//go:build setup_ilm

package main

import (
	"encoding/json"
	"testing"
)

func Test_ILMPolicyBody_compacts_indices_when_warm_age_is_set(t *testing.T) {
	// Given
	var policy struct {
		Policy struct {
			Phases struct {
				Warm struct {
					MinAge  string `json:"min_age"`
					Actions struct {
						ForceMerge struct {
							MaxNumSegments int    `json:"max_num_segments"`
							IndexCodec     string `json:"index_codec"`
						} `json:"forcemerge"`
					} `json:"actions"`
				} `json:"warm"`
			} `json:"phases"`
		} `json:"policy"`
	}

	// When
	err := json.Unmarshal([]byte(ilmPolicyBody("30d", "7d")), &policy)

	// Then
	if err != nil {
		t.Fatalf("decode ILM policy: %v", err)
	}
	if policy.Policy.Phases.Warm.MinAge != "7d" {
		t.Fatalf("warm minimum age = %q, want 7d", policy.Policy.Phases.Warm.MinAge)
	}
	if policy.Policy.Phases.Warm.Actions.ForceMerge.MaxNumSegments != 1 {
		t.Fatalf("force-merge segments = %d, want 1", policy.Policy.Phases.Warm.Actions.ForceMerge.MaxNumSegments)
	}
	if policy.Policy.Phases.Warm.Actions.ForceMerge.IndexCodec != "" {
		t.Fatalf("force-merge codec = %q, want no codec migration", policy.Policy.Phases.Warm.Actions.ForceMerge.IndexCodec)
	}
}

func Test_IndexTemplateBody_applies_log_storage_optimizations(t *testing.T) {
	// Given
	var indexTemplate struct {
		Template struct {
			Settings struct {
				Codec           string `json:"index.codec"`
				RefreshInterval string `json:"index.refresh_interval"`
			} `json:"settings"`
		} `json:"template"`
	}

	// When
	err := json.Unmarshal([]byte(indexTemplateBody([]string{"logs-*"}, "homelab-logs-30d", 200)), &indexTemplate)

	// Then
	if err != nil {
		t.Fatalf("decode index template: %v", err)
	}
	if indexTemplate.Template.Settings.Codec != "best_compression" {
		t.Fatalf("index codec = %q, want best_compression", indexTemplate.Template.Settings.Codec)
	}
	if indexTemplate.Template.Settings.RefreshInterval != "30s" {
		t.Fatalf("refresh interval = %q, want 30s", indexTemplate.Template.Settings.RefreshInterval)
	}
}
