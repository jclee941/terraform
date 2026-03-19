package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
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
	filesScanned       int
	filesWithIssues    int
	duplicateSteps     int
	destructiveCommand int
	missingPath        int
	headingHierarchy   int
}

var (
	stepHeadingRe = regexp.MustCompile(`(?i)^#{2,6}\s*step\s+([0-9]+)\b`)
	numberedRe    = regexp.MustCompile(`^#{2,6}\s*([0-9]+)\.\s+`)
	headingRe     = regexp.MustCompile(`^(#{1,6})\s+\S`)

	fenceStartRe = regexp.MustCompile("^```\\s*([a-zA-Z0-9_-]*)\\s*$")
	fenceEndRe   = regexp.MustCompile("^```\\s*$")

	tokenRe = regexp.MustCompile(`[^\s"'()\[\]{}<>|;]+`)

	destructivePatterns = []struct {
		name string
		re   *regexp.Regexp
	}{
		{name: "rm -rf", re: regexp.MustCompile(`(?i)\brm\s+-rf\b`)},
		{name: "drop table", re: regexp.MustCompile(`(?i)\bdrop\s+table\b`)},
		{name: "drop database", re: regexp.MustCompile(`(?i)\bdrop\s+database\b`)},
		{name: "truncate", re: regexp.MustCompile(`(?i)\btruncate\b`)},
		{name: "format", re: regexp.MustCompile(`(?i)\bformat\b`)},
		{name: "mkfs", re: regexp.MustCompile(`(?i)\bmkfs\b`)},
		{name: "dd if=", re: regexp.MustCompile(`(?i)\bdd\s+if=`)},
		{name: "fdisk", re: regexp.MustCompile(`(?i)\bfdisk\b`)},
		{name: "wipefs", re: regexp.MustCompile(`(?i)\bwipefs\b`)},
	}

	knownPathPrefixes = []string{
		"./",
		"scripts/",
		"docs/",
		"modules/",
		"tests/",
		".github/",
	}

	numberedWorkspacePrefixRe = regexp.MustCompile(`^[0-9]{3}-[^/]+/`)
)

func main() {
	verbose := flag.Bool("verbose", false, "show detailed per-file and check output")
	flag.Parse()

	repoRoot := detectRepoRoot()
	runbooksDir := filepath.Join(repoRoot, "docs", "runbooks")

	mdFiles, err := collectMarkdownFiles(runbooksDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to enumerate runbooks: %v\n", err)
		os.Exit(1)
	}

	if len(mdFiles) == 0 {
		fmt.Println("Runbook Validator Report")
		fmt.Printf("Repo root: %s\n", repoRoot)
		fmt.Printf("Runbook dir: %s\n", runbooksDir)
		fmt.Println("No markdown files found in docs/runbooks/. Nothing to validate.")
		os.Exit(0)
	}

	reports := make([]fileReport, 0, len(mdFiles))
	sum := summary{filesScanned: len(mdFiles)}

	for _, filePath := range mdFiles {
		relPath, relErr := filepath.Rel(repoRoot, filePath)
		if relErr != nil {
			relPath = filePath
		}

		fileIssues, scanErr := validateFile(filePath, repoRoot)
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
				case "duplicate-step":
					sum.duplicateSteps++
				case "destructive":
					sum.destructiveCommand++
				case "missing-path":
					sum.missingPath++
				case "heading-hierarchy":
					sum.headingHierarchy++
				}
			}
		}

		reports = append(reports, fileReport{path: relPath, issues: fileIssues})
	}

	printReport(repoRoot, runbooksDir, reports, sum, *verbose)

	if sum.filesWithIssues > 0 {
		os.Exit(1)
	}

	os.Exit(0)
}

func detectRepoRoot() string {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	out, err := cmd.Output()
	if err == nil {
		root := strings.TrimSpace(string(out))
		if root != "" {
			return root
		}
	}

	fallback := filepath.Clean(filepath.Join("..", ".."))
	if info, statErr := os.Stat(fallback); statErr == nil && info.IsDir() {
		return fallback
	}

	return "."
}

func collectMarkdownFiles(runbooksDir string) ([]string, error) {
	entries, err := os.ReadDir(runbooksDir)
	if err != nil {
		return nil, err
	}

	files := make([]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if strings.HasSuffix(strings.ToLower(name), ".md") {
			files = append(files, filepath.Join(runbooksDir, name))
		}
	}
	sort.Strings(files)
	return files, nil
}

