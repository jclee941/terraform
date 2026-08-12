package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"time"
)

type alertState struct {
	Issue     issue     `json:"issue"`
	Failures  int       `json:"failures"`
	StartedAt time.Time `json:"started_at"`
	Active    bool      `json:"active"`
	Notified  bool      `json:"notified"`
}

type persistedState struct {
	Alerts    map[string]alertState `json:"alerts"`
	UpdatedAt time.Time             `json:"updated_at"`
}

type stateMachine struct {
	threshold int
	state     persistedState
}

func newStateMachine(threshold int, state persistedState) *stateMachine {
	if state.Alerts == nil {
		state.Alerts = make(map[string]alertState)
	}
	return &stateMachine{threshold: threshold, state: state}
}

func (machine *stateMachine) evaluate(now time.Time, current evaluation) []alertEvent {
	keys := make([]string, 0, len(current.Observed))
	for key := range current.Observed {
		keys = append(keys, key)
	}
	slices.Sort(keys)

	events := make([]alertEvent, 0)
	for _, key := range keys {
		problem, unhealthy := current.Issues[key]
		entry, exists := machine.state.Alerts[key]
		if unhealthy {
			if !exists {
				entry = alertState{Issue: problem, StartedAt: now}
			}
			entry.Issue = problem
			entry.Failures++
			if entry.Failures >= machine.threshold {
				entry.Active = true
				if !entry.Notified {
					events = append(events, alertEvent{
						Kind: eventFiring, Issue: problem, StartedAt: entry.StartedAt,
						OccurredAt: now, Duration: now.Sub(entry.StartedAt), Confirmations: entry.Failures,
					})
				}
			}
			machine.state.Alerts[key] = entry
			continue
		}

		if !exists {
			continue
		}
		if entry.Active && entry.Notified {
			events = append(events, alertEvent{
				Kind: eventResolved, Issue: entry.Issue, StartedAt: entry.StartedAt,
				OccurredAt: now, Duration: now.Sub(entry.StartedAt), Confirmations: entry.Failures,
			})
			continue
		}
		delete(machine.state.Alerts, key)
	}
	return events
}

func (machine *stateMachine) markSent(event alertEvent) {
	switch event.Kind {
	case eventFiring:
		entry := machine.state.Alerts[event.Issue.Key]
		entry.Notified = true
		machine.state.Alerts[event.Issue.Key] = entry
	case eventResolved:
		delete(machine.state.Alerts, event.Issue.Key)
	}
}

func loadState(path string) (persistedState, error) {
	content, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return persistedState{Alerts: make(map[string]alertState)}, nil
	}
	if err != nil {
		return persistedState{}, fmt.Errorf("read monitor state: %w", err)
	}
	var state persistedState
	if err := json.Unmarshal(content, &state); err != nil {
		return persistedState{}, fmt.Errorf("decode monitor state: %w", err)
	}
	return state, nil
}

func saveState(path string, now time.Time, state persistedState) error {
	state.UpdatedAt = now
	content, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("encode monitor state: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("create state directory: %w", err)
	}
	temporary := path + ".tmp"
	if err := os.WriteFile(temporary, content, 0o600); err != nil {
		return fmt.Errorf("write monitor state: %w", err)
	}
	if err := os.Rename(temporary, path); err != nil {
		return fmt.Errorf("replace monitor state: %w", err)
	}
	return nil
}
