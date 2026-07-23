# Cloudflare Service Token Rotation Guide

## Status

This guide is retained for historical reference only. Cloudflare Access resources
and the former GitHub Actions service-token flow are not active; `300-cloudflare/terraform/access.tf`
is a tombstone. Do not create, rotate, or restore the former
`CF_ACCESS_CLIENT_ID` and `CF_ACCESS_CLIENT_SECRET` credentials from this document.

## Current Access Path

- The active `cloudflared` connector runs as a native systemd service on cliproxy
  (VMID 114).
- HTTP and TCP services use the Cloudflare Tunnel origins documented in
  [`300-cloudflare/README.md`](../300-cloudflare/README.md).
- For connector incidents, use the
  [Cloudflare Tunnel troubleshooting procedure](runbooks/troubleshooting.md).

## Secret Handling

- Never commit tunnel tokens or other credentials.
- Keep current secret values in 1Password and GitHub Actions secrets as required by
  the active workflows.
- Do not use this retired Access-token procedure for current operations.

*Last Updated: 2026-07-23*
