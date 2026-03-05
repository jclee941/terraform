package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"time"
)

// ANSI colors
const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[0;33m"
	blue   = "\033[0;34m"
	cyan   = "\033[0;36m"
	bold   = "\033[1m"
	nc     = "\033[0m"
)

var (
	envKeyRe = regexp.MustCompile(`^[A-Za-z_]`)
	tfvarsRe = regexp.MustCompile(`^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)`)
)

// envSource pairs a display label with a file path.
type envSource struct {
	label string
	path  string
}

func main() {
	// ── Resolve paths relative to script location ────────────────────────
	_, sourceFile, _, ok := runtime.Caller(0)
	if !ok {
		fmt.Fprintln(os.Stderr, "Failed to determine script location")
		os.Exit(1)
	}
	sourceFile, _ = filepath.Abs(sourceFile)
	scriptDir := filepath.Dir(sourceFile)
	rootDir := filepath.Clean(filepath.Join(scriptDir, ".."))
	devDir := filepath.Clean(filepath.Join(rootDir, ".."))
	inventory := filepath.Join(rootDir, "inventory", "secrets.yaml")
	defaultOut := filepath.Join(rootDir, "terraform", "secret-values.tfvars")

	// ── Arguments ────────────────────────────────────────────────────────
	dryRun := false
	useVault := false
	format := "tfvars"
	outFile := defaultOut
	showDiff := false

	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--dry-run":
			dryRun = true
		case "--vault":
			useVault = true
		case "--format":
			i++
			if i >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --format")
				os.Exit(1)
			}
			format = args[i]
		case "--out":
			i++
			if i >= len(args) {
				fmt.Fprintln(os.Stderr, "Missing value for --out")
				os.Exit(1)
			}
			outFile = args[i]
		case "--diff":
			showDiff = true
		case "-h", "--help":
			fmt.Printf("Usage: %s [--dry-run] [--vault] [--format tfvars|json] [--out FILE] [--diff]\n", os.Args[0])
			os.Exit(0)
		default:
			fmt.Fprintf(os.Stderr, "Unknown option: %s\n", args[i])
			os.Exit(1)
		}
	}

	// ── Dependency checks ────────────────────────────────────────────────
	if !checkCmd("yq") {
		os.Exit(1)
	}
	if useVault && !checkCmd("vault") {
		os.Exit(1)
	}
	if useVault && !checkCmd("jq") {
		os.Exit(1)
	}

	// ── Validate inventory ───────────────────────────────────────────────
	if _, err := os.Stat(inventory); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "%s✗ Missing: %s%s\n", red, inventory, nc)
		os.Exit(1)
	}

	// ── Build registry set from secrets.yaml ─────────────────────────────
	registry := make(map[string]bool)
	registryVaultPath := make(map[string]string)

	yqOut, err := exec.Command("yq", "-r",
		`.secrets[] | [.name, .targets.vault // "null"] | @tsv`,
		inventory).Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s✗ Failed to parse secrets.yaml: %v%s\n", red, err, nc)
		os.Exit(1)
	}

	sc := bufio.NewScanner(strings.NewReader(string(yqOut)))
	for sc.Scan() {
		line := sc.Text()
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "\t", 2)
		name := parts[0]
		registry[name] = true
		if len(parts) > 1 && parts[1] != "" && parts[1] != "null" {
			registryVaultPath[name] = parts[1]
		}
	}

	registryCount := len(registry)
	fmt.Printf("%sSecret Registry:%s %d secrets loaded from secrets.yaml\n", bold, nc, registryCount)
	fmt.Println()

	// ── Source file map ──────────────────────────────────────────────────
	envFiles := []envSource{
		{"money", filepath.Join(devDir, "money", ".env")},
		{"resume", filepath.Join(devDir, "resume", ".env")},
		{"safework", filepath.Join(devDir, "safework", "workers", ".env")},
		{"slack", filepath.Join(devDir, "slack", ".env")},
		{"slack-bot", filepath.Join(devDir, "slack", "typescript", "slack-bot", ".env")},
		{"proxmox-tf", filepath.Join(devDir, "proxmox", "terraform", "terraform.tfvars")},
		{"blacklist", filepath.Join(devDir, "blacklist", ".env")},
		{"blacklist-agent", filepath.Join(devDir, "blacklist", "agent", ".env")},
		{"elk", filepath.Join(devDir, "proxmox", "105-elk", ".env")},
	}

	collected := make(map[string]string)
	collectedSource := make(map[string]string)

	// ── Phase 1: Scan local files ────────────────────────────────────────
	fmt.Printf("%sPhase 1: Scanning local files%s\n", bold, nc)

	foundFiles := 0
	for _, src := range envFiles {
		if _, err := os.Stat(src.path); os.IsNotExist(err) {
			continue
		}
		foundFiles++
		if strings.HasSuffix(src.path, ".tfvars") {
			parseTfvarsFile(src.path, src.label, collected, collectedSource)
		} else {
			parseEnvFile(src.path, src.label, collected, collectedSource)
		}
	}

	fmt.Printf("  Scanned %s%d%s files, collected %s%d%s unique vars\n",
		cyan, foundFiles, nc, cyan, len(collected), nc)
	fmt.Println()

	// ── Phase 2: Vault collection (optional) ─────────────────────────────
	if useVault {
		fmt.Printf("%sPhase 2: Pulling from Vault%s\n", bold, nc)

		vaultAddr := os.Getenv("VAULT_ADDR")
		if vaultAddr == "" {
			if out, err := exec.Command("yq", "-r", ".vault.address", inventory).Output(); err == nil {
				vaultAddr = strings.TrimSpace(string(out))
			}
		}
		vaultMount := ""
		if out, err := exec.Command("yq", "-r", ".vault.mount", inventory).Output(); err == nil {
			vaultMount = strings.TrimSpace(string(out))
		}
		os.Setenv("VAULT_ADDR", vaultAddr)

		// Check vault auth (suppress stdout+stderr)
		if err := exec.Command("vault", "token", "lookup").Run(); err != nil {
			fmt.Printf("  %s✗ Vault authentication failed%s\n", red, nc)
			fmt.Println("  Set VAULT_TOKEN or run: vault login")
		} else {
			// Get unique vault paths from registry
			vaultPaths := make(map[string]bool)
			for _, vp := range registryVaultPath {
				vaultPaths[vp] = true
			}

			vaultCount := 0
			for vpath := range vaultPaths {
				fullPath := vaultMount + "/" + vpath
				jsonOut, err := exec.Command("vault", "kv", "get", "-format=json", fullPath).Output()
				if err != nil {
					fmt.Printf("  %s⚠%s %s (not found or no access)\n", yellow, nc, vpath)
					continue
				}

				// Parse vault JSON with jq
				jqCmd := exec.Command("jq", "-r",
					`.data.data | to_entries[] | [.key, .value] | @tsv`)
				jqCmd.Stdin = strings.NewReader(string(jsonOut))
				jqOut, err := jqCmd.Output()
				if err != nil {
					fmt.Printf("  %s⚠%s %s (jq parse error)\n", yellow, nc, vpath)
					continue
				}

				kvSc := bufio.NewScanner(strings.NewReader(string(jqOut)))
				for kvSc.Scan() {
					kvLine := kvSc.Text()
					if kvLine == "" {
						continue
					}
					kvParts := strings.SplitN(kvLine, "\t", 2)
					if len(kvParts) != 2 || kvParts[0] == "" {
						continue
					}
					k, v := kvParts[0], kvParts[1]
					// Vault values don't overwrite local values
					if _, exists := collected[k]; !exists {
						collected[k] = v
						collectedSource[k] = "vault:" + vpath
						vaultCount++
					}
				}
				fmt.Printf("  %s✓%s %s\n", green, nc, vpath)
			}
			fmt.Printf("  Collected %s%d%s additional vars from Vault\n", cyan, vaultCount, nc)
		}
		fmt.Println()
	} else {
		fmt.Printf("%sPhase 2: Vault%s (skipped — use --vault to enable)\n", bold, nc)
		fmt.Println()
	}

	// ── Phase 3: Match against registry ──────────────────────────────────
	fmt.Printf("%sPhase 3: Matching against registry%s\n", bold, nc)

	matched := make(map[string]string)
	unmatched := make(map[string]bool)

	for key, val := range collected {
		if registry[key] {
			matched[key] = val
		} else {
			unmatched[key] = true
		}
	}

	// Find missing (in registry but not collected)
	missing := make(map[string]bool)
	for name := range registry {
		if _, exists := matched[name]; !exists {
			missing[name] = true
		}
	}

	fmt.Printf("  %s✓ Matched:%s  %d/%d\n", green, nc, len(matched), registryCount)
	fmt.Printf("  %s✗ Missing:%s  %d/%d\n", red, nc, len(missing), registryCount)
	fmt.Printf("  %s⚠ Unregistered:%s %d (not in secrets.yaml)\n", yellow, nc, len(unmatched))
	fmt.Println()

	// ── Phase 4: Generate output ─────────────────────────────────────────
	if dryRun {
		printDryRun(matched, missing, unmatched, collectedSource, outFile)
	} else if showDiff {
		printDiff(matched, outFile)
	} else {
		writeOutput(matched, format, outFile)
	}

	fmt.Println()
	fmt.Printf("%sSummary:%s %s%d%s collected, %s%d%s missing, %s%d%s unregistered\n",
		bold, nc,
		green, len(matched), nc,
		red, len(missing), nc,
		yellow, len(unmatched), nc)
}

