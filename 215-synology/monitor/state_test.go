package main

import (
	"testing"
	"time"
)

func TestStateMachine_emits_firing_then_resolved_after_threshold(t *testing.T) {
	// Given
	now := time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC)
	machine := newStateMachine(3, persistedState{Alerts: map[string]alertState{}})
	problem := issue{
		Key:       "status/qemu/200",
		Severity:  "SEV-1",
		Target:    "PVE/VM/200 dev",
		Summary:   "가상 머신 중지",
		Condition: "status=stopped",
		Action:    "VM 상태와 최근 작업을 확인",
	}
	unhealthy := evaluation{
		Issues:   map[string]issue{problem.Key: problem},
		Observed: map[string]struct{}{problem.Key: {}},
	}
	healthy := evaluation{Issues: map[string]issue{}, Observed: map[string]struct{}{problem.Key: {}}}

	// When
	if events := machine.evaluate(now, unhealthy); len(events) != 0 {
		t.Fatalf("first failure events = %v, want none", events)
	}
	if events := machine.evaluate(now.Add(time.Minute), unhealthy); len(events) != 0 {
		t.Fatalf("second failure events = %v, want none", events)
	}
	firing := machine.evaluate(now.Add(2*time.Minute), unhealthy)

	// Then
	if len(firing) != 1 || firing[0].Kind != eventFiring {
		t.Fatalf("firing events = %v, want one firing", firing)
	}
	machine.markSent(firing[0])
	resolved := machine.evaluate(now.Add(7*time.Minute), healthy)
	if len(resolved) != 1 || resolved[0].Kind != eventResolved {
		t.Fatalf("resolved events = %v, want one resolved", resolved)
	}
	if resolved[0].Duration != 7*time.Minute {
		t.Fatalf("duration = %s, want 7m", resolved[0].Duration)
	}
}

func TestStateMachine_suppresses_transient_failure(t *testing.T) {
	// Given
	now := time.Date(2026, 8, 12, 0, 0, 0, 0, time.UTC)
	machine := newStateMachine(3, persistedState{Alerts: map[string]alertState{}})
	problem := issue{Key: "api/control-plane", Severity: "SEV-1", Target: "PVE/API"}
	unhealthy := evaluation{Issues: map[string]issue{problem.Key: problem}, Observed: map[string]struct{}{problem.Key: {}}}
	healthy := evaluation{Issues: map[string]issue{}, Observed: map[string]struct{}{problem.Key: {}}}

	// When
	first := machine.evaluate(now, unhealthy)
	second := machine.evaluate(now.Add(time.Minute), healthy)

	// Then
	if len(first) != 0 || len(second) != 0 {
		t.Fatalf("events = %v then %v, want none", first, second)
	}
}
