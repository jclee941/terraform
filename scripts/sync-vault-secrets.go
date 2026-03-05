package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const repo = "qws941/terraform"

// ANSI colors
const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	blue   = "\033[0;34m"
	cyan   = "\033[0;36m"
	bold   = "\033[1m"
	nc     = "\033[0m"
)

type opSecret struct {
	name     string
	opRef    string
	priority string
	desc     string
}

type derivedSecret struct {
	name     string
	value    string
	priority string
	desc     string
}

type manualSecret struct {
	name     string
	priority string
	source   string
}

var opSecrets = []opSecret{
	{"TF_VAR_GRAFANA_AUTH", "op://homelab/grafana/secrets/service_account_token", "P1", "Grafana service account token"},
	{"TF_VAR_GITHUB_TOKEN", "op://homelab/github/secrets/personal_access_token", "P1", "GitHub PAT for TF provider"},
	{"TF_VAR_SUPABASE_URL", "op://homelab/supabase/secrets/url", "P1", "Supabase project URL"},
	{"GH_PAT", "op://homelab/github/secrets/personal_access_token", "P2", "GitHub PAT for workflow automation"},
}

var derivedSecrets = []derivedSecret{
	{"TF_VAR_N8N_WEBHOOK_URL", "http://192.168.50.112:5678/webhook", "P1", "n8n webhook base URL"},
}

var manualSecretsList = []manualSecret{
	{"TF_API_TOKEN", "P0", "Terraform Cloud (skip if not using TFC)"},
	{"CF_ACCESS_CLIENT_ID", "P2", "CF Zero Trust → Service Tokens"},
	{"CF_ACCESS_CLIENT_SECRET", "P2", "CF Zero Trust → Service Tokens"},
}

func usage() {
	fmt.Fprintf(os.Stdout, `Usage: sync-vault-secrets [OPTIONS]

Sync secrets from 1Password to GitHub Actions for %s.

Options:
  --audit        Check which secrets need sync (no changes)
  --dry-run      Show what would be set without applying
  --force        Overwrite existing secrets (for rotation)
  -h, --help     Show this help

Environment:
  OP_SERVICE_ACCOUNT_TOKEN  1Password service account token (required)

1Password Paths:
  op://homelab/cloudflare/secrets  → Account ID
  op://homelab/grafana/secrets     → Service account token
  op://homelab/github/secrets      → Personal access token
  op://homelab/n8n/secrets         → Webhook config
  op://homelab/supabase/secrets    → URL and service key
`, repo)
}

func maskValue(v string) string {
	l := len(v)
	if l <= 4 {
		return "****"
	}
	if l <= 8 {
		return v[:2] + "****"
	}
	return v[:4] + "..." + v[l-2:]
}

func commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func runSilent(name string, args ...string) bool {
	cmd := exec.Command(name, args...)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func fetchExistingSecrets() []string {
	cmd := exec.Command("gh", "secret", "list", "-R", repo)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return nil
	}
	var secrets []string
	for _, line := range strings.Split(out.String(), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) > 0 {
			secrets = append(secrets, fields[0])
		}
	}
	return secrets
}

func isConfigured(name string, existing []string) bool {
	for _, s := range existing {
		if s == name {
			return true
		}
	}
	return false
}

func opRead(ref string) (string, bool) {
	cmd := exec.Command("op", "read", ref)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return "", false
	}
	return strings.TrimRight(out.String(), "\n"), true
}

