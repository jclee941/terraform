import { Hono } from 'hono';
import { logger } from 'hono/logger';
import { cors } from 'hono/cors';
import type { HonoEnv } from './env';
import { errorHandler, notFoundHandler } from './middleware/error-handler';
import { formRoutes } from './routes/form';
import { issueRoutes } from './routes/issues';
import { healthRoutes } from './routes/health';
import { webhookRoutes } from './routes/webhook';

export const createApp = (): Hono<HonoEnv> => {
  const app = new Hono<HonoEnv>();

  app.use('*', logger());
  app.use('*', cors());

  app.route('/', healthRoutes);
  app.route('/', formRoutes);
  app.route('/api', issueRoutes);
  app.route('/api', webhookRoutes);

  app.onError(errorHandler);
  app.notFound(notFoundHandler);

  return app;
};
