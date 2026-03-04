import { Hono } from 'hono';
import type { HonoEnv } from '../env';

export const healthRoutes = new Hono<HonoEnv>();

healthRoutes.get('/health', (c) => {
  return c.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'issue-form',
    version: '1.0.0',
  });
});