func ghSecretSet(name, value string) bool {
	cmd := exec.Command("gh", "secret", "set", name, "-R", repo)
	cmd.Stdin = strings.NewReader(value)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func isPlaceholder(v string) bool {
	lower := strings.ToLower(v)
	return strings.HasPrefix(lower, "placeholder")
}

func main() {
	var dryRun, auditOnly, force, help bool

	flag.BoolVar(&dryRun, "dry-run", false, "Show what would be set without applying")
	flag.BoolVar(&auditOnly, "audit", false, "Check which secrets need sync (no changes)")
	flag.BoolVar(&force, "force", false, "Overwrite existing secrets (for rotation)")
	flag.BoolVar(&help, "help", false, "Show this help")
	flag.BoolVar(&help, "h", false, "Show this help")

	flag.Usage = usage
	flag.Parse()

	if help {
		usage()
		os.Exit(0)
	}

	if flag.NArg() > 0 {
		fmt.Fprintf(os.Stderr, "%sUnknown: %s%s\n", red, flag.Arg(0), nc)
		usage()
		os.Exit(1)
	}

	// --- Dependency checks ---

	if !commandExists("op") {
		fmt.Fprintf(os.Stderr, "%sop CLI required. Install: https://developer.1password.com/docs/cli/get-started/%s\n", red, nc)
		os.Exit(1)
	}

	if !commandExists("gh") {
		fmt.Fprintf(os.Stderr, "%sgh CLI required. Install: https://cli.github.com/%s\n", red, nc)
		os.Exit(1)
	}

	if !runSilent("gh", "auth", "status") {
		fmt.Fprintf(os.Stderr, "%sgh auth required — run: gh auth login%s\n", red, nc)
		os.Exit(1)
	}

	// --- Verify 1Password connectivity ---

	if os.Getenv("OP_SERVICE_ACCOUNT_TOKEN") == "" {
		fmt.Fprintf(os.Stderr, "%sOP_SERVICE_ACCOUNT_TOKEN not set%s\n", red, nc)
		fmt.Fprintf(os.Stderr, "Set via: export OP_SERVICE_ACCOUNT_TOKEN='ops_xxx'\n")
		os.Exit(1)
	}

	if !runSilent("op", "whoami") {
		fmt.Fprintf(os.Stderr, "%s1Password authentication failed%s\n", red, nc)
		fmt.Fprintf(os.Stderr, "Check OP_SERVICE_ACCOUNT_TOKEN\n")
		os.Exit(1)
	}

	// --- Fetch existing secrets ---

	existing := fetchExistingSecrets()

	// --- Main sync logic ---

	fmt.Printf("%s1Password → GitHub Secret Sync%s\n", bold, nc)
	fmt.Printf("Repo:   %s\n\n", repo)

	synced := 0
	skipped := 0
	failed := 0
	total := 0

	// Process 1Password-sourced secrets
	for _, s := range opSecrets {
		total++

		// Check if already configured (skip unless --force)
		if isConfigured(s.name, existing) && !force {
			fmt.Printf("%s  [OK]%s %-35s %s  (already set)\n", green, nc, s.name, s.priority)
			skipped++
			continue
		}

		// Fetch from 1Password
		value, ok := opRead(s.opRef)

		if !ok || value == "" {
			fmt.Printf("%s  [!!]%s %-35s %s  1Password ref missing: %s\n", red, nc, s.name, s.priority, s.opRef)
			failed++
			continue
		}

		if isPlaceholder(value) {
			fmt.Printf("%s  [PH]%s %-35s %s  placeholder value — skipped\n", yellow, nc, s.name, s.priority)
			skipped++
			continue
		}

		if auditOnly {
			if isConfigured(s.name, existing) {
				fmt.Printf("%s  [~~]%s %-35s %s  would rotate: %s\n", yellow, nc, s.name, s.priority, maskValue(value))
			} else {
				fmt.Printf("%s  [--]%s %-35s %s  available: %s\n", yellow, nc, s.name, s.priority, maskValue(value))
			}
			continue
		}

		if dryRun {
			action := "set"
			if isConfigured(s.name, existing) {
				action = "rotate"
			}
			fmt.Printf("%s  [DRY]%s %-35s %s  would %s: %s\n", blue, nc, s.name, s.priority, action, maskValue(value))
			continue
		}

		// Set the secret
		if ghSecretSet(s.name, value) {
			action := "SET"
			if isConfigured(s.name, existing) && force {
				action = "ROTATED"
			}
			fmt.Printf("%s  [%s]%s %-35s %s\n", green, action, nc, s.name, s.priority)
			synced++
		} else {
			fmt.Printf("%s  [ERR]%s %-35s %s  gh secret set failed\n", red, nc, s.name, s.priority)
			failed++
		}
	}

	// Process derived secrets (known infrastructure values)
	for _, s := range derivedSecrets {
		total++

		if isConfigured(s.name, existing) && !force {
			fmt.Printf("%s  [OK]%s %-35s %s  (already set)\n", green, nc, s.name, s.priority)
			skipped++
			continue
		}

		if auditOnly {
			if isConfigured(s.name, existing) {
				fmt.Printf("%s  [~~]%s %-35s %s  derived: %s\n", yellow, nc, s.name, s.priority, maskValue(s.value))
			} else {
				fmt.Printf("%s  [--]%s %-35s %s  derived: %s\n", yellow, nc, s.name, s.priority, maskValue(s.value))
			}
			continue
		}

		if dryRun {
			fmt.Printf("%s  [DRY]%s %-35s %s  derived: %s\n", blue, nc, s.name, s.priority, maskValue(s.value))
			continue
		}

		if ghSecretSet(s.name, s.value) {
			fmt.Printf("%s  [SET]%s %-35s %s\n", green, nc, s.name, s.priority)
			synced++
		} else {
			fmt.Printf("%s  [ERR]%s %-35s %s  gh secret set failed\n", red, nc, s.name, s.priority)
			failed++
		}
	}

	// --- Summary ---

	fmt.Printf("\n%sSummary:%s %d total", bold, nc, total)
	if auditOnly {
		fmt.Printf(" (audit mode)\n")
	} else if dryRun {
		fmt.Printf(" (dry-run)\n")
	} else {
		fmt.Printf(", %s%d synced%s, %d skipped, %s%d failed%s\n", green, synced, nc, skipped, red, failed, nc)
	}

	// --- Report remaining manual secrets ---

	manualCount := 0
	for _, s := range manualSecretsList {
		if !isConfigured(s.name, existing) {
			if manualCount == 0 {
				fmt.Printf("\n%sManual secrets (not in 1Password):%s\n", bold, nc)
			}
			fmt.Printf("  %s%-35s%s %s  %s\n", yellow, s.name, nc, s.priority, s.source)
			manualCount++
		}
	}

	if manualCount > 0 {
		fmt.Printf("\nSet manually: %sgh secret set NAME -R %s%s\n", cyan, repo, nc)
	}

	if failed > 0 {
		os.Exit(1)
	}
}
