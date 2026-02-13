import { Hono } from 'hono';
import { logger } from 'hono/logger';
import type { HonoEnv } from './env';
import { errorHandler, notFoundHandler } from './middleware/error-handler';
import { filesRoutes } from './routes/files';
import { healthRoutes } from './routes/health';

export const createApp = (): Hono<HonoEnv> => {
  const app = new Hono<HonoEnv>();

  app.use('*', logger());

  app.route('/api/files', filesRoutes);
  app.route('/', healthRoutes);

  app.onError(errorHandler);
  app.notFound(notFoundHandler);

  return app;
};
