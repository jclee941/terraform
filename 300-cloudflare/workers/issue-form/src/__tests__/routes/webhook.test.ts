import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createApp } from '../../app';

const mockEnv = {
  GITHUB_TOKEN: 'test-token',
  GITHUB_OWNER: 'test-owner',
  GITHUB_REPO: 'test-repo',
  ENVIRONMENT: 'test',
  WEBHOOK_SECRET: 'test-webhook-secret',  // pragma: allowlist secret
};

interface WebhookResponse {
  success: boolean;
  message?: string;
  processed?: number;
  created: number;
  skipped: number;
  results?: Array<{
    title: string;
    created?: boolean;
    skipped?: boolean;
    assigned_to?: string;
    issue?: { number: number; html_url: string };
    existing_issue?: string;
  }>;
}

// Mock response for assignIssue (PATCH) — always succeeds
const assignOkResponse = () =>
  new Response(JSON.stringify({}), { status: 200 });

describe('POST /api/webhook/elk', () => {
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    app = createApp();
    vi.restoreAllMocks();
  });

  const request = (
    body: unknown,
    headers: Record<string, string> = {}
  ) =>
    app.request(
      '/api/webhook/elk',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${mockEnv.WEBHOOK_SECRET}`,
          ...headers,
        },
        body: JSON.stringify(body),
      },
      mockEnv
    );

  it('rejects missing auth header', async () => {
    const res = await app.request(
      '/api/webhook/elk',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ alerts: [] }),
      },
      mockEnv
    );
    expect(res.status).toBe(401);
  });

  it('rejects invalid webhook secret', async () => {
    const res = await request(
      { alerts: [] },
      { Authorization: 'Bearer wrong-secret' }
    );
    expect(res.status).toBe(401);
  });

  it('returns success for empty alerts', async () => {
    const res = await request({ alerts: [] });
    expect(res.status).toBe(200);
    const json = (await res.json()) as WebhookResponse;
    expect(json).toEqual({
      success: true,
      message: 'No alerts to process',
      created: 0,
      skipped: 0,
    });
  });

  it('returns success for payload with no aggregation buckets', async () => {
    const res = await request({
      watch_id: 'test',
      payload: { aggregations: { by_service: { buckets: [] } } },
    });
    expect(res.status).toBe(200);
    const json = (await res.json()) as WebhookResponse;
    expect(json.created).toBe(0);
    expect(json.skipped).toBe(0);
  });

  it('creates issue from direct alert payload', async () => {
    global.fetch = vi
      .fn()
      // searchIssues -> no existing issues
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ items: [] }), { status: 200 })
      )
      // createIssue -> success
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            number: 42,
            html_url:
              'https://github.com/test-owner/test-repo/issues/42',
            title: '[ELK] traefik: CRITICAL_FAILURE',
          }),
          { status: 201, headers: { 'Content-Type': 'application/json' } }
        )
      )
      // assignIssue -> success
      .mockResolvedValueOnce(assignOkResponse());

    const res = await request({
      watch_id: 'test-watcher',
      alerts: [
        {
          service: 'traefik',
          classification: 'CRITICAL_FAILURE',
          severity: 'critical',
          tier: 1,
          count: 5,
          sample_message: 'Connection refused',
          timestamp: '2025-03-04T00:00:00Z',
        },
      ],
    });

    expect(res.status).toBe(200);
    const json = (await res.json()) as WebhookResponse;
    expect(json.success).toBe(true);
    expect(json.created).toBe(1);
    expect(json.skipped).toBe(0);
    expect(json.results?.[0].issue?.number).toBe(42);
    expect(json.results?.[0].assigned_to).toBe('copilot');
  });

  it('skips duplicate issues', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          items: [
            {
              number: 10,
              html_url:
                'https://github.com/test-owner/test-repo/issues/10',
              title: '[ELK] traefik: CRITICAL_FAILURE',
              state: 'open',
            },
          ],
        }),
        { status: 200 }
      )
    );

    const res = await request({
      alerts: [
        {
          service: 'traefik',
          classification: 'CRITICAL_FAILURE',
          severity: 'critical',
          tier: 1,
          count: 3,
          sample_message: 'Error',
          timestamp: '2025-03-04T00:00:00Z',
        },
      ],
    });

    expect(res.status).toBe(200);
    const json = (await res.json()) as WebhookResponse;
    expect(json.created).toBe(0);
    expect(json.skipped).toBe(1);
    expect(json.results?.[0].existing_issue).toBe(
      'https://github.com/test-owner/test-repo/issues/10'
    );
  });

  it('parses ES watcher aggregation payload', async () => {
    global.fetch = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ items: [] }), { status: 200 })
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            number: 99,
            html_url:
              'https://github.com/test-owner/test-repo/issues/99',
            title: '[ELK] grafana: RESOURCE_EXHAUSTION',
          }),
          { status: 201, headers: { 'Content-Type': 'application/json' } }
        )
      )
      // assignIssue
      .mockResolvedValueOnce(assignOkResponse());

    const res = await request({
      watch_id: 'elk-error-alerts',
      payload: {
        aggregations: {
          by_service: {
            buckets: [
              {
                key: 'grafana',
                by_classification: {
                  buckets: [
                    {
                      key: 'RESOURCE_EXHAUSTION',
                      doc_count: 12,
                      severity: { buckets: [{ key: 'high' }] },
                      tier: { value: 2 },
                      latest_message: {
                        hits: {
                          hits: [
                            {
                              _source: {
                                message: 'Out of memory',
                                '@timestamp': '2025-03-04T01:00:00Z',
                              },
                            },
                          ],
                        },
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
      },
    });

    expect(res.status).toBe(200);
    const json = (await res.json()) as WebhookResponse;
    expect(json.created).toBe(1);
    expect(json.results?.[0].issue?.number).toBe(99);
  });

  it('applies correct labels based on severity and tier', async () => {
    let capturedBody: Record<string, unknown> | undefined;
    global.fetch = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ items: [] }), { status: 200 })
      )
      .mockImplementationOnce(async (_url: unknown, init: RequestInit) => {
        capturedBody = JSON.parse(init.body as string);
        return new Response(
          JSON.stringify({
            number: 1,
            html_url: 'https://github.com/t/t/issues/1',
            title: 'test',
          }),
          { status: 201, headers: { 'Content-Type': 'application/json' } }
        );
      })
      // assignIssue
      .mockResolvedValueOnce(assignOkResponse());

    await request({
      alerts: [
        {
          service: 'elk',
          classification: 'CRITICAL_FAILURE',
          severity: 'critical',
          tier: 1,
          count: 1,
          sample_message: 'test',
          timestamp: '2025-03-04T00:00:00Z',
        },
      ],
    });

    expect(capturedBody).toBeDefined();
    const labels = capturedBody!.labels as string[];
    expect(labels).toContain('elk-alert');
    expect(labels).toContain('service:elk');
    expect(labels).toContain('priority:critical');
    expect(labels).toContain('tier:1-critical');
  });

  it('proceeds to create when search fails', async () => {
    global.fetch = vi
      .fn()
      // searchIssues -> fails
      .mockRejectedValueOnce(new Error('Search API down'))
      // createIssue -> success
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            number: 77,
            html_url: 'https://github.com/t/t/issues/77',
            title: '[ELK] coredns: CONNECTIVITY_FAILURE',
          }),
          { status: 201, headers: { 'Content-Type': 'application/json' } }
        )
      )
      // assignIssue
      .mockResolvedValueOnce(assignOkResponse());

    const res = await request({
      alerts: [
        {
          service: 'coredns',
          classification: 'CONNECTIVITY_FAILURE',
          severity: 'high',
          tier: 2,
          count: 8,
          sample_message: 'DNS timeout',
          timestamp: '2025-03-04T02:00:00Z',
        },
      ],
    });

    expect(res.status).toBe(200);
    const json = (await res.json()) as WebhookResponse;
    expect(json.created).toBe(1);
  });

  it('still creates issue when Codex assignment fails', async () => {
    global.fetch = vi
      .fn()
      // searchIssues -> no match
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ items: [] }), { status: 200 })
      )
      // createIssue -> success
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            number: 55,
            html_url: 'https://github.com/t/t/issues/55',
            title: '[ELK] runner: GATEWAY_ERROR',
          }),
          { status: 201, headers: { 'Content-Type': 'application/json' } }
        )
      )
      // assignIssue -> fails (e.g. Copilot bot not available)
      .mockRejectedValueOnce(new Error('Assign API error'));

    const res = await request({
      alerts: [
        {
          service: 'runner',
          classification: 'GATEWAY_ERROR',
          severity: 'medium',
          tier: 2,
          count: 2,
          sample_message: '502 Bad Gateway',
          timestamp: '2025-03-04T03:00:00Z',
        },
      ],
    });

    expect(res.status).toBe(200);
    const json = (await res.json()) as WebhookResponse;
    expect(json.created).toBe(1);
    expect(json.results?.[0].issue?.number).toBe(55);
    // assigned_to should be undefined when assignment fails
    expect(json.results?.[0].assigned_to).toBeUndefined();
  });
});
