# Legacy / Infrastructure Diagnosis Report

> Generated for the `jclee.me` Terraform homelab monorepo.
> Scope: full monorepo (`100-pve`, `300-cloudflare`, `105-elk`, `215-synology`, `102-traefik` + `modules/**` + `tests/**`).
> Method: 4 parallel structural/duplication/deprecation scans + canonical Terraform 1.10+ best-practice review + direct verification.

## Executive Summary

The codebase is **healthier than typical legacy Terraform**:

| Clean signal | Result |
| --- | --- |
| `terraform fmt` drift | 0 files |
| Interpolation-only `"${x}"` legacy | 0 occurrences |
| `count` vs `for_each` | 2 `count` (boolean gates) vs 26 `for_each` — modern |
| Untyped / undescribed variables | 0 (all 90 `variable` blocks typed + described) |
| `provider` blocks inside child modules (anti-pattern) | 0 |
| Legacy `list()` / `map()` functions | 0 |
| `required_version` consistency | `">= 1.7, < 2.0"` everywhere |

The real debt is **structural inconsistency, copy-paste duplication, and a few correctness bugs** — not deprecated syntax.

## Findings by Severity

### CRITICAL

- **C1 — Hardcoded credentials in cloud-init.** `100-pve/terraform/vm_configs.tf:221,233-234` embeds `minioadmin/minioadmin` (BuildKit S3 cache access/secret keys) directly in runcmd. Must come from 1Password (`module.onepassword_secrets`).

### HIGH

- **B1 — Wrong provider version constraint (bug).** `215-synology/versions.tf:15-18` pins `aminueza/minio` at `~> 3.2`, but that provider is on the `0.x` line. `~> 3.2` is a non-existent major; this is a copy-paste artifact from the adjacent `onepassword ~> 3.2` block. Fix to match the resolved lockfile version (≈ `~> 0.6`).
- **S1 — Three conflicting directory conventions.** Nested `{ws}/terraform/` (100-pve, 105-elk, 102-traefik) vs flat `{ws}/` (215-synology) vs symlinked root (300-cloudflare: 20 `*.tf` at root are symlinks → `terraform/*.tf`, a Makefile compat shim). Docs (`CODE_STYLE.md:54-66`, `ARCHITECTURE.md:31-38`) describe the **flat** layout as canonical, which only 215-synology follows.
- **S2 — Makefile alias map inconsistent.** `ALIAS_pve := 100-pve` and `ALIAS_cloudflare := 300-cloudflare` point at directories with no real `.tf` at root (pve) or only symlinks (cloudflare), while `ALIAS_elk/traefik/archon := {ws}/terraform`. `make plan SVC=pve` resolves to a stateless/empty dir.
- **L1 — `lint-tflint` blind spot.** Makefile runs tflint against alias roots; for nested-layout workspaces the root has no `.tf`, so `terraform_standard_module_structure` and other rules silently scan empty dirs and pass.
- **L2 — Hardcoded IPs bypassing SSoT.** `vm_configs.tf:77,219,221,231` (`192.168.50.215`), `firewall.tf:70-71` (`192.168.50.0/24`) hardcode values that exist in `module.hosts` / `var.network_cidr`. Violates the repo's own "NO hardcoded IPs" rule.
- **L3 — 14 `null_resource` + `provisioner` sites.** `modules/proxmox/{lxc-config,vm-config}/main.tf`, `100-pve/terraform/backup_jobs.tf`, `300-cloudflare/terraform/secrets-store.tf`. The proxmox modules' own `AGENTS.md` mandates "NO local-exec; prefer `proxmox_virtual_environment_file`". Some are justified (no `bpg` resource for `cluster_backup_job`), others are migratable.

### MEDIUM

- **M1 — 100-pve root migration debris.** `100-pve/` root holds stale `terraform.tfstate.backup` (832 KB), `tfplan`, `tfplan-n8n`, `.terraform/`, `terraform.tfvars` while live code/state is in `100-pve/terraform/`. Incomplete root→subdir migration.
- **M2 — Child modules lack `versions.tf`.** All `modules/proxmox/*` + `modules/shared/*` inline `required_version`/`required_providers` in `main.tf` (CODE_STYLE.md:45 wants a separate `versions.tf`). Child modules use `~>` where HashiCorp recommends `>=` for reusables.
- **M3 — Port variables typed as `string`.** `215-synology/variables.tf:69,75,104` (`portainer_https_port`, `portainer_edge_port`, `registry_port`).
- **M4 — Fragile `count`.** `215-synology/main.tf:150` uses `count = length(minio_iam_user.console_admin)`; should mirror the upstream condition.
- **M5 — Stale documentation.** `ARCHITECTURE.md:31-38` and `CODE_STYLE.md:54-66` show layouts that no longer match disk; `ARCHITECTURE.md:211` claims tfstate is committed (it is git-ignored).

### Duplication (DRY targets)

| ID | Pattern | Sites | Extraction |
| --- | --- | --- | --- |
| D1 | `onepassword_vault_name` variable | 4 workspaces, identical | shared variable / module input |
| D2 | 1Password→var fallback (`effective_X`) | 12+ across 4 files | `onepassword_secret_with_fallback` helper |
| D3 | `versions.tf` boilerplate | 5 workspaces | shared versions convention |
| D4 | VM cloud-init SSH+fail2ban+docker | 3× verbatim in `vm_configs.tf` | `vm-cloud-init-baseline` |
| D5 | Cloudflare tunnel triple | 3× in `tunnel.tf` + 3 output files | `cloudflare/tunnel` module |
| D6 | `check "required_secrets"` | 4 workspaces | `onepassword_required_keys` helper |
| D7 | Proxmox firewall container-vs-vm | 2 near-identical pairs | `proxmox/firewall_rules` module |
| D8 | `cloudflare_dns_record` CNAME | 3× in `dns.tf` | `for_each` over a map |
| D9 | LXC cloud-init baseline | 4× in `lxc_configs.tf` | `lxc-cloud-init-baseline` |
| D10 | ELK ILM + index_template | 3+4 near-identical | `elasticstack/{ilm,index_template}` |
| D11 | `_svc_tpl` manual template registry | SSoT dup | derive from filesystem |
| D12 | IP/hex/url regex validation | 7+4+3 scattered | shared validation locals/module |

## Recommended Refactor Order (smallest blast radius first)

1. **R1 (correctness):** fix `215-synology` `minio ~> 3.2` → resolved `~> 0.x`.
2. **R2 (correctness):** fix `215-synology/main.tf:150` `count`.
3. **R3 (security):** move `minioadmin` creds → 1Password.
4. **R4 (structure):** pick ONE layout convention; remove 300-cloudflare symlinks + repoint Makefile alias.
5. **R5 (CI):** fix `lint-tflint` to scan `$(TF_DIR)`.
6. **R6 (cleanup):** remove 100-pve root migration debris.
7. **R7–R11 (DRY):** extract modules per the duplication table.
8. **R12 (docs):** sync `ARCHITECTURE.md` / `CODE_STYLE.md` to reality.
