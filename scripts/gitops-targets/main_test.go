package main

import (
	"reflect"
	"testing"
)

func TestBuildPlan(t *testing.T) {
	tests := []struct {
		name           string
		mode           string
		selectors      []string
		changedPaths   []string
		wantAutoApply  []string
		wantReportOnly []string
		wantErr        bool
	}{
		{
			name:          "default allowlist for scheduled reconcile",
			mode:          "reconcile",
			wantAutoApply: []string{"traefik", "archon", "github"},
		},
		{
			name:           "selector routes proxmox to report only",
			mode:           "dry-run",
			selectors:      []string{"100-pve"},
			wantReportOnly: []string{"proxmox"},
		},
		{
			name:          "selector routes github to auto apply",
			mode:          "dry-run",
			selectors:     []string{"github"},
			wantAutoApply: []string{"github"},
		},
		{
			name:          "changed path de-duplicates workspace",
			mode:          "reconcile",
			changedPaths:  []string{"108-archon/templates/app.env.tftpl", "108-archon/terraform/main.tf"},
			wantAutoApply: []string{"archon"},
		},
		{
			name:           "module change is report only",
			mode:           "reconcile",
			changedPaths:   []string{"modules/proxmox/lxc/main.tf"},
			wantReportOnly: []string{"proxmox"},
		},
		{
			name:           "shared onepassword module fans out to github and proxmox",
			mode:           "reconcile",
			changedPaths:   []string{"modules/shared/onepassword-secrets/main.tf"},
			wantAutoApply:  []string{"github"},
			wantReportOnly: []string{"proxmox"},
		},
		{
			name:           "mixed paths split safe and manual targets",
			mode:           "reconcile",
			changedPaths:   []string{"301-github/repositories.tf", "modules/shared/onepassword-secrets/main.tf"},
			wantAutoApply:  []string{"github"},
			wantReportOnly: []string{"proxmox"},
		},
		{
			name:      "invalid selector errors",
			mode:      "dry-run",
			selectors: []string{"missing"},
			wantErr:   true,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			plan, err := buildPlan(test.mode, test.selectors, test.changedPaths)
			if test.wantErr {
				if err == nil {
					t.Fatalf("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("buildPlan returned error: %v", err)
			}

			if got := collectNames(plan.AutoApply); !reflect.DeepEqual(got, test.wantAutoApply) {
				t.Fatalf("auto apply mismatch: got %v want %v", got, test.wantAutoApply)
			}
			if got := collectNames(plan.ReportOnly); !reflect.DeepEqual(got, test.wantReportOnly) {
				t.Fatalf("report-only mismatch: got %v want %v", got, test.wantReportOnly)
			}
		})
	}
}

func collectNames(targets []target) []string {
	if len(targets) == 0 {
		return nil
	}
	names := make([]string, 0, len(targets))
	for _, target := range targets {
		names = append(names, target.Name)
	}
	return names
}
