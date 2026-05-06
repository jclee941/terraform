# AGENTS: 400-gcp — Google Cloud Platform (PLANNED)

> **Status**: PLANNED — NOT YET IMPLEMENTED  
> **Tier**: Independent (400s cloud)  
> **Apply Order**: Any — parallel with 300-cloudflare, 301-github, 320-slack

## OVERVIEW

Planned Google Cloud Platform workspace for cloud-native resources. This workspace is reserved for future GCP infrastructure but has not been implemented yet.

**Current State**: Directory does not exist. Only Makefile alias and test scaffolding are prepared.

## PLANNED STRUCTURE

```
400-gcp/
├── main.tf              # GCP provider + resources (GCE, Cloud SQL, GKE, etc.)
├── variables.tf         # Input variables
├── outputs.tf           # Outputs
├── versions.tf          # Provider constraints (google ~> 5.0)
├── onepassword.tf       # Secret lookup via shared module
└── AGENTS.md            # This file
```

## PREPARED INTEGRATIONS

| Component | Status | Location |
|-----------|--------|----------|
| Makefile alias | ✅ Ready | `ALIAS_gcp := 400-gcp` |
| 1Password secrets | ✅ Prepared | `enable_gcp` variable in onepassword-secrets module |
| Test scaffolding | ⚠️ Placeholder | `tests/workspaces/gcp/` — minimal stub only |
| CI pipeline | ❌ Not configured | Would need `.github/workflows/` addition |

## INTENDED RESOURCES (Inference)

Based on workspace patterns, this would likely provision:
- GCP Compute Engine instances
- Cloud SQL databases
- GKE clusters (if Kubernetes workloads needed)
- Cloud Storage buckets
- IAM service accounts and policies

## CONVENTIONS (To Follow)

- Use `google` provider (~> 5.0)
- Secrets via `module.onepassword_secrets` with `enable_gcp = true`
- Follow Independent tier patterns from `300-cloudflare/`
- No Proxmox dependencies — pure cloud resources

## ANTI-PATTERNS

- **DO NOT** create until infrastructure requirements are defined
- **NEVER** commit GCP credentials to repository
- **NEVER** use default GCP project — always specify explicit project ID

## NOTES

- Referenced in root `AGENTS.md` as part of 400s cloud tier.

## NEXT STEPS TO IMPLEMENT

1. Create `400-gcp/` directory
2. Add `google` provider to `versions.tf`
3. Define required GCP resources
4. Wire up `onepassword-secrets` with `enable_gcp = true`
5. Add real tests to `tests/workspaces/gcp/`
6. Configure CI job in `.github/workflows/`.
