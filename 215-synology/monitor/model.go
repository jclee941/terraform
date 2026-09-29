package main

import "time"

type resource struct {
	ID       string  `json:"id"`
	Type     string  `json:"type"`
	Node     string  `json:"node"`
	Name     string  `json:"name"`
	Storage  string  `json:"storage"`
	Status   string  `json:"status"`
	Template int     `json:"template"`
	CPU      float64 `json:"cpu"`
	Mem      float64 `json:"mem"`
	MaxMem   float64 `json:"maxmem"`
	Disk     float64 `json:"disk"`
	MaxDisk  float64 `json:"maxdisk"`
}

type clusterResourcesResponse struct {
	Data []resource `json:"data"`
}

type thresholds struct {
	CPUPercent    float64
	MemoryPercent float64
	DiskPercent   float64
}

type issue struct {
	Key       string `json:"key"`
	Severity  string `json:"severity"`
	Target    string `json:"target"`
	Summary   string `json:"summary"`
	Condition string `json:"condition"`
	Action    string `json:"action"`
}

type evaluation struct {
	Issues   map[string]issue
	Observed map[string]struct{}
}

type eventKind string

const (
	eventFiring   eventKind = "firing"
	eventResolved eventKind = "resolved"
)

type alertEvent struct {
	Kind          eventKind
	Issue         issue
	StartedAt     time.Time
	OccurredAt    time.Time
	Duration      time.Duration
	Confirmations int
}
