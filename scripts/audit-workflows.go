package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
)

const (
	categoryReusable   = "reusable"
	categoryCaller     = "caller"
	categoryStandalone = "standalone"
)

type registryEntry struct {
	File    string
	Section string
	Line    int
}

type mismatch struct {
	Registry string
	Actual   string
	Stem     string
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(2)
	}
}

func run() error {
	fs := flag.NewFlagSet("audit-workflows.go", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	verbose := fs.Bool("verbose", false, "Show detailed category and inventory output")
	if err := fs.Parse(os.Args[1:]); err != nil {
		return err
	}

	repoRoot, err := repoRootFromScript()
	if err != nil {
		return fmt.Errorf("resolve repository root: %w", err)
	}

	registryPath := filepath.Join(repoRoot, ".github", "workflow-registry.yml")
	workflowsDir := filepath.Join(repoRoot, ".github", "workflows")

	registryEntries, err := parseRegistry(registryPath)
	if err != nil {
		return err
	}

	actualFiles, err := listWorkflowFiles(workflowsDir)
	if err != nil {
		return err
	}

	registrySet := make(map[string]registryEntry, len(registryEntries))
	for _, entry := range registryEntries {
		registrySet[entry.File] = entry
	}

	actualSet := make(map[string]struct{}, len(actualFiles))
	for _, file := range actualFiles {
		actualSet[file] = struct{}{}
	}

	undocumented := make([]string, 0)
	for _, file := range actualFiles {
		if _, ok := registrySet[file]; !ok {
			undocumented = append(undocumented, file)
		}
	}

	stale := make([]string, 0)
	for _, entry := range registryEntries {
		if _, ok := actualSet[entry.File]; !ok {
			stale = append(stale, entry.File)
		}
	}

	mismatches := detectMismatches(stale, undocumented)

	actualCategories := categorizeActualFiles(workflowsDir, actualFiles)
	registryCategories := categorizeRegistryEntries(registryEntries)

	driftFound := len(undocumented) > 0 || len(stale) > 0 || len(mismatches) > 0

	printReport(reportInput{
		RepoRoot:            repoRoot,
		RegistryPath:        registryPath,
		WorkflowsDir:        workflowsDir,
		RegistryEntries:     registryEntries,
		ActualFiles:         actualFiles,
		Undocumented:        undocumented,
		Stale:               stale,
		Mismatches:          mismatches,
		ActualCategories:    actualCategories,
		RegistryCategories:  registryCategories,
		Verbose:             *verbose,
		RegistryParseIssues: findRegistryDuplicates(registryEntries),
	})

	if driftFound {
		os.Exit(1)
	}

	return nil
}

func repoRootFromScript() (string, error) {
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		return "", errors.New("runtime.Caller failed")
	}
	return filepath.Clean(filepath.Join(filepath.Dir(file), "..")), nil
}

func parseRegistry(registryPath string) ([]registryEntry, error) {
	f, err := os.Open(registryPath)
	if err != nil {
		return nil, fmt.Errorf("open registry %q: %w", registryPath, err)
	}
	defer f.Close()

	lineRe := regexp.MustCompile(`^\s*-\s*file:\s*([^\s#]+)`) // extracted manually from YAML lines

	entries := make([]registryEntry, 0, 128)
	s := bufio.NewScanner(f)
	lineNo := 0
	section := ""

	for s.Scan() {
		lineNo++
		line := strings.TrimSpace(s.Text())

		switch line {
		case "templates:":
			section = "templates"
			continue
		case "direct:":
			section = "direct"
			continue
		}

		m := lineRe.FindStringSubmatch(s.Text())
		if len(m) != 2 {
			continue
		}

		file := strings.TrimSpace(m[1])
		file = strings.Trim(file, `"'`)
		if file == "" {
			continue
		}

		entries = append(entries, registryEntry{File: file, Section: section, Line: lineNo})
	}

	if err := s.Err(); err != nil {
		return nil, fmt.Errorf("scan registry %q: %w", registryPath, err)
	}

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].File < entries[j].File
	})

	return entries, nil
}

