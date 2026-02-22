# PROJECT KNOWLEDGE BASE

**Updated:** 2026-02-22

## OVERVIEW

Hono-based Cloudflare Worker proxying Synology NAS FileStation API with R2-backed response caching.

## STRUCTURE

```
src/
├── index.ts              # Entry: exports { fetch } from app
├── app.ts                # Hono factory: mounts routes + error middleware
├── env.ts                # Env interface: R2Bucket, SYNOLOGY_* secrets, API_KEY
├── routes/
│   ├── files.ts          # CRUD + download/upload/share (DI: receives client+cache)
│   └── health.ts         # GET /health
├── synology/
│   ├── auth.ts           # SID session auth, 50min TTL cache
│   ├── client.ts         # FileStation API client (list/get/download/upload/share/delete)
│   └── types.ts          # Interfaces + SynologyErrorCode enum (119=no login, 101=unknown)
├── middleware/
│   └── error-handler.ts  # AppError hierarchy (AuthError, NotFoundError, ValidationError)
└── cache/
    └── r2.ts             # R2 cache: get/set with TTL metadata, prefix invalidation
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Add API endpoint | `routes/files.ts` | Follow existing DI pattern (client, cache injected) |
| Add Synology API method | `synology/client.ts` | Follow `FileStationClient` class pattern |
| New error type | `middleware/error-handler.ts` | Extend `AppError` base class |
| Add env binding | `env.ts` | Update `Env` interface |
| Cache behavior | `cache/r2.ts` | `R2CacheService`, TTL in metadata |
| Test patterns | `src/__tests__/` | Mirrors src structure, vitest + miniflare env |

## CONVENTIONS

- **DI pattern**: Route handlers receive `SynologyClient` + `R2CacheService` as params, NOT from env directly
- **App factory**: `createApp(env)` in `app.ts` — instantiates client/cache, passes to routes
- **Error handling**: Throw `AppError` subclass → middleware catches → JSON `{ error, message, status }`
- **Auth flow**: `SynologyAuth.getSid()` → cached 50min → auto-refreshes on 119 error
- **Cache keys**: R2 key = `synology-cache/${path}` prefix, 7-day TTL stored in `customMetadata.expiresAt`
- **Cache invalidation**: Write operations (upload/delete) call `cache.invalidateByPrefix(folderPath)`
- **Formatting**: Prettier — printWidth:100, singleQuote, trailingComma:es5, no semi
- **Types**: TypeScript strict mode, no `any`

## ANTI-PATTERNS

- **NEVER** call Synology API directly from routes — always through `SynologyClient`
- **NEVER** hardcode SID — use `SynologyAuth` (handles session lifecycle)
- Don't cache upload/delete responses — only read operations (list, get, download)
- Don't access `env.*` in route handlers — use injected services from `createApp()`
- Test files must use `miniflare` environment for R2/Workers bindings
- **NEVER** deploy manually — `npm run deploy` is disabled. Use `worker-deploy.yml` CI workflow.
