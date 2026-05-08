// validate-docs_test.go — Tests for documentation QA harness
package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestStaleDriftDetectionRef tests that references to the nonexistent
// docs/runbooks/drift-detection.md are detected.
func TestValidateDocsStaleDriftDetectionRef(t *testing.T) {
	// Create temp dir structure
	tmpDir := t.TempDir()

	// Create a doc that references drift-detection.md
	docDir := filepath.Join(tmpDir, "docs")
	err := os.MkdirAll(docDir, 0755)
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	docContent := "## Test Doc\nSome content referencing the drift runbook.\nSee docs/runbooks/drift-detection.md for details.\n"
	docPath := filepath.Join(docDir, "test.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation
	issues, err := validateFile(docPath, tmpDir, false)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should have one issue about nonexistent drift-detection reference
	found := false
	for _, issue := range issues {
		if issue.typeName == "nonexistent-drift-ref" {
			found = true
			break
		}
	}

	if !found {
		t.Errorf("expected to find nonexistent-drift-ref issue, got: %v", issues)
	}
}

// TestRemovedWorkspaceReference tests that references to 104-grafana
// workspace (which was removed) are detected.
func TestValidateDocsRemovedWorkspaceReference(t *testing.T) {
	tmpDir := t.TempDir()

	// Create a doc that references 104-grafana
	docContent := "## Test Doc\nThe Grafana workspace 104-grafana has been migrated.\nSee 104-grafana/terraform/main.tf for details.\n"
	docPath := filepath.Join(tmpDir, "test.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation
	issues, err := validateFile(docPath, tmpDir, false)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should have one issue about removed workspace reference
	found := false
	for _, issue := range issues {
		if issue.typeName == "removed-workspace-ref" {
			found = true
			break
		}
	}

	if !found {
		t.Errorf("expected to find removed-workspace-ref issue, got: %v", issues)
	}
}

// TestUnpairedMermaidFence tests that unclosed mermaid blocks are detected.
func TestValidateDocsUnpairedMermaidFence(t *testing.T) {
	tmpDir := t.TempDir()

	// Create a doc with unpaired mermaid fence
	docContent := "## Test Doc\nSome content here.\n\n" +
		"```mermaid\n" +
		"graph TD\n" +
		"    A[Start] --> B{End}\n"
	docPath := filepath.Join(tmpDir, "test.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation
	issues, err := validateFile(docPath, tmpDir, false)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should have one issue about unpaired mermaid
	found := false
	for _, issue := range issues {
		if issue.typeName == "unpaired-mermaid" {
			found = true
			break
		}
	}

	if !found {
		t.Errorf("expected to find unpaired-mermaid issue, got: %v", issues)
	}
}

// TestBrokenLocalMarkdownLink tests that unresolved local markdown links are detected.
func TestValidateDocsBrokenLocalMarkdownLink(t *testing.T) {
	tmpDir := t.TempDir()

	// Create a doc with a broken local link
	docContent := "## Test Doc\nSee the [installation guide](./docs/installation.md) for details.\n"
	docPath := filepath.Join(tmpDir, "test.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation
	issues, err := validateFile(docPath, tmpDir, false)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should have one issue about broken link
	found := false
	for _, issue := range issues {
		if issue.typeName == "broken-link" {
			found = true
			break
		}
	}

	if !found {
		t.Errorf("expected to find broken-link issue, got: %v", issues)
	}
}

// TestValidLocalMarkdownLink tests that resolved local markdown links pass.
func TestValidateDocsValidLocalMarkdownLink(t *testing.T) {
	tmpDir := t.TempDir()

	// Create a doc with a valid local link
	docDir := filepath.Join(tmpDir, "docs")
	err := os.MkdirAll(docDir, 0755)
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	// Create both files
	docContent := "## Test Doc\nSee the [installation guide](./docs/installation.md) for details.\n"
	docPath := filepath.Join(tmpDir, "test.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	targetContent := "## Installation\nInstallation steps here.\n"
	targetPath := filepath.Join(docDir, "installation.md")
	if err := os.WriteFile(targetPath, []byte(targetContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation
	issues, err := validateFile(docPath, tmpDir, false)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should have no issues
	for _, issue := range issues {
		if issue.typeName == "broken-link" {
			t.Errorf("expected no broken-link issues, but found: %v", issue)
		}
	}
}

// TestBazelGovernanceOutsideADR tests that Bazel governance references
// outside ADR/archive context are flagged.
func TestValidateDocsBazelGovernanceOutsideADR(t *testing.T) {
	tmpDir := t.TempDir()

	// Create a doc with Bazel references outside ADR context
	docContent := "## Test Doc\nThis project uses Bazel for build governance.\nThe BUILD.bazel file defines the build rules.\n"
	docPath := filepath.Join(tmpDir, "test.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation
	issues, err := validateFile(docPath, tmpDir, false)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should have one issue about Bazel governance
	found := false
	for _, issue := range issues {
		if issue.typeName == "bazel-governance" {
			found = true
			break
		}
	}

	if !found {
		t.Errorf("expected to find bazel-governance issue, got: %v", issues)
	}
}

// TestBazelGovernanceInsideADR tests that Bazel governance references
// inside ADR context are NOT flagged.
func TestValidateDocsBazelGovernanceInsideADR(t *testing.T) {
	tmpDir := t.TempDir()

	// Create ADR directory structure
	adrDir := filepath.Join(tmpDir, "docs", "adr")
	err := os.MkdirAll(adrDir, 0755)
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	// Create an ADR doc with Bazel references
	docContent := "## ADR-001: Monorepo Structure with Bazel\n\nThis ADR describes the Bazel build system adoption.\n"
	docPath := filepath.Join(adrDir, "001-bazel-adoption.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation
	issues, err := validateFile(docPath, tmpDir, false)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should NOT have bazel-governance issue (it's in ADR context)
	for _, issue := range issues {
		if issue.typeName == "bazel-governance" {
			t.Errorf("expected no bazel-governance issue in ADR context, but found: %v", issue)
		}
	}
}

// TestTerraformDocsBlockSkipped tests that content inside BEGIN_TF_DOCS
// and END_TF_DOCS blocks is skipped.
func TestValidateDocsTerraformDocsBlockSkipped(t *testing.T) {
	tmpDir := t.TempDir()

	// Create a doc with terraform docs block containing invalid links
	docContent := "## Test Doc\nSome content.\n\n" +
		"<!-- BEGIN_TF_DOCS -->\n" +
		"## Requirements\n\n" +
		"| Name | Version |\n" +
		"|------|---------|\n" +
		"| terraform | ~> 1.0 |\n\n" +
		"[nonexistent](./nonexistent.md)\n" +
		"<!-- END_TF_DOCS -->\n\n" +
		"More content.\n"
	docPath := filepath.Join(tmpDir, "test.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation
	issues, err := validateFile(docPath, tmpDir, false)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should NOT have broken-link issue (link is inside terraform docs block)
	for _, issue := range issues {
		if issue.typeName == "broken-link" {
			if strings.Contains(issue.message, "nonexistent.md") {
				t.Errorf("expected broken-link to be skipped inside BEGIN_TF_DOCS block, but found: %v", issue)
			}
		}
	}
}

// TestCollectMarkdownFilesExclude tests that appropriate files/dirs are excluded.
func TestValidateDocsCollectMarkdownFilesExclude(t *testing.T) {
	tmpDir := t.TempDir()

	// Create various directories
	terraformDir := filepath.Join(tmpDir, ".terraform")
	gitDir := filepath.Join(tmpDir, ".git")
	archiveDir := filepath.Join(tmpDir, "docs", "archive")

	for _, dir := range []string{terraformDir, gitDir, archiveDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("failed to create temp dir: %v", err)
		}
	}

	// Create markdown files in various locations
	files := map[string]string{
		filepath.Join(tmpDir, "README.md"):                             "root readme",
		filepath.Join(tmpDir, ".terraform", "module.md"):              "should be skipped",
		filepath.Join(tmpDir, ".git", "docs.md"):                     "should be skipped",
		filepath.Join(tmpDir, "docs", "archive", "old.md"):           "should be skipped",
		filepath.Join(tmpDir, "docs", "current.md"):                  "should be included",
		filepath.Join(tmpDir, "subdir", "AGENTS.md"):                 "should be skipped (sync-controlled)",
		filepath.Join(tmpDir, "AGENTS.md"):                            "should be included (root)",
	}

	for path, content := range files {
		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			t.Fatalf("failed to create temp dir: %v", err)
		}
		if err := os.WriteFile(path, []byte(content), 0644); err != nil {
			t.Fatalf("failed to write temp file: %v", err)
		}
	}

	// Run collection
	mdFiles, err := collectMarkdownFiles(tmpDir)
	if err != nil {
		t.Fatalf("collectMarkdownFiles failed: %v", err)
	}

	// Build set of found files (relative to tmpDir)
	found := make(map[string]bool)
	for _, f := range mdFiles {
		rel, _ := filepath.Rel(tmpDir, f)
		found[rel] = true
	}

	// Check expected inclusions/exclusions
	if !found["README.md"] {
		t.Error("expected README.md to be included")
	}
	if !found["AGENTS.md"] {
		t.Error("expected root AGENTS.md to be included")
	}
	if !found["docs/current.md"] {
		t.Error("expected docs/current.md to be included")
	}

	if found[".terraform/module.md"] {
		t.Error("expected .terraform/module.md to be excluded")
	}
	if found[".git/docs.md"] {
		t.Error("expected .git/docs.md to be excluded")
	}
	if found["docs/archive/old.md"] {
		t.Error("expected docs/archive/old.md to be excluded")
	}
	if found["subdir/AGENTS.md"] {
		t.Error("expected subdir/AGENTS.md to be excluded (sync-controlled)")
	}
}

// TestKeyDocMissingMermaid tests that key docs missing mermaid diagrams are flagged
// when checkMermaid is true.
func TestValidateDocsKeyDocMissingMermaid(t *testing.T) {
	tmpDir := t.TempDir()

	// Create ARCHITECTURE.md without mermaid
	docContent := "## Architecture Overview\n\nThis is the architecture documentation.\nNo diagrams here.\n"
	docPath := filepath.Join(tmpDir, "ARCHITECTURE.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation with checkMermaid=true
	issues, err := validateFile(docPath, tmpDir, true)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should have one issue about missing mermaid
	found := false
	for _, issue := range issues {
		if issue.typeName == "key-doc-missing-mermaid" {
			found = true
			break
		}
	}

	if !found {
		t.Errorf("expected to find key-doc-missing-mermaid issue, got: %v", issues)
	}
}

// TestKeyDocWithMermaidPasses tests that key docs WITH mermaid diagrams pass
// when checkMermaid is true.
func TestValidateDocsKeyDocWithMermaidPasses(t *testing.T) {
	tmpDir := t.TempDir()

	// Create ARCHITECTURE.md with mermaid
	docContent := "## Architecture Overview\n\n" +
		"```mermaid\n" +
		"graph TD\n" +
		"    A[Start] --> B[End]\n" +
		"```\n"
	docPath := filepath.Join(tmpDir, "ARCHITECTURE.md")
	if err := os.WriteFile(docPath, []byte(docContent), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	// Run validation with checkMermaid=true
	issues, err := validateFile(docPath, tmpDir, true)
	if err != nil {
		t.Fatalf("validateFile failed: %v", err)
	}

	// Should NOT have key-doc-missing-mermaid issue
	for _, issue := range issues {
		if issue.typeName == "key-doc-missing-mermaid" {
			t.Errorf("expected no key-doc-missing-mermaid issue for doc with mermaid, but found: %v", issue)
		}
	}
}
