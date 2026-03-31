/**
 * Environment configuration for n8n agent.
 * All values have sensible defaults for local development.
 */

function env(key: string, fallback: string): string {
  return process.env[key] ?? fallback;
}

function envInt(key: string, fallback: number): number {
  const v = process.env[key];
  if (v === undefined) return fallback;
  const n = parseInt(v, 10);
  return Number.isNaN(n) ? fallback : n;
}

function envPositiveInt(key: string, fallback: number): number {
  const v = process.env[key];
  if (v === undefined) return fallback;

  const n = Number(v);
  if (!Number.isInteger(n) || n < 1) return fallback;
  return n;
}

/** n8n REST API configuration */
export const n8n = {
  /** Base URL of the n8n instance (no trailing slash) */
  baseUrl: env("N8N_BASE_URL", "https://n8n.jclee.me"),
  /** API key for n8n authentication */
  apiKey: env("N8N_API_KEY", ""),
} as const;

/** OpenCode server configuration */
export const server = {
  /** Port for the OpenCode server */
  port: envInt("OPENCODE_PORT", 4096),
  /** Hostname to bind */
  hostname: env("OPENCODE_HOST", "0.0.0.0"),
} as const;

/** OpenAI-compatible proxy configuration */
export const proxy = {
  /** Port for the proxy server */
  port: envInt("PROXY_PORT", 3001),
  /** Hostname to bind */
  hostname: env("PROXY_HOST", "0.0.0.0"),
} as const;

/** Model configuration */
export const model = {
  /** Default model ID */
  id: env("MODEL_ID", "anthropic/claude-sonnet-4-20250514"),
} as const;

/** Proxy model configuration */
export const proxyModel = {
  publicId: env("PROXY_PUBLIC_MODEL_ID", "opencode"),
  targetId: env("PROXY_MODEL_ID", "openai/gpt-5.4"),
  aliases: env("PROXY_MODEL_ALIASES", "opencode,openai/gpt-5.4,gpt-5.4")
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0),
  /** Max number of upstream models to return (sorted by newest first). 0 = no limit */
  modelsLimit: envInt("PROXY_MODELS_LIMIT", 30),
} as const;

export const proxyProvider = {
  id: env("PROXY_PROVIDER_ID", "n8n-openai"),
  apiKey: env("OPENAI_API_KEY", env("OPENROUTER_API_KEY", "")),
  baseUrl: env(
    "OPENAI_BASE_URL",
    env(
      "OPENROUTER_BASE_URL",
      process.env.OPENROUTER_API_KEY ? "https://openrouter.ai/api/v1" : "",
    ),
  ),
  /** Access key for authenticating proxy requests (e.g. from n8n AI Agent).
   *  When a Bearer token matches this key, the shared runtime is used
   *  instead of creating a per-request isolated runtime. */
  accessKey: env("PROXY_ACCESS_KEY", ""),
} as const;

export const smokeTest = {
  attempts: envPositiveInt("OPENCODE_SMOKE_ATTEMPTS", 120),
  sleepMs: envPositiveInt("OPENCODE_SMOKE_SLEEP_MS", 500),
} as const;

export function getProxyProviderConfigError(): string | undefined {
  if (!proxyProvider.apiKey) {
    return "Proxy provider API key is not configured. Set OPENAI_API_KEY or OPENROUTER_API_KEY."
  }

  if (!proxyProvider.baseUrl) {
    return "Proxy provider base URL is not configured. Set OPENAI_BASE_URL or OPENROUTER_BASE_URL."
  }

  return undefined
}
