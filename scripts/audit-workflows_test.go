package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func TestMainCIIsLocalSecretlessAndPinned(t *testing.T) {
	t.Parallel()

	workingDirectory, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}

	workflowPath := filepath.Join(filepath.Dir(workingDirectory), ".github", "workflows", "ci.yml")
	content, err := os.ReadFile(workflowPath)
	if err != nil {
		t.Fatalf("read %s: %v", workflowPath, err)
	}

	workflow := string(content)
	lowercaseWorkflow := strings.ToLower(workflow)

	for _, forbidden := range []string{
		"uses: jclee941/.github/",
		"uses: ./.github/workflows/",
		"secrets:",
		"secrets.",
		"environment:",
		"permissions: write-all",
		"@master",
		"@main",
		"contents: write",
		"apply",
		"plan",
		"drift",
		"backup",
		"verify",
	} {
		if strings.Contains(lowercaseWorkflow, forbidden) {
			t.Errorf("ci.yml contains forbidden reference %q", forbidden)
		}
	}

	writePermission := regexp.MustCompile(`(?m)^\s*[a-z-]+:\s*write\s*(?:#.*)?$`)
	if match := writePermission.FindString(workflow); match != "" {
		t.Errorf("ci.yml grants write permission: %s", strings.TrimSpace(match))
	}

	for _, required := range []string{
		"name: CI",
		"contents: read",
		"jobs:\n  ci:",
		"make lint-tf",
		"make validate SVC=pve",
		"make validate SVC=elk",
		"make validate SVC=synology",
		"make validate SVC=cloudflare",
		"make test",
		"make test-go",
		"make lint-docs",
	} {
		if !strings.Contains(workflow, required) {
			t.Errorf("ci.yml is missing required reference %q", required)
		}
	}

	expectedActions := map[string]struct{}{
		"step-security/harden-runner@bf7454d06d71f1098171f2acdf0cd4708d7b5920": {},
		"actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1":            {},
		"hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e":   {},
		"actions/setup-go@b7ad1dad31e06c5925ef5d2fc7ad053ef454303e":            {},
	}
	actionReference := regexp.MustCompile(`(?m)^\s*uses:\s*([^\s#]+)`)
	fullSHA := regexp.MustCompile(`^[^@\s]+@[0-9a-f]{40}$`)

	for _, match := range actionReference.FindAllStringSubmatch(workflow, -1) {
		reference := match[1]
		if !fullSHA.MatchString(reference) {
			t.Errorf("ci.yml action reference is not SHA-pinned: %s", reference)
		}
		if _, ok := expectedActions[reference]; !ok {
			t.Errorf("ci.yml action reference is not approved: %s", reference)
		}
		delete(expectedActions, reference)
	}

	for reference := range expectedActions {
		t.Errorf("ci.yml is missing approved action reference %s", reference)
	}
}
