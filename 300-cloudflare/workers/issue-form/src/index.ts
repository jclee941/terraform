import { createApp } from './app';
import type { Env } from './env';

export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext) {
    const app = createApp();
    return app.fetch(request, env, ctx);
  },
};
