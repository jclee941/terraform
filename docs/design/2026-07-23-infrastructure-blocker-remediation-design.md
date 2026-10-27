# Infrastructure Blocker Remediation Design

**Status:** Approved
**Date:** 2026-07-23
**Scope:** Repository changes only; no Terraform apply or live infrastructure mutation

## Context

The infrastructure review found four repository-controlled blockers that can be
fixed without redesigning the whole homelab:

1. An unauthenticated public Cloudflare Tunnel route exposes Logstash HTTP ingest.
2. The declared Proxmox backup jobs disagree with the working live PBS storage and
   guest schedule.
3. The Terraform state backup tool resolves the repository and state locations
   incorrectly.
4. The main CI workflow calls a reusable workflow that no longer exists on the
   referenced branch, uses a mutable revision, and inherits all repository secrets.

TLS trust, Cloudflare Access restoration, and Proxmox east-west firewall policy
remain important but require trust-policy decisions and coordinated live rollout.
They are deliberately excluded from this implementation phase.

## Goals

1. Remove unauthenticated Internet access to Logstash ingest while preserving
   internal Beats and service-to-service ingestion.
2. Make the declared PBS backup jobs match the currently working production
   schedule and storage identifier.
3. Back up every active local Terraform state from its real workspace root and
   fail when a requested workspace cannot be backed up.
4. Replace the missing shared CI dependency with repository-local, secretless checks
   that exercise this monorepo's real Terraform and Go validation contracts.
5. Add regression coverage that fails if these contracts drift again.

## Non-Goals

- Applying Terraform or changing `/etc/pve/jobs.cfg` during this work.
- Restoring Cloudflare Access applications or issuing service tokens.
- Replacing self-signed certificates or enabling the Proxmox firewall.
- Migrating Terraform state to a remote backend.
- Resizing running guests.

## Design

### 1. Close the public Logstash route

Remove `logstash-ingest` from the Cloudflare tunnel ingress and DNS records. Remove
the Cloudflare Logpush job that targets that hostname so Terraform does not retain a
permanently unreachable delivery job. No replacement public endpoint is introduced.
Filebeat and other internal clients continue to use the ELK host directly on the
private network; the existing Logstash inputs remain available only to private
clients.

Regression coverage must verify that:

- the public hostname is absent from managed DNS records;
- no tunnel ingress rule targets Logstash HTTP port 8080;
- no Cloudflare Logpush job targets the retired hostname;
- internal Logstash inputs remain in the ELK template.

### 2. Converge PBS backup declarations

Use `pbs-backup` as the only Proxmox storage identifier. Preserve the working
production schedule:

| Job | Schedule | VMIDs | Storage |
|-----|----------|-------|---------|
| `lxc-daily` | `02:00` | `114` | `pbs-backup` |
| `lxc-weekly` | `sun 03:00` | `105` | `pbs-backup` |
| `vm-daily` | `04:00` | `200,220` | `pbs-backup` |

The implementation must not write `/etc/pve/jobs.cfg` directly. It manages each of
the three owned jobs independently through `pvesh` (`create` when absent, `set` when
present), then reads the job back through the same API. Unrelated jobs are never
deleted or rewritten. No live execution occurs in this phase.

Regression coverage must assert the storage identifier, VMID membership, unique
job IDs, and preservation strategy.

### 3. Repair Terraform state backup

The Go tool receives the repository root from its working directory or an explicit
CLI argument instead of deriving it from the temporary `go run` executable path.
It owns the explicit active local-backend workspace roots `100-pve/terraform`,
`105-elk/terraform`, `215-synology`, and `300-cloudflare/terraform`, and invokes
`terraform state pull` in each selected root.

For every workspace, the tool:

1. verifies that the workspace declares a local backend;
2. runs `terraform state pull` without printing state content;
3. writes the state into the existing encrypted backup flow;
4. reports the workspace name and artifact path, never secret values;
5. returns a non-zero exit status if any requested workspace fails.

The repository permanently ignores `.backups/`. Backend detection accepts only active
`backend "local"` declarations, and command failures retain diagnostic stderr without
including state content or the backup passphrase.

A dry-run or list mode exposes the selected workspaces without reading state. Unit
tests cover repository-root resolution, workspace selection, missing-state errors,
and command failures. An end-to-end test runs the CLI against a temporary fixture
repository with a fake Terraform executable.

### 4. Replace the missing shared CI with local checks

The reusable workflow is absent from the current `jclee941/.github` default branch,
and the last revision that contained it only discovers root-level Go modules and
Terraform files. It therefore cannot provide meaningful coverage for this repository.
Replace the caller with one local `ci` job while preserving the existing workflow
name, triggers, concurrency group, job ID, and read-only contents permission.

The job runs on a GitHub-hosted runner, uses SHA-pinned checkout, Terraform setup,
Go setup, and runner-hardening actions, installs Terraform 1.10.5 and Go 1.22.2, and
executes repository-owned Make targets for Terraform formatting, validation, native
Terraform tests, Go tests, and documentation validation. It receives no production
secrets and never runs plan, apply, drift, backup, or live verification commands.

The PVE and Cloudflare tests live in each production root's `tests/` directory and run
through `terraform -chdir=<root> test -filter=tests/<file>`. Each Make recipe initializes
its production root with `-backend=false` first, so the test targets work independently
from a clean checkout while preserving provider and import semantics.

Regression coverage rejects reusable workflow calls, mutable action references, secret
expressions, deployment environments, and any write permission in the main CI workflow.

## Failure Handling

- Terraform and CI validation fail closed on malformed routes, backup jobs, missing
  tests, mutable action references, or secret-bearing CI configuration.
- State backup continues through independent workspaces to collect all failures,
  then exits non-zero with a workspace summary.
- Temporary state and encrypted artifacts are created with owner-only permissions.
- No state contents, credentials, or resolved 1Password values are logged.

## Verification

1. Run focused failing tests before each implementation change.
2. Run Go tests with race detection and shuffled order.
3. Run Terraform formatting and validation for PVE, ELK, Synology, and Cloudflare.
4. Run native Terraform tests through the production-root test-directory contract.
5. Run the state-backup CLI in list/dry-run mode through its public interface.
6. Inspect the rendered Cloudflare plan surface to confirm the public Logstash route
   is absent without applying it.
7. Run the same secretless commands declared by the local CI job.
8. Confirm the repository has no unintended changes outside this design.

## Rollout

This phase stops after repository verification. A later operator-controlled rollout
must plan Cloudflare first, verify the hostname is no longer reachable, then plan
PVE backup-job convergence and inspect the proposed job diff before apply.

## Follow-Up Work

1. Establish internal CA or certificate pinning for Proxmox, PBS, and Synology.
2. Replace PBS root credentials with a least-privilege API token.
3. Decide whether to restore Cloudflare Access or formally supersede the existing
   Access architecture decision.
4. Enable default-deny Proxmox firewall policy after traffic inventory.
5. Reduce guest memory allocation and validate host reserve targets.
