package main

import (
	"reflect"
	"testing"
)

func TestAuthenticatedRepoURL(t *testing.T) {
	got, err := authenticatedRepoURL("https://github.com/qws941/terraform.git", "token-123")
	if err != nil {
		t.Fatalf("authenticatedRepoURL returned error: %v", err)
	}
	want := "https://x-access-token:token-123@github.com/qws941/terraform.git"
	if got != want {
		t.Fatalf("authenticatedRepoURL mismatch\nwant: %s\n got: %s", want, got)
	}
}

func TestAuthenticatedRepoURLRejectsNonHTTPS(t *testing.T) {
	if _, err := authenticatedRepoURL("ssh://git@github.com/qws941/terraform.git", "token-123"); err == nil {
		t.Fatal("authenticatedRepoURL should reject non-https URLs")
	}
}

func TestWorkspaceNames(t *testing.T) {
	got := workspaceNames([]target{
		{Name: "github"},
		{Name: "github"},
		{Name: "traefik"},
	})
	want := []string{"github", "traefik"}
	if len(got) != len(want) {
		t.Fatalf("workspaceNames length mismatch: want %d got %d", len(want), len(got))
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("workspaceNames[%d] mismatch: want %s got %s", i, want[i], got[i])
		}
	}
}

func TestResolveTargetsDefaultAllowlist(t *testing.T) {
	result, err := resolveTargets(nil)
	if err != nil {
		t.Fatalf("resolveTargets returned error: %v", err)
	}
	want := []string{"traefik", "archon", "github"}
	if got := workspaceNames(result.AutoApply); !reflect.DeepEqual(got, want) {
		t.Fatalf("default auto-apply mismatch: got %v want %v", got, want)
	}
}

func TestResolveTargetsSharedModuleFanout(t *testing.T) {
	result, err := resolveTargets([]string{"modules/shared/onepassword-secrets/main.tf"})
	if err != nil {
		t.Fatalf("resolveTargets returned error: %v", err)
	}
	if got := workspaceNames(result.AutoApply); !reflect.DeepEqual(got, []string{"github"}) {
		t.Fatalf("shared module auto-apply mismatch: got %v", got)
	}
	if got := workspaceNames(result.ReportOnly); !reflect.DeepEqual(got, []string{"proxmox"}) {
		t.Fatalf("shared module report-only mismatch: got %v", got)
	}
}