// ── Helpers ──────────────────────────────────────────────────────────────────

func checkCmd(name string) bool {
	if _, err := exec.LookPath(name); err != nil {
		fmt.Fprintf(os.Stderr, "%s✗ Required: %s%s\n", red, name, nc)
		return false
	}
	return true
}

// parseEnvFile reads KEY=VALUE pairs from a .env file.
// Handles quotes, comments, blank lines. First source wins.
func parseEnvFile(file, label string, collected, collectedSource map[string]string) {
	f, err := os.Open(file)
	if err != nil {
		return
	}
	defer f.Close()

	count := 0
	s := bufio.NewScanner(f)
	for s.Scan() {
		line := s.Text()
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		eqIdx := strings.Index(line, "=")
		if eqIdx < 0 {
			continue
		}

		key := strings.TrimSpace(line[:eqIdx])
		value := line[eqIdx+1:]

		// Must start with letter or underscore
		if !envKeyRe.MatchString(key) {
			continue
		}

		value = stripQuotes(value)
		value = strings.TrimSpace(value)

		if value == "" {
			continue
		}

		// First source wins — don't overwrite
		if _, exists := collected[key]; !exists {
			collected[key] = value
			collectedSource[key] = label
			count++
		}
	}

	fmt.Printf("  %s✓%s %s: %d vars\n", green, nc, label, count)
}

