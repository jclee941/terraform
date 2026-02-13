import { Hono } from 'hono';
import type { HonoEnv } from '../env';

export const healthRoutes = new Hono<HonoEnv>();

healthRoutes.get('/health', (c) => {
  return c.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'synology-proxy',
    version: '1.0.0',
  });
});
