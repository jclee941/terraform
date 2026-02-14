# ADR-001: Monorepo Structure with Bazel

**Status:** Accepted  
**Date:** 2026-02-13  

## Context

The infrastructure was initially managed across separate repositories (proxmox/, cloudflare/). As the number of providers grew, maintaining consistency and cross-cutting concerns became difficult.

## Decision

Adopt a flat monorepo structure with Bazel build system:
- Root-level `{NNN}-{svc}/` directories for Terraform workspaces
- `modules/{provider}/{module}/` for reusable modules
- `modules/shared/` for cross-provider modules
- Every directory has `BUILD.bazel` and `OWNERS` (Google3 style)
- Numbering: 100-199 internal infra, 200-299 VMs, 300+ external providers

## Alternatives Considered

1. **Terragrunt** — Too opinionated for our multi-provider setup
2. **Multi-repo** — Cross-repo dependencies hard to manage
3. **TF Workspaces** — Single state file risk, env-based switching fragile

## Consequences

- Single source of truth for all infrastructure
- Bazel validates BUILD files across all directories
- Module sharing via relative paths (`../modules/`)
- Atomic commits across providers
- CI/CD runs against entire repo
