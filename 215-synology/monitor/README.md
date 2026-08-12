# Proxmox Telegram Monitor

This monitor runs on the physical Synology NAS so it can still detect a full
Proxmox node outage. Every minute it checks the Proxmox cluster resources API
for node, VM, LXC, storage, and SDN network health. CPU, memory, and disk
pressure are also evaluated where the API exposes those values.

An alert is sent only after three consecutive unhealthy polls. State is kept
in the `proxmox-monitor-state` volume so container restarts do not duplicate
alerts. A recovery notification includes the full incident duration.

## Notification format

```text
🚨 장애 발생 · SEV-1 · PVE/VM/200 jclee-dev
가상 머신 중지
조건: status=stopped, expected=running · 3회 연속
시작: 08-12 10:01 KST · 지속: 2분
조치: VM 상태와 최근 작업을 확인
런북: https://github.com/qws941/terraform/blob/master/docs/runbooks/service-down.md
```

The status-first firing/resolved split, severity and target labels, observed
condition, duration, and runbook link follow these operational references:

- [Grafana notification templates](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/template-notifications/examples/)
- [Prometheus notification data](https://prometheus.io/docs/alerting/latest/notifications/)
- [Google SRE practical alerting](https://sre.google/sre-book/practical-alerting/)

## Local verification

```bash
go test -race -shuffle=on -count=1 ./...
go run . --help
go run . --once --dry-run
go run . --test-notification
```

Runtime credentials are injected from the existing 1Password `proxmox` and
`telegram` items by the `215-synology` Terraform workspace.
