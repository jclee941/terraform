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

- **C1 — Hardcoded credentials in cloud-init.** `100-pve/terraform/vm_configs.tf:221,233-234` embedded `minioadmin/minioadmin` (BuildKit S3 cache access/secret keys) directly in runcmd. **[RESOLVED in R3, commit d5df3d0; hardened in R3b, commit 386dbaf]** — all 5 literals now resolve from `module.onepassword_secrets.secrets["registry_minio_*"]` (with `enable_registry = true`). `grep minioadmin 100-pve/terraform/vm_configs.tf` returns 0; the only remaining `minioadmin` strings in the workspace are inside the R3b guard in `checks.tf` (which rejects that value). Residual: the shared module still has a `"minioadmin"` default fallback in `outputs.tf:64` when the 1Password `registry` item is absent — that line lives in in-flight onepassword work and is out of this refactor's scope; R3b's blocking guard fails `terraform plan` if that fallback ever reaches 100-pve.

### HIGH

- **B1 — ~~Wrong provider version constraint~~ [DROPPED — false positive].** Initial scan flagged `215-synology/versions.tf` `aminueza/minio "~> 3.2"` as a non-existent major. Verified against the lockfile: `aminueza/minio` resolves to `3.34.0`, i.e. it genuinely is on the `3.x` line. `~> 3.2` is CORRECT. No change made.
- **S1 — Three conflicting directory conventions.** Nested `{ws}/terraform/` (100-pve, 105-elk, 102-traefik) vs flat `{ws}/` (215-synology) vs symlinked root (300-cloudflare: 20 `*.tf` at root are symlinks → `terraform/*.tf`, a Makefile compat shim). Docs (`CODE_STYLE.md:54-66`, `ARCHITECTURE.md:31-38`) describe the **flat** layout as canonical, which only 215-synology follows.
- **S2 — Makefile alias map inconsistent.** `ALIAS_pve := 100-pve` and `ALIAS_cloudflare := 300-cloudflare` point at directories with no real `.tf` at root (pve) or only symlinks (cloudflare), while `ALIAS_elk/traefik/archon := {ws}/terraform`. `make plan SVC=pve` resolves to a stateless/empty dir.
- **L1 — `lint-tflint` blind spot.** Makefile runs tflint against alias roots; for nested-layout workspaces the root has no `.tf`, so `terraform_standard_module_structure` and other rules silently scan empty dirs and pass.
- **L2 — Hardcoded IPs bypassing SSoT.** `vm_configs.tf:77,219,221,231` (`192.168.50.215`), `firewall.tf:70-71` (`192.168.50.0/24`) hardcode values that exist in `module.hosts` / `var.network_cidr`. Violates the repo's own "NO hardcoded IPs" rule.
- **L3 — 14 `null_resource` + `provisioner` sites.** `modules/proxmox/{lxc-config,vm-config}/main.tf`, `100-pve/terraform/backup_jobs.tf`, `300-cloudflare/terraform/secrets-store.tf`. The proxmox modules' own `AGENTS.md` mandates "NO local-exec; prefer `proxmox_virtual_environment_file`". Some are justified (no `bpg` resource for `cluster_backup_job`), others are migratable.

### MEDIUM

- **M1 — 100-pve root migration debris.** `100-pve/` root holds stale `terraform.tfstate.backup` (832 KB), `tfplan`, `.terraform/`, `terraform.tfvars` while live code/state is in `100-pve/terraform/`. Incomplete root→subdir migration.
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

## Execution Status (what was actually done)

Executed as the R2-R12 refactor commits plus follow-up hardening/verification/report commits on `master` (not pushed). `terraform apply` never run (CI/CD only); verified via `terraform validate` / `terraform test` (plan-level, mock providers) / `terraform fmt`.

| ID | Status | Commit | Note |
| --- | --- | --- | --- |
| R1 | DROPPED | — | False positive: `aminueza/minio 3.34.0`, `~> 3.2` correct. |
| R2 | DONE | `3528944` | synology minio policy count mirrors upstream condition; both states pinned by test. |
| R3 | DONE | `d5df3d0` | 5 `minioadmin` literals → 1Password; `enable_registry=true` wired; `grep minioadmin 100-pve/terraform/vm_configs.tf` = 0. |
| R3b | DONE | `386dbaf` | Blocking `terraform_data` lifecycle precondition (not a warn-only `check`) fails plan when `enable_registry=true` and registry user/password are empty or still `minioadmin`; static-assertion test in `pve_test`. (Superseded the initial check-block attempt `618cb40`.) |
| R4 | DONE | `98f6c43` | 20 cloudflare root symlinks removed; nested convention. |
| R5 | DONE | `d31fc15` | fmt/lint scan real `.tf` dirs (`TF_WORKSPACE_DIRS`); fixed broken `XY\|lint` target; aliases repointed. |
| R5b | DONE | `4c4dd40` | Repointed stale workspace-test module sources (pve 22, cloudflare 18) to nested `terraform/`. |
| R6 | DONE | (no commit) | Removed `100-pve/{terraform.tfstate.backup,tfplan,.terraform}` (all git-untracked, so nothing to commit). |
| R7 | DROPPED | — | Collided with in-flight onepassword cleanup; user agreed to skip. |
| R8 | DONE | `92a0a1c` | `modules/proxmox/firewall` + 4 `moved{}` blocks. |
| R9 | DONE | `fe7e685` | `modules/cloudflare/tunnel` for_each + 8 `moved{}` blocks. |
| R10 | DONE | `730bcf5` | `cloud_init_baseline.tf` locals; `concat`-equivalent runcmd ordering. |
| R11 | DONE | `f48fa40` | `modules/elasticstack/{ilm_policy,index_template}` + 7 `moved{}` blocks. |
| R12 | DONE | `c028e1b` | ARCHITECTURE.md/CODE_STYLE.md synced; false "tfstate committed" claim fixed. |

## Verification limits (honest disclosure)

- **State-move safety is NOT plan-verified.** No provider credentials locally and `apply` is CI-only, so `terraform plan` was not run against real state for R8/R9/R11. The `moved{}` blocks were hand-mapped from the pre-refactor resource addresses and validated structurally (`terraform validate` + plan-level module tftests). Claim should read "moved blocks written and structurally correct", NOT "proven no destroy/recreate". **A real `terraform plan` in CI must confirm no destroy/recreate before merge.**
- **ELK `moved{}` count vs live state:** current `terraform state list` for 105-elk holds only 3 ILM + 3 index_template resources; `logs_cloudflare_workers` is in config but not yet in state. Its `moved{}` block is harmless (Terraform ignores a `from` that isn't in state) but means the "7 resources moved" claim is config-level, not state-level.
- **pve workspace `terraform test` is not fully green:** remaining `check`-block failures (`mcphub_*` secrets) stem from the in-flight onepassword cleanup (uncommitted, out of scope), not from this refactor. New R3/R10 run blocks pass.
- **`make lint-docs` fails on a pre-existing `removed-workspace-ref` (104-grafana)** in auto-synced agent notepads/AGENTS.md — pre-existing, left untouched.
- **In-flight onepassword work preserved:** none of the refactor commits touched `100-pve/terraform/locals.tf`, `300-cloudflare/terraform/{onepassword,identity-provider,variables}.tf`, `modules/shared/onepassword-secrets/outputs.tf`, or `tests/modules/shared/onepassword_secrets_test.tftest.hcl`. Those remain unstaged in the working tree.
