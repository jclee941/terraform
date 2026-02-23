import type { MiddlewareHandler } from 'hono';
import type { HonoEnv } from '../env';

type WorkerLog = {
  timestamp: string;
  level: 'info';
  service: 'synology-proxy-worker';
  message: string;
  event: 'request_completed';
  method: string;
  path: string;
  status: number;
  duration_ms: number;
  request_id?: string;
  cf_colo?: string;
  user_agent?: string;
};

export const elkRequestLogger: MiddlewareHandler<HonoEnv> = async (c, next) => {
  const startedAt = Date.now();
  await next();

  const requestId = c.req.header('cf-ray');
  const cfColo = c.req.header('cf-ipcountry');
  const userAgent = c.req.header('user-agent');
  const url = new URL(c.req.url);

  const payload: WorkerLog = {
    timestamp: new Date().toISOString(),
    level: 'info',
    service: 'synology-proxy-worker',
    message: 'Cloudflare Worker request processed',
    event: 'request_completed',
    method: c.req.method,
    path: url.pathname,
    status: c.res.status,
    duration_ms: Date.now() - startedAt,
    request_id: requestId,
    cf_colo: cfColo,
    user_agent: userAgent,
  };

  console.log(JSON.stringify(payload));

  const endpoint = c.env.ELK_ES_ENDPOINT?.trim();
  const password = c.env.ELK_ES_PASSWORD?.trim();
  if (!endpoint || !password) {
    return;
  }

  const username = c.env.ELK_ES_USERNAME?.trim() || 'elastic';
  const indexPrefix = c.env.ELK_ES_INDEX_PREFIX?.trim() || 'logs-synology-proxy-worker';
  const now = new Date();
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  const day = String(now.getUTCDate()).padStart(2, '0');
  const indexName = `${indexPrefix}-${now.getUTCFullYear()}.${month}.${day}`;
  const authToken = btoa(`${username}:${password}`);
  const indexUrl = `${endpoint.replace(/\/$/, '')}/${indexName}/_doc`;

  try {
    const response = await fetch(indexUrl, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Basic ${authToken}`,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      console.warn(
        JSON.stringify({
          event: 'elk_forward_failed',
          status: response.status,
          path: new URL(c.req.url).pathname,
        })
      );
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn(
      JSON.stringify({
        event: 'elk_forward_error',
        message,
        path: new URL(c.req.url).pathname,
      })
    );
  }
};