// parseTfvarsFile reads HCL key = "value" pairs from a .tfvars file.
func parseTfvarsFile(file, label string, collected, collectedSource map[string]string) {
	f, err := os.Open(file)
	if err != nil {
		return
	}
	defer f.Close()

	count := 0
	s := bufio.NewScanner(f)
	for s.Scan() {
		line := s.Text()
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		m := tfvarsRe.FindStringSubmatch(line)
		if m == nil {
			continue
		}

		key := m[1]
		value := stripQuotes(m[2])
		value = strings.TrimSpace(value)

		if value == "" {
			continue
		}

		if _, exists := collected[key]; !exists {
			collected[key] = value
			collectedSource[key] = label
			count++
		}
	}

	fmt.Printf("  %s✓%s %s: %d vars\n", green, nc, label, count)
}

// stripQuotes removes one layer of surrounding quotes (" then ').
func stripQuotes(s string) string {
	if len(s) > 0 && s[0] == '"' {
		s = s[1:]
	}
	if len(s) > 0 && s[len(s)-1] == '"' {
		s = s[:len(s)-1]
	}
	if len(s) > 0 && s[0] == '\'' {
		s = s[1:]
	}
	if len(s) > 0 && s[len(s)-1] == '\'' {
		s = s[:len(s)-1]
	}
	return s
}

func maskValue(v string) string {
	n := len(v)
	if n <= 4 {
		return "****"
	}
	if n <= 8 {
		return v[:2] + "****"
	}
	return v[:4] + "…" + v[n-2:]
}

func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func sortedBoolKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func escapeHCL(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	return s
}

// ── Output generators ────────────────────────────────────────────────────────

func generateTfvars(matched map[string]string) string {
	var sb strings.Builder
	sb.WriteString("# Auto-generated by collect.go\n")
	fmt.Fprintf(&sb, "# %s\n", time.Now().Format(time.RFC3339))
	sb.WriteString("# DO NOT COMMIT — contains secret values\n")
	sb.WriteString("\n")
	sb.WriteString("secret_values = {\n")

	for _, key := range sortedKeys(matched) {
		fmt.Fprintf(&sb, "  %s = \"%s\"\n", key, escapeHCL(matched[key]))
	}

	sb.WriteString("}\n")
	return sb.String()
}

