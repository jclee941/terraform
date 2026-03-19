# AGENTS: docs/adr

## OVERVIEW

Architecture Decision Records for lasting design choices in this monorepo. These files are historical decisions, not operational runbooks.

## STRUCTURE

```text
docs/adr/
├── 001-monorepo-structure.md
├── 002-mcphub-single-entrypoint.md
├── 003-cloudflare-tunnel-architecture.md
├── 004-onepassword-vault-standardization.md
└── AGENTS.md
```

## WHERE TO LOOK

| Topic | File | Notes |
|------|------|-------|
| Monorepo structure | `001-monorepo-structure.md` | Directory model, Bazel, workspace numbering. |
| MCP access pattern | `002-mcphub-single-entrypoint.md` | Gateway and entrypoint decisions. |
| External access model | `003-cloudflare-tunnel-architecture.md` | Cloudflare tunnel and access rationale. |
| Secret schema migration | `004-onepassword-vault-standardization.md` | Vault item structure and consumer fallout. |

## CONVENTIONS

- File names stay `NNN-kebab-case.md`.
- Keep the standard ADR shape: `Context`, `Decision`, `Alternatives Considered`, `Consequences`.
- Keep status and date at the top of the file.
- Accepted ADRs are append-only; supersede them with a new ADR instead of rewriting history.

## ANTI-PATTERNS

- Do not edit past ADRs to describe a new decision.
- Do not omit alternatives or consequences; that removes the decision context.
- Do not turn ADRs into runbooks, TODO lists, or implementation checklists.
