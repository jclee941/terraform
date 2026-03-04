import { Hono } from 'hono';
import { HonoEnv } from '../env';
import { GitHubClient } from '../github/client';
import { AuthenticationError } from '../middleware/error-handler';

// --- Types ---

interface ELKAlert {
  service: string;
  classification: string;
  severity: string;
  tier: number;
  count: number;
  sample_message: string;
  timestamp: string;
}

interface ESWatcherPayload {
  watch_id: string;
  payload: {
    aggregations?: {
      by_service: {
        buckets: Array<{
          key: string;
          by_classification: {
            buckets: Array<{
              key: string;
              doc_count: number;
              severity: { buckets: Array<{ key: string }> };
              tier: { value: number };
              latest_message: {
                hits: {
                  hits: Array<{
                    _source: {
                      message: string;
                      '@timestamp': string;
                    };
                  }>;
                };
              };
            }>;
          };
        }>;
      };
    };
  };
}

interface DirectPayload {
  watch_id?: string;
  alerts: ELKAlert[];
}

type WebhookPayload = ESWatcherPayload | DirectPayload;

// --- Constants ---

const SEVERITY_LABELS: Record<string, string> = {
  critical: 'priority:critical',
  high: 'priority:high',
  medium: 'priority:medium',
  low: 'priority:low',
};

const TIER_LABELS: Record<number, string> = {
  1: 'tier:1-critical',
  2: 'tier:2-high',
};

// --- Helpers ---

function parseESAggregations(payload: ESWatcherPayload): ELKAlert[] {
  const alerts: ELKAlert[] = [];
  const buckets = payload.payload?.aggregations?.by_service?.buckets;
  if (!buckets) return alerts;

  for (const serviceBucket of buckets) {
    const classificationBuckets = serviceBucket.by_classification?.buckets;
    if (!classificationBuckets) continue;

    for (const classBucket of classificationBuckets) {
      const severity = classBucket.severity?.buckets?.[0]?.key ?? 'unknown';
      const tier = classBucket.tier?.value ?? 0;
      const hit = classBucket.latest_message?.hits?.hits?.[0]?._source;

      alerts.push({
        service: serviceBucket.key,
        classification: classBucket.key,
        severity,
        tier,
        count: classBucket.doc_count,
        sample_message: hit?.message ?? '',
        timestamp: hit?.['@timestamp'] ?? new Date().toISOString(),
      });
    }
  }

  return alerts;
}

function extractAlerts(body: WebhookPayload): {
  watchId: string;
  alerts: ELKAlert[];
} {
  if ('alerts' in body && Array.isArray(body.alerts)) {
    return { watchId: body.watch_id ?? 'direct', alerts: body.alerts };
  }

  if ('payload' in body && body.payload?.aggregations) {
    return {
      watchId: body.watch_id,
      alerts: parseESAggregations(body as ESWatcherPayload),
    };
  }

  return { watchId: 'unknown', alerts: [] };
}

function buildIssueBody(alert: ELKAlert, watchId: string): string {
  return [
    `## ELK Error Alert`,
    '',
    `| Field | Value |`,
    `|-------|-------|`,
    `| **Service** | \`${alert.service}\` |`,
    `| **Classification** | \`${alert.classification}\` |`,
    `| **Severity** | ${alert.severity} |`,
    `| **Tier** | ${alert.tier} |`,
    `| **Occurrences** | ${alert.count} |`,
    `| **Timestamp** | ${alert.timestamp} |`,
    '',
    `### Sample Message`,
    '```',
    alert.sample_message,
    '```',
    '',
    '---',
    `*Auto-created by ELK Watcher \`${watchId}\`*`,
  ].join('\n');
}

function buildLabels(alert: ELKAlert): string[] {
  const labels = ['elk-alert', `service:${alert.service}`];
  const severityLabel = SEVERITY_LABELS[alert.severity];
  if (severityLabel) labels.push(severityLabel);
  const tierLabel = TIER_LABELS[alert.tier];
  if (tierLabel) labels.push(tierLabel);
  return labels;
}

// --- Route ---

export const webhookRoutes = new Hono<HonoEnv>();

webhookRoutes.post('/webhook/elk', async (c) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw new AuthenticationError('Missing or invalid Authorization header');
  }
  if (authHeader.slice(7) !== c.env.WEBHOOK_SECRET) {
    throw new AuthenticationError('Invalid webhook secret');
  }

  const body = await c.req.json<WebhookPayload>();
  const { watchId, alerts } = extractAlerts(body);

  if (alerts.length === 0) {
    return c.json({
      success: true,
      message: 'No alerts to process',
      created: 0,
      skipped: 0,
    });
  }

  const client = new GitHubClient(
    c.env.GITHUB_TOKEN,
    c.env.GITHUB_OWNER,
    c.env.GITHUB_REPO
  );

  const results: Array<{
    title: string;
    created?: boolean;
    skipped?: boolean;
    assigned_to?: string;
    issue?: { number: number; html_url: string };
    existing_issue?: string;
  }> = [];

  for (const alert of alerts) {
    const title = `[ELK] ${alert.service}: ${alert.classification}`;

    // Dedup: search for existing open issue with same title.
    // On search failure, proceed to create (prefer duplicate over missed alert).
    let existingIssues: Array<{ number: number; html_url: string }> = [];
    try {
      existingIssues = await client.searchIssues(title);
    } catch {
      // Search API failure — fall through to create
    }

    if (existingIssues.length > 0) {
      results.push({
        title,
        skipped: true,
        existing_issue: existingIssues[0].html_url,
      });
      continue;
    }

    const issue = await client.createIssue({
      title,
      body: buildIssueBody(alert, watchId),
      labels: buildLabels(alert),
    });

    // Auto-assign to Copilot coding agent (Codex) for PR creation
    let assignedTo: string | undefined;
    try {
      await client.assignIssue(issue.number, ['copilot']);
      assignedTo = 'copilot';
    } catch {
      // Assignment failure is non-critical — issue was still created
    }

    results.push({
      title,
      created: true,
      assigned_to: assignedTo,
      issue: { number: issue.number, html_url: issue.html_url },
    });
  }

  const created = results.filter((r) => r.created).length;
  const skipped = results.filter((r) => r.skipped).length;

  return c.json({
    success: true,
    processed: alerts.length,
    created,
    skipped,
    results,
  });
});
