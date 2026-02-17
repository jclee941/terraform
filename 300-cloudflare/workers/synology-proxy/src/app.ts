import { Hono } from 'hono';
import { logger } from 'hono/logger';
import type { HonoEnv } from './env';
import { bearerAuth } from './middleware/auth';
import { errorHandler, notFoundHandler } from './middleware/error-handler';
import { filesRoutes } from './routes/files';
import { healthRoutes } from './routes/health';
import { publicRoutes } from './routes/public';

export const createApp = (): Hono<HonoEnv> => {
  const app = new Hono<HonoEnv>();

  app.use('*', logger());

  // Public routes (no auth required)
  app.route('/', healthRoutes);
  app.route('/public', publicRoutes);

  // Protected API routes (Bearer token auth)
  app.use('/api/*', bearerAuth);
  app.route('/api/files', filesRoutes);

  app.onError(errorHandler);
  app.notFound(notFoundHandler);

  return app;
};