func listWorkflowFiles(workflowsDir string) ([]string, error) {
	files := make([]string, 0, 128)

	err := filepath.WalkDir(workflowsDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		ext := strings.ToLower(filepath.Ext(d.Name()))
		if ext != ".yml" && ext != ".yaml" {
			return nil
		}

		files = append(files, d.Name())
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("walk workflows directory %q: %w", workflowsDir, err)
	}

	sort.Strings(files)
	return files, nil
}

func categorizeActualFiles(workflowsDir string, files []string) map[string][]string {
	out := map[string][]string{
		categoryReusable:   {},
		categoryCaller:     {},
		categoryStandalone: {},
	}

	for _, file := range files {
		switch {
		case strings.HasPrefix(file, "_"):
			out[categoryReusable] = append(out[categoryReusable], file)
		case isCallerWorkflow(filepath.Join(workflowsDir, file)):
			out[categoryCaller] = append(out[categoryCaller], file)
		default:
			out[categoryStandalone] = append(out[categoryStandalone], file)
		}
	}

	return out
}

func categorizeRegistryEntries(entries []registryEntry) map[string][]string {
	out := map[string][]string{
		categoryReusable:   {},
		categoryCaller:     {},
		categoryStandalone: {},
	}

	for _, entry := range entries {
		if strings.HasPrefix(entry.File, "_") || entry.Section == "templates" {
			out[categoryReusable] = append(out[categoryReusable], entry.File)
			continue
		}

		if entry.Section == "direct" {
			out[categoryStandalone] = append(out[categoryStandalone], entry.File)
			continue
		}

		out[categoryCaller] = append(out[categoryCaller], entry.File)
	}

	return out
}

func isCallerWorkflow(path string) bool {
	content, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	text := string(content)

	if strings.Contains(text, "uses: ./.github/workflows/_") {
		return true
	}
	if strings.Contains(text, "uses: qws941/.github/.github/workflows/_") {
		return true
	}

	return false
}

func detectMismatches(stale, undocumented []string) []mismatch {
	staleByStem := make(map[string][]string)
	for _, file := range stale {
		stem := strings.ToLower(strings.TrimSuffix(file, filepath.Ext(file)))
		staleByStem[stem] = append(staleByStem[stem], file)
	}

	mismatches := make([]mismatch, 0)
	usedStale := make(map[string]bool)

	for _, file := range undocumented {
		stem := strings.ToLower(strings.TrimSuffix(file, filepath.Ext(file)))
		candidates := staleByStem[stem]
		if len(candidates) == 0 {
			continue
		}

		sort.Strings(candidates)
		for _, candidate := range candidates {
			if usedStale[candidate] {
				continue
			}
			usedStale[candidate] = true
			mismatches = append(mismatches, mismatch{Registry: candidate, Actual: file, Stem: stem})
			break
		}
	}

	sort.Slice(mismatches, func(i, j int) bool {
		if mismatches[i].Registry == mismatches[j].Registry {
			return mismatches[i].Actual < mismatches[j].Actual
		}
		return mismatches[i].Registry < mismatches[j].Registry
	})

	return mismatches
}

func findRegistryDuplicates(entries []registryEntry) []string {
	seen := make(map[string]int)
	dups := make([]string, 0)

	for _, entry := range entries {
		seen[entry.File]++
	}
	for file, count := range seen {
		if count > 1 {
			dups = append(dups, fmt.Sprintf("%s (x%d)", file, count))
		}
	}
	sort.Strings(dups)
	return dups
}

type reportInput struct {
	RepoRoot            string
	RegistryPath        string
	WorkflowsDir        string
	RegistryEntries     []registryEntry
	ActualFiles         []string
	Undocumented        []string
	Stale               []string
	Mismatches          []mismatch
	ActualCategories    map[string][]string
	RegistryCategories  map[string][]string
	Verbose             bool
	RegistryParseIssues []string
}

