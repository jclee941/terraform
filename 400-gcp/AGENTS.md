# AGENTS: 400-gcp

## OVERVIEW

Terraform-managed Google Cloud Platform (GCP) infrastructure via the `hashicorp/google` provider. Foundation workspace — provider config and auth only; add resources as needed.

## STRUCTURE

```text
400-gcp/
├── AGENTS.md
├── BUILD.bazel
├── OWNERS
├── main.tf          # Provider config (google + onepassword)
├── versions.tf      # Provider requirements + backend
├── variables.tf     # GCP auth variables (with validation)
├── onepassword.tf   # 1Password secret lookup + effective locals
├── locals.tf        # Common labels and defaults
└── outputs.tf       # Project ID and region outputs
```

## WHERE TO LOOK

| Task                | Location         | Notes                                |
| ------------------- | ---------------- | ------------------------------------ |
| Provider config     | `main.tf`        | SA credentials + project + region    |
| Secret lookup       | `onepassword.tf` | SA key JSON from 1Password           |
| Auth variables      | `variables.tf`   | Project, region, credentials override|
| CI plan/apply       | `.github/workflows/gcp-{plan,apply}.yml` | Reusable `_terraform-*` wrappers |

## CONVENTIONS

- Auth: Service account key JSON via 1Password, with variable fallback.
- Region default: `asia-northeast3` (Seoul).
- Label all resources with `local.default_labels`.
- Resource gating: use `local._gcp_enabled` to conditionally create resources when credentials are available.
- Toggle `enable_gcp_lookup = true` only after the `gcp` 1Password item is created; keep default `false` to avoid CI failures during scaffold runs.

## ANTI-PATTERNS

- Never hardcode GCP credentials or project IDs in TF files.
- Never use user credentials for CI/CD — service accounts only.
- Never store SA key JSON in git — 1Password only.

## COMMANDS

```bash
make plan SVC=gcp
# make apply is DISABLED locally — applies go through CI/CD
```
