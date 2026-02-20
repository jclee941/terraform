# AGENTS: 300-cloudflare/workers — Worker Workspace Boundary

## OVERVIEW
Boundary guidance for Cloudflare Worker implementations under `300-cloudflare/workers/`.

## STRUCTURE
```
300-cloudflare/workers/
├── synology-proxy/   # Hono Worker implementation
├── BUILD.bazel
└── OWNERS
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Worker runtime behavior | `synology-proxy/src/` | Request handling, middleware, cache, and client logic. |
| Worker scripts and tooling | `synology-proxy/package.json` | `dev`, `test`, `build`, `deploy`, `type-check`. |
| Worker-specific conventions | `synology-proxy/AGENTS.md` | Most specific rules for current worker. |

## CONVENTIONS
- Keep worker-level implementation rules in each worker subdirectory AGENTS file.
- Keep this file as boundary/index guidance only.
- Use Wrangler + TypeScript + Vitest workflows defined per worker.

## ANTI-PATTERNS
- Do not duplicate `synology-proxy/AGENTS.md` details here.
- Do not mix Terraform workspace rules into worker runtime guidance.

## COMMANDS
```bash
cd 300-cloudflare/workers/synology-proxy && npm run dev
cd 300-cloudflare/workers/synology-proxy && npm test
cd 300-cloudflare/workers/synology-proxy && npm run deploy
```
