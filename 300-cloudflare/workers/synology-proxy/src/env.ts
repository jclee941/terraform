export interface Env {
  SYNOLOGY_CACHE: R2Bucket;
  SYNOLOGY_API_URL: string;
  SYNOLOGY_USERNAME: string;
  SYNOLOGY_PASSWORD: string;
  ENVIRONMENT: string;
}

export type HonoEnv = { Bindings: Env };