func printReport(in reportInput) {
	fmt.Println("Workflow Registry Audit Report")
	fmt.Println("==============================")
	fmt.Printf("Repository: %s\n", in.RepoRoot)
	fmt.Printf("Registry:   %s\n", in.RegistryPath)
	fmt.Printf("Workflows:  %s\n", in.WorkflowsDir)
	fmt.Println()

	fmt.Println("Summary")
	fmt.Println("-------")
	fmt.Printf("Registry entries:                 %d\n", len(in.RegistryEntries))
	fmt.Printf("Workflow files on disk:           %d\n", len(in.ActualFiles))
	fmt.Printf("Undocumented workflow files:      %d\n", len(in.Undocumented))
	fmt.Printf("Stale registry entries:           %d\n", len(in.Stale))
	fmt.Printf("Filename mismatches (stem match): %d\n", len(in.Mismatches))
	fmt.Println()

	printCategorySummary("Actual workflow categories", in.ActualCategories)
	printCategorySummary("Registry entry categories", in.RegistryCategories)

	printStringList("Undocumented workflow files (present in .github/workflows but missing in registry)", in.Undocumented)
	printStringList("Stale registry entries (present in registry but missing on disk)", in.Stale)

	if len(in.Mismatches) == 0 {
		fmt.Println("Filename mismatches (registry vs actual)")
		fmt.Println("----------------------------------------")
		fmt.Println("- none")
		fmt.Println()
	} else {
		fmt.Println("Filename mismatches (registry vs actual)")
		fmt.Println("----------------------------------------")
		for _, m := range in.Mismatches {
			fmt.Printf("- registry: %-35s actual: %-35s stem: %s\n", m.Registry, m.Actual, m.Stem)
		}
		fmt.Println()
	}

	if in.Verbose {
		printVerbose(in)
	}

	inSync := len(in.Undocumented) == 0 && len(in.Stale) == 0 && len(in.Mismatches) == 0
	if inSync {
		fmt.Println("Result: synchronized (exit code 0)")
		return
	}
	fmt.Println("Result: drift detected (exit code 1)")
}

func printCategorySummary(title string, categories map[string][]string) {
	fmt.Println(title)
	fmt.Println(strings.Repeat("-", len(title)))
	fmt.Printf("- reusable:   %d\n", len(categories[categoryReusable]))
	fmt.Printf("- callers:    %d\n", len(categories[categoryCaller]))
	fmt.Printf("- standalone: %d\n", len(categories[categoryStandalone]))
	fmt.Println()
}

func printStringList(title string, values []string) {
	fmt.Println(title)
	fmt.Println(strings.Repeat("-", len(title)))
	if len(values) == 0 {
		fmt.Println("- none")
		fmt.Println()
		return
	}
	for _, v := range values {
		fmt.Printf("- %s\n", v)
	}
	fmt.Println()
}

func printVerbose(in reportInput) {
	fmt.Println("Verbose Details")
	fmt.Println("---------------")

	printStringList("All workflow files on disk", in.ActualFiles)

	registryFiles := make([]string, 0, len(in.RegistryEntries))
	for _, entry := range in.RegistryEntries {
		registryFiles = append(registryFiles, entry.File)
	}
	printStringList("All registry file entries", registryFiles)

	if len(in.RegistryParseIssues) > 0 {
		printStringList("Registry duplicate entries", in.RegistryParseIssues)
	}
	if len(in.RegistryParseIssues) == 0 {
		fmt.Println("Registry duplicate entries")
		fmt.Println("--------------------------")
		fmt.Println("- none")
		fmt.Println()
	}

	printStringList("Actual reusable workflows", in.ActualCategories[categoryReusable])
	printStringList("Actual caller workflows", in.ActualCategories[categoryCaller])
	printStringList("Actual standalone workflows", in.ActualCategories[categoryStandalone])
}
