export interface Env {
  GITHUB_TOKEN: string;
  GITHUB_OWNER: string;
  GITHUB_REPO: string;
  ENVIRONMENT: string;
  WEBHOOK_SECRET: string;
}

export type HonoEnv = { Bindings: Env };
