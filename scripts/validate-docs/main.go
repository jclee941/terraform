// validate-docs.go — Documentation QA harness (stdlib-only)
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type issue struct {
	typeName string
	line     int
	message  string
}

type fileReport struct {
	path   string
	issues []issue
}

type summary struct {
	filesScanned         int
	filesWithIssues      int
	brokenLinks          int
	unpairedMermaid      int
	nonexistentDriftRef  int
	removedWorkspaceRef  int
	bazelGovernance      int
	keyDocsMissingMermaid int
}

// Patterns for detection
var (
	// Skip blocks
	terraformDocsStartRe = regexp.MustCompile(`(?i)<!--\s*BEGIN_TF_DOCS\s*-->`)
	terraformDocsEndRe   = regexp.MustCompile(`(?i)<!--\s*END_TF_DOCS\s*-->`)

	// Markdown link pattern: [text](path) where path is local (not URL)
	markdownLinkRe = regexp.MustCompile(`\[([^\]]+)\]\(([^)]+)\)`)

	// Mermaid fence patterns - use hex escape for backticks
	mermaidFenceStartRe = regexp.MustCompile("^" + "\x60\x60\x60" + "mermaid\\s*$")
	mermaidFenceEndRe   = regexp.MustCompile("^" + "\x60\x60\x60" + "\\s*$")

	// References to check
	driftDetectionRe   = regexp.MustCompile(`docs/runbooks/drift-detection\.md`)
	grafanaWorkspaceRe = regexp.MustCompile(`(?i)104-grafana/`)

	// Bazel governance patterns (outside ADR/archive context)
	bazelGovernanceRe = regexp.MustCompile(`(?i)\b(Bazel|BUILD\.bazel|OWNERS)\b`)

	// Key docs that should contain Mermaid diagrams after modernization
	keyDocsForMermaid = []string{
		"ARCHITECTURE.md",
		"DEPENDENCY_MAP.md",
		"AGENTS.md",
		"README.md",
	}
)

// Directory names to skip entirely (matches any path component)
var skipDirNames = map[string]bool{
	".terraform": true,
	".git":      true,
	"node_modules": true,
}

// Path prefixes to skip (matched against relative path from repo root)
var skipPathPrefixes = []string{
	"docs/archive/",
	".archive/",
	"thoughts/",
	".sisyphus/",
}

func main() {
	verbose := flag.Bool("verbose", false, "show detailed per-file and check output")
	checkMermaidDiagrams := flag.Bool("check-mermaid", false, "require Mermaid diagrams in key docs (post-modernization)")
	flag.Parse()

	repoRoot := detectRepoRoot()

	mdFiles, err := collectMarkdownFiles(repoRoot)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to enumerate markdown files: %v\n", err)
		os.Exit(1)
	}

	if len(mdFiles) == 0 {
		fmt.Println("Documentation Validator Report")
		fmt.Printf("Repo root: %s\n", repoRoot)
		fmt.Println("No markdown files found. Nothing to validate.")
		os.Exit(0)
	}

	reports := make([]fileReport, 0, len(mdFiles))
	sum := summary{filesScanned: len(mdFiles)}

	for _, filePath := range mdFiles {
		relPath, relErr := filepath.Rel(repoRoot, filePath)
		if relErr != nil {
			relPath = filePath
		}

		fileIssues, scanErr := validateFile(filePath, repoRoot, *checkMermaidDiagrams)
		if scanErr != nil {
			fileIssues = append(fileIssues, issue{
				typeName: "scan-error",
				line:     0,
				message:  scanErr.Error(),
			})
		}

		if len(fileIssues) > 0 {
			sum.filesWithIssues++
			for _, is := range fileIssues {
				switch is.typeName {
				case "broken-link":
					sum.brokenLinks++
				case "unpaired-mermaid":
					sum.unpairedMermaid++
				case "nonexistent-drift-ref":
					sum.nonexistentDriftRef++
				case "removed-workspace-ref":
					sum.removedWorkspaceRef++
				case "bazel-governance":
					sum.bazelGovernance++
				case "key-doc-missing-mermaid":
					sum.keyDocsMissingMermaid++
				}
			}
		}

		reports = append(reports, fileReport{path: relPath, issues: fileIssues})
	}

	printReport(repoRoot, reports, sum, *verbose)

	if sum.filesWithIssues > 0 {
		os.Exit(1)
	}

	os.Exit(0)
}

