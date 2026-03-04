# AGENTS: 300-cloudflare/workers/issue-form — GitHub Issue Form Worker

## OVERVIEW

Hono-based Cloudflare Worker serving a Korean-language GitHub issue submission form. Renders an inline HTML form at `/` and creates issues in `qws941-lab/terraform` via the GitHub API.

## STRUCTURE

```
issue-form/
├── src/
│   ├── index.ts              # Worker fetch entry (delegates to app)
│   ├── app.ts                # Hono factory: logger, CORS, routes, error handler
│   ├── env.ts                # Env + HonoEnv type bindings
│   ├── routes/
│   │   ├── form.ts           # GET / — inline HTML form (dark theme, Pretendard font)
│   │   ├── issues.ts         # POST /api/issues — validate + create GitHub issue
│   │   └── health.ts         # GET /health — service status
│   ├── github/
│   │   └── client.ts         # GitHubClient: issue creation, error mapping, rate-limit handling
│   └── middleware/
│       └── error-handler.ts  # AppError hierarchy + JSON error responses
├── test/
├── package.json
├── tsconfig.json
├── vitest.config.ts
└── wrangler.toml
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Route registration + middleware | `src/app.ts` |
| Issue creation logic + label mapping | `src/routes/issues.ts` |
| HTML form template + client-side JS | `src/routes/form.ts` |
| GitHub API interaction + auth errors | `src/github/client.ts` |
| Error classes (Validation/NotFound/Auth/ExternalService) | `src/middleware/error-handler.ts` |
| Worker bindings (GITHUB_TOKEN secret, vars) | `wrangler.toml` + `src/env.ts` |
| Parent workspace policy | `../../AGENTS.md` |

## CONVENTIONS

- App factory pattern: `createApp()` in `app.ts` returns configured Hono instance.
- Korean label mapping: issue types (🐛버그→bug, ✨기능요청→enhancement, 🔧유지보수→maintenance, 📝문서→documentation) and priorities (🔴긴급→critical, 🟠높음→high, 🟡보통→medium, 🟢낮음→low).
- Validation in route handler: title max 256 chars, description max 65536 chars.
- Error responses: JSON `{success: false, error: {message, code, statusCode, details}, timestamp, requestId}`.
- `GITHUB_TOKEN` stored as Wrangler secret, never in `wrangler.toml`.
- `workers_dev = true` — currently served on `*.workers.dev`, no custom route.

## ANTI-PATTERNS

- Do not hardcode GitHub credentials in source — use Wrangler secrets.
- Do not bypass `Env` type bindings with `env: any` in `index.ts` (existing tech debt).
- Do not insert user input via `innerHTML` without sanitization (existing XSS risk in `form.ts`).
- Do not add authentication middleware without updating this doc and parent AGENTS.md.
- Do not hand-edit rendered form HTML outside `form.ts` — it is the single source.