func generateJSON(matched map[string]string) string {
	var sb strings.Builder
	sb.WriteString("{\n")

	keys := sortedKeys(matched)
	for i, key := range keys {
		val := escapeHCL(matched[key])
		if i > 0 {
			sb.WriteString(",\n")
		}
		fmt.Fprintf(&sb, "  \"%s\": \"%s\"", key, val)
	}

	sb.WriteString("\n}\n")
	return sb.String()
}

// ── Phase 4 variants ─────────────────────────────────────────────────────────

func printDryRun(matched map[string]string, missing, unmatched map[string]bool, collectedSource map[string]string, outFile string) {
	fmt.Printf("%sPhase 4: Preview (dry-run)%s\n", bold, nc)
	fmt.Println()

	fmt.Printf("%sMatched secrets:%s\n", cyan, nc)
	for _, key := range sortedKeys(matched) {
		src := collectedSource[key]
		if src == "" {
			src = "unknown"
		}
		fmt.Printf("  %s✓%s %s = %s %s← %s%s\n",
			green, nc, key, maskValue(matched[key]), blue, src, nc)
	}

	if len(missing) > 0 {
		fmt.Println()
		fmt.Printf("%sMissing secrets (not found locally):%s\n", cyan, nc)
		for _, key := range sortedBoolKeys(missing) {
			fmt.Printf("  %s✗%s %s\n", red, nc, key)
		}
	}

	if len(unmatched) > 0 {
		fmt.Println()
		fmt.Printf("%sUnregistered vars (consider adding to secrets.yaml):%s\n", cyan, nc)
		unmatchedKeys := sortedBoolKeys(unmatched)
		limit := len(unmatchedKeys)
		if limit > 20 {
			limit = 20
		}
		for _, key := range unmatchedKeys[:limit] {
			src := collectedSource[key]
			if src == "" {
				src = "unknown"
			}
			fmt.Printf("  %s⚠%s %s %s← %s%s\n", yellow, nc, key, blue, src, nc)
		}
		if len(unmatchedKeys) > 20 {
			fmt.Printf("  … and %d more\n", len(unmatchedKeys)-20)
		}
	}

	fmt.Println()
	fmt.Printf("%sWould write %d secrets to:%s %s\n", bold, len(matched), nc, outFile)
}

func printDiff(matched map[string]string, outFile string) {
	fmt.Printf("%sPhase 4: Diff%s\n", bold, nc)

	if _, err := os.Stat(outFile); err == nil {
		// Write generated content to temp file for diff
		tmp, err := os.CreateTemp("", "collect-diff-*.tfvars")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to create temp file: %v\n", err)
			os.Exit(1)
		}
		tmpPath := tmp.Name()
		defer os.Remove(tmpPath)

		tmp.WriteString(generateTfvars(matched))
		tmp.Close()

		diffCmd := exec.Command("diff", outFile, tmpPath)
		diffCmd.Stdout = os.Stdout
		diffCmd.Stderr = os.Stderr
		diffCmd.Run() // diff returns 1 if files differ — that is OK
	} else {
		fmt.Printf("  %sNo existing file to diff against%s\n", yellow, nc)
		fmt.Print(generateTfvars(matched))
	}
}

func writeOutput(matched map[string]string, format, outFile string) {
	fmt.Printf("%sPhase 4: Writing output%s\n", bold, nc)

	var content string
	switch format {
	case "tfvars":
		content = generateTfvars(matched)
	case "json":
		content = generateJSON(matched)
	default:
		fmt.Fprintf(os.Stderr, "%sUnknown format: %s%s\n", red, format, nc)
		os.Exit(1)
	}

	if err := os.WriteFile(outFile, []byte(content), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "%s✗ Failed to write: %v%s\n", red, err, nc)
		os.Exit(1)
	}

	fmt.Printf("  %s✓%s Written %d secrets to %s%s%s\n",
		green, nc, len(matched), bold, outFile, nc)
	fmt.Printf("  %s⚠ DO NOT COMMIT this file%s\n", yellow, nc)
}
