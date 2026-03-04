# AGENTS: 300-cloudflare/workers — Worker Workspace Boundary

## OVERVIEW
Boundary guidance for Cloudflare Worker implementations under `300-cloudflare/workers/`.

## STRUCTURE
```
300-cloudflare/workers/
├── synology-proxy/   # Hono Worker implementation
├── issue-form/       # Hono Worker implementation
├── BUILD.bazel
├── OWNERS
└── AGENTS.md
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Worker runtime behavior | `synology-proxy/src/` | Request handling, middleware, cache, and client logic. |
| Worker scripts and tooling | `synology-proxy/package.json` | `dev`, `test`, `build`, `deploy`, `type-check`. |
| Worker deployment config | `synology-proxy/wrangler.jsonc` | Route, compatibility date, bindings, and env config. |
| Worker tests | `synology-proxy/test/` | Vitest suites and request/response assertions. |
| Worker-specific conventions | `synology-proxy/AGENTS.md` | Most specific rules for current worker. |
| issue-form runtime behavior | `issue-form/src/` | Request handling, middleware, GitHub client, and form rendering. |
| issue-form scripts and tooling | `issue-form/package.json` | `dev`, `test`, `build`, `deploy`, `type-check`. |
| issue-form deployment config | `issue-form/wrangler.toml` | Compatibility date, bindings, and env config. |
| issue-form tests | `issue-form/test/` | Vitest suites. |
| issue-form conventions | `issue-form/AGENTS.md` | Most specific rules for issue-form worker. |
| Parent workspace policy | `../AGENTS.md` | Cloudflare workspace-level Terraform + worker constraints. |
| Secret automation scripts | `../scripts/AGENTS.md` | Script-side secret/binding generation and sync workflow. |

## CONVENTIONS
- Keep worker-level implementation rules in each worker subdirectory AGENTS file.
- Keep this file as boundary/index guidance only.
- Use Wrangler + TypeScript + Vitest workflows defined per worker.

## ANTI-PATTERNS
- Do not duplicate worker subdirectory AGENTS.md details here.
- Do not mix Terraform workspace rules into worker runtime guidance.

## COMMANDS
```bash
npm --prefix 300-cloudflare/workers/synology-proxy run dev
npm --prefix 300-cloudflare/workers/synology-proxy test
npm --prefix 300-cloudflare/workers/synology-proxy run build
npm --prefix 300-cloudflare/workers/synology-proxy run deploy  # DISABLED — use worker-deploy.yml CI workflow
npm --prefix 300-cloudflare/workers/issue-form run dev
npm --prefix 300-cloudflare/workers/issue-form test
npm --prefix 300-cloudflare/workers/issue-form run build
npm --prefix 300-cloudflare/workers/issue-form run deploy  # DISABLED — use worker-deploy.yml CI workflow
```
