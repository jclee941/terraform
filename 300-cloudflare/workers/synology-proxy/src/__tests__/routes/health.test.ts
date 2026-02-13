import { Hono } from 'hono';
import { describe, expect, it } from 'vitest';
import type { Env, HonoEnv } from '../../env';
import { healthRoutes } from '../../routes/health';

const createBucketMock = (): R2Bucket => {
  const bucket = {
    get: async () => null,
    put: async () => {},
    delete: async () => {},
    list: async () => ({ objects: [], truncated: false }),
  };
  return bucket as unknown as R2Bucket;
};

const createEnv = (): Env => {
  return {
    SYNOLOGY_CACHE: createBucketMock(),
    SYNOLOGY_API_URL: 'https://nas.example.com',
    SYNOLOGY_USERNAME: 'user',
    SYNOLOGY_PASSWORD: 'pass',
    ENVIRONMENT: 'test',
  };
};

describe('health routes', () => {
  it('returns healthy status payload', async () => {
    const app = new Hono<HonoEnv>();
    app.route('/', healthRoutes);

    const response = await app.request('/health', { method: 'GET' }, createEnv());
    const body = (await response.json()) as {
      status: string;
      timestamp: string;
      service: string;
      version: string;
    };

    expect(response.status).toBe(200);
    expect(body.status).toBe('ok');
    expect(body.service).toBe('synology-proxy');
    expect(body.version).toBe('1.0.0');
    expect(typeof body.timestamp).toBe('string');
  });
});
