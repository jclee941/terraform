#!/bin/bash
# GitLab Runner 모니터링 스크립트

set -e

PVE_HOST="192.168.50.100"
VMID="101"

echo "========================================="
echo "GitLab Runner (LXC $VMID) 모니터링"
echo "========================================="
echo ""

echo "[1/5] LXC 상태 확인..."
ssh root@$PVE_HOST "pct status $VMID"
echo ""

echo "[2/5] 리소스 사용량..."
ssh root@$PVE_HOST "pct exec $VMID -- free -h 2>/dev/null || echo '메모리 정보 가져오기 실패'"
echo ""

echo "[3/5] Runner 상태..."
ssh root@$PVE_HOST "pct exec $VMID -- gitlab-runner status 2>&1"
echo ""

echo "[4/5] Docker 상태..."
ssh root@$PVE_HOST "pct exec $VMID -- docker info --format 'Containers: {{.Containers}} | Images: {{.Images}} | Storage Driver: {{.Driver}}' 2>/dev/null || echo 'Docker 정보 가져오기 실패'"
echo ""

echo "[5/5] 최근 로그 (마지막 10줄)..."
ssh root@$PVE_HOST "pct exec $VMID -- journalctl -u gitlab-runner --since '10 minutes ago' --no-pager 2>/dev/null | tail -10 || echo '로그 가져오기 실패'"
echo ""

echo "========================================="
echo "모니터링 완료"
echo "========================================="
