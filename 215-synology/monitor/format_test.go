package main

import (
	"strings"
	"testing"
	"time"
)

func TestFormatEvent_includes_operational_fields_for_firing(t *testing.T) {
	// Given
	event := alertEvent{
		Kind: eventFiring,
		Issue: issue{
			Severity:  "SEV-1",
			Target:    "PVE/Node/pve3",
			Summary:   "Proxmox 노드 응답 불가",
			Condition: "status=offline · 3회 연속",
			Action:    "노드 전원과 관리 네트워크를 확인",
		},
		StartedAt:  time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC),
		OccurredAt: time.Date(2026, 8, 12, 0, 2, 0, 0, time.UTC),
		Duration:   2 * time.Minute,
	}

	// When
	message := formatEvent(event, "https://example.com/runbook")

	// Then
	for _, field := range []string{"장애 발생", "SEV-1", "PVE/Node/pve3", "조건:", "시작:", "지속:", "조치:", "런북:"} {
		if !strings.Contains(message, field) {
			t.Fatalf("message missing %q: %s", field, message)
		}
	}
}

func TestFormatEvent_includes_duration_and_end_for_recovery(t *testing.T) {
	// Given
	event := alertEvent{
		Kind:       eventResolved,
		Issue:      issue{Severity: "SEV-2", Target: "PVE/Storage/nvme", Summary: "스토리지 사용량 임계치 초과", Action: "용량 추세를 확인"},
		StartedAt:  time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC),
		OccurredAt: time.Date(2026, 8, 12, 0, 8, 0, 0, time.UTC),
		Duration:   8 * time.Minute,
	}

	// When
	message := formatEvent(event, "")

	// Then
	for _, field := range []string{"복구 완료", "해소:", "지속:", "종료:", "후속:"} {
		if !strings.Contains(message, field) {
			t.Fatalf("message missing %q: %s", field, message)
		}
	}
}