func detectRepoRoot() string {
	// Walk up to find .git directory as anchor
	dir, err := os.Getwd()
	if err == nil {
		for {
			if _, statErr := os.Stat(filepath.Join(dir, ".git")); statErr == nil {
				return dir
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
	}
	return "."
}

func shouldSkipPath(relPath string) bool {
	// Check if any path component matches skipDirNames
	parts := strings.Split(filepath.ToSlash(relPath), "/")
	for _, part := range parts {
		if skipDirNames[part] {
			return true
		}
	}

	// Check if path starts with any skip prefix
	relPathLower := strings.ToLower(relPath)
	for _, prefix := range skipPathPrefixes {
		if strings.HasPrefix(relPathLower, strings.ToLower(prefix)) {
			return true
		}
	}

	return false
}

func collectMarkdownFiles(repoRoot string) ([]string, error) {
	var files []string

	err := filepath.Walk(repoRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		relPath, err := filepath.Rel(repoRoot, path)
		if err != nil {
			return nil
		}

		// Skip paths matching our skip criteria
		if shouldSkipPath(relPath) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		// Skip subdirectory AGENTS.md files (sync-controlled)
		if info.Name() == "AGENTS.md" && relPath != "AGENTS.md" {
			return nil
		}

		if !info.IsDir() && strings.HasSuffix(strings.ToLower(info.Name()), ".md") {
			files = append(files, path)
		}

		return nil
	})

	return files, err
}

func validateFile(filePath string, repoRoot string, checkMermaid bool) ([]issue, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	issues := make([]issue, 0)
	scanner := bufio.NewScanner(f)

	inTerraformDocsBlock := false
	inMermaidBlock := false
	lineNo := 0

	// For checking if file contains mermaid diagrams
	hasMermaidDiagram := false

	// Get directory of current file for resolving relative links
	fileDir := filepath.Dir(filePath)

	for scanner.Scan() {
		lineNo++
		line := scanner.Text()

		// Track BEGIN_TF_DOCS / END_TF_DOCS blocks
		if terraformDocsStartRe.MatchString(line) {
			inTerraformDocsBlock = true
			continue
		}
		if terraformDocsEndRe.MatchString(line) {
			inTerraformDocsBlock = false
			continue
		}
		if inTerraformDocsBlock {
			continue
		}

		// Track mermaid blocks
		if mermaidFenceStartRe.MatchString(line) {
			inMermaidBlock = true
			continue
		}
		if inMermaidBlock && mermaidFenceEndRe.MatchString(line) {
			inMermaidBlock = false
			continue
		}
		if inMermaidBlock {
			hasMermaidDiagram = true
		}

		// Check for markdown links
		matches := markdownLinkRe.FindAllStringSubmatch(line, -1)
		for _, match := range matches {
			linkText := match[1]
			linkTarget := match[2]

			// Skip URLs
			if strings.HasPrefix(linkTarget, "http://") ||
				strings.HasPrefix(linkTarget, "https://") ||
				strings.HasPrefix(linkTarget, "mailto:") {
				continue
			}

			// Skip fragment-only links (e.g., [text](#section))
			if strings.HasPrefix(linkTarget, "#") {
				continue
			}

			// Resolve relative link
			var targetPath string
			if filepath.IsAbs(linkTarget) {
				targetPath = filepath.Join(repoRoot, linkTarget)
			} else {
				targetPath = filepath.Join(fileDir, linkTarget)
			}

			// Resolve the path (handle .., etc.)
			targetPath = filepath.Clean(targetPath)

			// Check if target exists (file or directory)
			if _, statErr := os.Stat(targetPath); statErr != nil {
				issues = append(issues, issue{
					typeName: "broken-link",
					line:     lineNo,
					message:  fmt.Sprintf("unresolved local link: [%s](%s) -> %s", linkText, linkTarget, targetPath),
				})
			}
		}

		// Check for drift-detection.md reference
		if driftDetectionRe.MatchString(line) {
			issues = append(issues, issue{
				typeName: "nonexistent-drift-ref",
				line:     lineNo,
				message:  "references docs/runbooks/drift-detection.md which does not exist",
			})
		}

		// Check for 104-grafana workspace reference
		if grafanaWorkspaceRe.MatchString(line) {
			issues = append(issues, issue{
				typeName: "removed-workspace-ref",
				line:     lineNo,
				message:  "references 104-grafana/ workspace which has been removed",
			})
		}

		// Check for Bazel governance language
		if bazelGovernanceRe.MatchString(line) {
			// Skip if in ADR or archive context
			relPath, _ := filepath.Rel(repoRoot, filePath)
			isADR := strings.Contains(relPath, "docs/adr/")
			isArchive := strings.Contains(relPath, "docs/archive/") || strings.Contains(relPath, ".archive/")

			if !isADR && !isArchive {
				issues = append(issues, issue{
					typeName: "bazel-governance",
					line:     lineNo,
					message:  "Bazel governance language found outside ADR/archive context",
				})
			}
		}
	}

	// Check for unclosed mermaid block at end of file
	if inMermaidBlock {
		issues = append(issues, issue{
			typeName: "unpaired-mermaid",
			line:     lineNo,
			message:  "unclosed ```mermaid block (no closing ```)",
		})
	}

	// Check for missing mermaid in key docs (post-modernization check)
	if checkMermaid {
		relPath, _ := filepath.Rel(repoRoot, filePath)
		for _, keyDoc := range keyDocsForMermaid {
			if relPath == keyDoc && !hasMermaidDiagram {
				issues = append(issues, issue{
					typeName: "key-doc-missing-mermaid",
					line:     0,
					message:  fmt.Sprintf("%s should contain Mermaid diagrams after modernization", keyDoc),
				})
			}
		}
	}

	return issues, scanner.Err()
}

func printReport(repoRoot string, reports []fileReport, sum summary, verbose bool) {
	fmt.Println("Documentation Validator Report")
	fmt.Printf("Repo root: %s\n", repoRoot)
	fmt.Printf("Files scanned: %d\n", sum.filesScanned)
	fmt.Println(strings.Repeat("=", 80))

	if sum.filesWithIssues == 0 {
		fmt.Println("Status: PASS (no issues found)")
		if verbose {
			for _, report := range reports {
				fmt.Printf("[ok] %s\n", report.path)
			}
		}
		return
	}

	fmt.Printf("Status: FAIL (%d file(s) with issues)\n", sum.filesWithIssues)

	for _, report := range reports {
		if len(report.issues) == 0 {
			if verbose {
				fmt.Printf("\n[ok] %s\n", report.path)
			}
			continue
		}

		fmt.Printf("\n[file] %s\n", report.path)
		for _, is := range report.issues {
			if is.line > 0 {
				fmt.Printf("  - [%s] line %d: %s\n", is.typeName, is.line, is.message)
			} else {
				fmt.Printf("  - [%s] %s\n", is.typeName, is.message)
			}
		}
	}

	fmt.Println("\nSummary:")
	fmt.Printf("  broken-link: %d\n", sum.brokenLinks)
	fmt.Printf("  unpaired-mermaid: %d\n", sum.unpairedMermaid)
	fmt.Printf("  nonexistent-drift-ref: %d\n", sum.nonexistentDriftRef)
	fmt.Printf("  removed-workspace-ref: %d\n", sum.removedWorkspaceRef)
	fmt.Printf("  bazel-governance: %d\n", sum.bazelGovernance)
	fmt.Printf("  key-doc-missing-mermaid: %d\n", sum.keyDocsMissingMermaid)
}