func validateFile(filePath string, repoRoot string) ([]issue, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	issues := make([]issue, 0)
	scanner := bufio.NewScanner(f)

	lineNo := 0
	prevHeadingLevel := 0

	stepLineByNumber := make(map[string]int)

	inFence := false
	fenceLang := ""

	for scanner.Scan() {
		lineNo++
		line := scanner.Text()

		if !inFence {
			if level := parseHeadingLevel(line); level > 0 {
				if prevHeadingLevel > 0 && level > prevHeadingLevel+1 {
					issues = append(issues, issue{
						typeName: "heading-hierarchy",
						line:     lineNo,
						message:  fmt.Sprintf("heading level jumps from h%d to h%d", prevHeadingLevel, level),
					})
				}
				prevHeadingLevel = level
			}

			if stepNum := parseStepNumber(line); stepNum != "" {
				if firstLine, exists := stepLineByNumber[stepNum]; exists {
					issues = append(issues, issue{
						typeName: "duplicate-step",
						line:     lineNo,
						message:  fmt.Sprintf("duplicate step number %s (first seen at line %d)", stepNum, firstLine),
					})
				} else {
					stepLineByNumber[stepNum] = lineNo
				}
			}

			if lang, ok := parseFenceStart(line); ok {
				inFence = true
				fenceLang = strings.ToLower(strings.TrimSpace(lang))
			}
			continue
		}

		if fenceEndRe.MatchString(line) {
			inFence = false
			fenceLang = ""
			continue
		}

		if !isTrackedFenceLang(fenceLang) {
			continue
		}

		if keyword := detectDestructiveKeyword(line); keyword != "" {
			issues = append(issues, issue{
				typeName: "destructive",
				line:     lineNo,
				message:  fmt.Sprintf("destructive command pattern detected: %s", keyword),
			})
		}

		paths := extractPathCandidates(line)
		for _, p := range paths {
			full := filepath.Join(repoRoot, filepath.FromSlash(p))
			if _, statErr := os.Stat(full); statErr != nil {
				issues = append(issues, issue{
					typeName: "missing-path",
					line:     lineNo,
					message:  fmt.Sprintf("referenced path does not exist: %s", p),
				})
			}
		}
	}

	if scanErr := scanner.Err(); scanErr != nil {
		return issues, scanErr
	}

	return issues, nil
}

func parseHeadingLevel(line string) int {
	m := headingRe.FindStringSubmatch(line)
	if len(m) < 2 {
		return 0
	}
	return len(m[1])
}

func parseStepNumber(line string) string {
	m := stepHeadingRe.FindStringSubmatch(line)
	if len(m) >= 2 {
		return m[1]
	}
	m = numberedRe.FindStringSubmatch(line)
	if len(m) >= 2 {
		return m[1]
	}
	return ""
}

func parseFenceStart(line string) (string, bool) {
	m := fenceStartRe.FindStringSubmatch(line)
	if len(m) < 2 {
		return "", false
	}
	if fenceEndRe.MatchString(line) {
		return "", true
	}
	return m[1], true
}

func isTrackedFenceLang(lang string) bool {
	if lang == "" {
		return true
	}
	return lang == "bash" || lang == "shell" || lang == "sh"
}

func detectDestructiveKeyword(line string) string {
	for _, item := range destructivePatterns {
		if item.re.MatchString(line) {
			return item.name
		}
	}
	return ""
}

func extractPathCandidates(line string) []string {
	if strings.TrimSpace(line) == "" {
		return nil
	}

	rawTokens := tokenRe.FindAllString(line, -1)
	if len(rawTokens) == 0 {
		return nil
	}

	seen := map[string]bool{}
	candidates := make([]string, 0)

	for _, tok := range rawTokens {
		clean := strings.TrimSpace(tok)
		clean = strings.Trim(clean, "`\"'")
		clean = strings.TrimRight(clean, ",.:")
		if clean == "" {
			continue
		}

		if !looksLikeRepoPath(clean) {
			continue
		}

		if seen[clean] {
			continue
		}
		seen[clean] = true
		candidates = append(candidates, clean)
	}

	return candidates
}

func looksLikeRepoPath(token string) bool {
	if strings.HasPrefix(token, "http://") || strings.HasPrefix(token, "https://") {
		return false
	}
	if strings.HasPrefix(token, "-") {
		return false
	}

	for _, prefix := range knownPathPrefixes {
		if strings.HasPrefix(token, prefix) {
			return true
		}
	}

	if numberedWorkspacePrefixRe.MatchString(token) {
		return true
	}

	return false
}

func printReport(repoRoot string, runbooksDir string, reports []fileReport, sum summary, verbose bool) {
	fmt.Println("Runbook Validator Report")
	fmt.Printf("Repo root: %s\n", repoRoot)
	fmt.Printf("Runbook dir: %s\n", runbooksDir)
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
	fmt.Printf("  duplicate-step: %d\n", sum.duplicateSteps)
	fmt.Printf("  destructive: %d\n", sum.destructiveCommand)
	fmt.Printf("  missing-path: %d\n", sum.missingPath)
	fmt.Printf("  heading-hierarchy: %d\n", sum.headingHierarchy)
}
