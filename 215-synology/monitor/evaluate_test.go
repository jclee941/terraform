package main

import (
	"slices"
	"testing"
)

func TestEvaluateResources_reports_every_unhealthy_resource_class(t *testing.T) {
	// Given
	resources := []resource{
		{ID: "node/pve3", Type: "node", Node: "pve3", Status: "offline", CPU: 0.2, Mem: 50, MaxMem: 100},
		{ID: "qemu/200", Type: "qemu", Node: "pve3", Name: "dev", Status: "stopped"},
		{ID: "qemu/9000", Type: "qemu", Node: "pve3", Name: "template", Status: "stopped", Template: 1},
		{ID: "lxc/105", Type: "lxc", Node: "pve3", Name: "elk", Status: "running", CPU: 0.96, Mem: 50, MaxMem: 100},
		{ID: "storage/pve3/nas", Type: "storage", Node: "pve3", Storage: "nas", Status: "unavailable", Disk: 50, MaxDisk: 100},
		{ID: "storage/pve3/nvme", Type: "storage", Node: "pve3", Storage: "nvme", Status: "available", Disk: 91, MaxDisk: 100},
		{ID: "network/pve3/local", Type: "network", Node: "pve3", Status: "error"},
	}
	thresholds := thresholds{CPUPercent: 95, MemoryPercent: 95, DiskPercent: 90}

	// When
	result := evaluateResources(resources, thresholds)
	keys := make([]string, 0, len(result.Issues))
	for key := range result.Issues {
		keys = append(keys, key)
	}
	slices.Sort(keys)

	// Then
	want := []string{
		"pressure/cpu/lxc/105",
		"pressure/disk/storage/pve3/nvme",
		"status/network/pve3/local",
		"status/node/pve3",
		"status/qemu/200",
		"status/storage/pve3/nas",
	}
	if !slices.Equal(keys, want) {
		t.Fatalf("issue keys = %v, want %v", keys, want)
	}
}

func TestEvaluateResources_ignores_templates_and_healthy_values(t *testing.T) {
	// Given
	resources := []resource{
		{ID: "node/pve3", Type: "node", Node: "pve3", Status: "online", CPU: 0.5, Mem: 80, MaxMem: 100, Disk: 50, MaxDisk: 100},
		{ID: "qemu/9000", Type: "qemu", Node: "pve3", Name: "template", Status: "stopped", Template: 1},
	}

	// When
	result := evaluateResources(resources, thresholds{CPUPercent: 95, MemoryPercent: 95, DiskPercent: 90})

	// Then
	if len(result.Issues) != 0 {
		t.Fatalf("issues = %v, want none", result.Issues)
	}
	if _, ok := result.Observed["status/qemu/9000"]; ok {
		t.Fatal("template VM must not be observed")
	}
}
