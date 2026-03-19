export interface Env {
  SYNOLOGY_CACHE: R2Bucket;
  SYNOLOGY_API_URL: string;
  SYNOLOGY_USERNAME: string;
  SYNOLOGY_PASSWORD: string;
  ENVIRONMENT: string;
  API_KEY: string;
  ELK_ES_ENDPOINT?: string;
  ELK_ES_USERNAME?: string;
  ELK_ES_PASSWORD?: string;
  ELK_ES_INDEX_PREFIX?: string;
}

export type HonoEnv = { Bindings: Env };
