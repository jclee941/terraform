package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const repo = "qws941/terraform"

const (
	colorRed    = "\033[0;31m"
	colorGreen  = "\033[0;32m"
	colorYellow = "\033[1;33m"
	colorBlue   = "\033[0;34m"
	colorCyan   = "\033[0;36m"
	colorBold   = "\033[1m"
	colorNC     = "\033[0m"
)

type secretEntry struct {
	name     string
	priority string
	source   string
}

func printUsage() {
	fmt.Printf("Usage: %s [OPTIONS]\n\n", filepath.Base(os.Args[0]))
	fmt.Printf("Register GitHub Actions secrets for %s from local .tfvars files.\n\n", repo)
	fmt.Println("Options:")
	fmt.Println("  --dry-run          Show what would be set without applying")
	fmt.Println("  --audit            Only check which secrets are missing (no prompts)")
	fmt.Println("  --priority P       Filter by priority: P0, P1, P2")
	fmt.Println("  -h, --help         Show this help")
}

func main() {
	dryRun := false
	auditOnly := false
	priorityFilter := ""

	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--dry-run":
			dryRun = true
		case "--audit":
			auditOnly = true
		case "--priority":
			if i+1 >= len(args) {
				fmt.Fprintf(os.Stderr, "%sUnknown: %s%s\n", colorRed, args[i], colorNC)
				printUsage()
				os.Exit(1)
			}
			i++
			priorityFilter = args[i]
		case "-h", "--help":
			printUsage()
			os.Exit(0)
		default:
			fmt.Fprintf(os.Stderr, "%sUnknown: %s%s\n", colorRed, args[i], colorNC)
			printUsage()
			os.Exit(1)
		}
	}

	if _, err := exec.LookPath("gh"); err != nil {
		fmt.Fprintf(os.Stderr, "%sgh CLI required%s\n", colorRed, colorNC)
		os.Exit(1)
	}

	if _, err := exec.Command("gh", "auth", "status").CombinedOutput(); err != nil {
		fmt.Fprintf(os.Stderr, "%sgh auth required — run: gh auth login%s\n", colorRed, colorNC)
		os.Exit(1)
	}

	rootDir := resolveRootDir()

	localValues := make(map[string]string)
	parseTfvars(filepath.Join(rootDir, "100-pve", "terraform.tfvars"), localValues)
	parseTfvars(filepath.Join(rootDir, "300-cloudflare", "terraform.tfvars"), localValues)

	secrets := []secretEntry{
		{"TF_API_TOKEN", "P0", "env:TF_API_TOKEN"},
		{"TF_VAR_PROXMOX_ENDPOINT", "P0", "tfvars:100-pve:proxmox_endpoint"},
		{"TF_VAR_PROXMOX_API_TOKEN", "P0", "tfvars:100-pve:proxmox_api_token"},
		{"TF_VAR_PROXMOX_INSECURE", "P0", "tfvars:100-pve:proxmox_insecure"},

		{"TF_VAR_GRAFANA_AUTH", "P1", "op:op://homelab/grafana/secrets/service_account_token"},
		{"TF_VAR_N8N_WEBHOOK_URL", "P1", "derived:http://192.168.50.112:5678/webhook"},
		{"TF_VAR_SUPABASE_URL", "P1", "op:op://homelab/supabase/secrets/url"},
		{"TF_VAR_CLOUDFLARE_ACCOUNT_ID", "P1", "tfvars:300-cloudflare:cloudflare_account_id"},
		{"TF_VAR_CLOUDFLARE_ZONE_ID", "P1", "tfvars:300-cloudflare:cloudflare_zone_id"},
		{"TF_VAR_SYNOLOGY_DOMAIN", "P1", "tfvars:300-cloudflare:synology_domain"},
		{"TF_VAR_ACCESS_ALLOWED_EMAILS", "P1", "tfvars:300-cloudflare:access_allowed_emails"},

		{"CLOUDFLARE_API_TOKEN", "P2", "env:CLOUDFLARE_API_TOKEN"},
		{"GH_PAT", "P2", "op:op://homelab/github/secrets/personal_access_token"},
		{"CF_ACCESS_CLIENT_ID", "P2", "env:CF_ACCESS_CLIENT_ID"},
		{"CF_ACCESS_CLIENT_SECRET", "P2", "env:CF_ACCESS_CLIENT_SECRET"},
	}

	byName := make(map[string]secretEntry, len(secrets))
	sortedNames := make([]string, 0, len(secrets))
	for _, s := range secrets {
		byName[s.name] = s
		sortedNames = append(sortedNames, s.name)
	}
	sort.Strings(sortedNames)

	existing := fetchExistingSecrets()

	fmt.Printf("%sGitHub Actions Secret Manager — %s%s\n\n", colorBold, repo, colorNC)

	total, configured, resolvable, missing := 0, 0, 0, 0

	for _, name := range sortedNames {
		s := byName[name]
		if priorityFilter != "" && s.priority != priorityFilter {
			continue
		}
		total++

		if existing[name] {
			configured++
			fmt.Printf("%s  [OK]%s %-35s %s\n", colorGreen, colorNC, name, s.priority)
			continue
		}

		value := resolveValue(s, localValues)
		if value == "" {
			value = tryResolveFromTfvars(name, localValues)
		}

		if value != "" {
			resolvable++
			fmt.Printf("%s  [--]%s %-35s %s  %svalue: %s%s\n", colorYellow, colorNC, name, s.priority, colorCyan, maskValue(value), colorNC)
		} else {
			missing++
			fmt.Printf("%s  [!!]%s %-35s %s  %ssource: %s%s\n", colorRed, colorNC, name, s.priority, colorRed, s.source, colorNC)
		}
	}

	fmt.Printf("\n%sSummary:%s %d total, %s%d configured%s, %s%d resolvable%s, %s%d manual%s\n\n",
		colorBold, colorNC, total, colorGreen, configured, colorNC, colorYellow, resolvable, colorNC, colorRed, missing, colorNC)

	if auditOnly {
		if missing+resolvable > 0 {
			os.Exit(1)
		}
		os.Exit(0)
	}

	if resolvable == 0 && missing == 0 {
		fmt.Printf("%sAll secrets configured.%s\n", colorGreen, colorNC)
		os.Exit(0)
	}

	if resolvable > 0 {
		fmt.Printf("%sSet %d resolvable secrets?%s [y/N] ", colorBold, resolvable, colorNC)
		scanner := bufio.NewScanner(os.Stdin)
		if scanner.Scan() {
			confirm := scanner.Text()
			if len(confirm) > 0 && (confirm[0] == 'y' || confirm[0] == 'Y') {
				for _, name := range sortedNames {
					s := byName[name]
					if priorityFilter != "" && s.priority != priorityFilter {
						continue
					}
					if existing[name] {
						continue
					}

					value := resolveValue(s, localValues)
					if value == "" {
						value = tryResolveFromTfvars(name, localValues)
					}
					if value == "" {
						continue
					}

					if dryRun {
						fmt.Printf("%s[DRY-RUN]%s gh secret set %s -R %s\n", colorBlue, colorNC, name, repo)
					} else {
						cmd := exec.Command("gh", "secret", "set", name, "-R", repo, "--body", "-")
						cmd.Stdin = strings.NewReader(value)
						if err := cmd.Run(); err != nil {
							fmt.Fprintf(os.Stderr, "%sFailed to set %s: %v%s\n", colorRed, name, err, colorNC)
						} else {
							fmt.Printf("%s  [SET]%s %s\n", colorGreen, colorNC, name)
						}
					}
				}
			}
		}
	}

	remainingManual := 0
	for _, name := range sortedNames {
		s := byName[name]
		if priorityFilter != "" && s.priority != priorityFilter {
			continue
		}
		if existing[name] {
			continue
		}

		value := resolveValue(s, localValues)
		if value == "" {
			value = tryResolveFromTfvars(name, localValues)
		}
		if value != "" {
			continue
		}

		remainingManual++
		if remainingManual == 1 {
			fmt.Printf("\n%sManual secrets remaining:%s\n", colorBold, colorNC)
			fmt.Printf("Set each with: gh secret set NAME -R %s\n\n", repo)
		}

		fmt.Printf("  %s%-35s%s %s  source: %s\n", colorRed, name, colorNC, s.priority, s.source)
	}

	fmt.Printf("\nDone.\n")
}

func resolveRootDir() string {
	exePath, err := os.Executable()
	if err == nil {
		exeDir := filepath.Dir(exePath)
		candidateRoot := filepath.Dir(exeDir)
		if _, statErr := os.Stat(filepath.Join(candidateRoot, "100-pve")); statErr == nil {
			return candidateRoot
		}
	}

	cwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%sCannot determine working directory%s\n", colorRed, colorNC)
		os.Exit(1)
	}
	return cwd
}

func parseTfvars(file string, values map[string]string) {
	f, err := os.Open(file)
	if err != nil {
		return
	}
	defer f.Close()

	re := regexp.MustCompile(`^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.*)`)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		matches := re.FindStringSubmatch(line)
		if matches == nil {
			continue
		}

		key := matches[1]
		val := strings.TrimSpace(matches[2])

		// Strip surrounding quotes independently (matches shell ${val#\"} / ${val%\"})
		val = strings.TrimPrefix(val, "\"")
		val = strings.TrimSuffix(val, "\"")
		val = strings.TrimPrefix(val, "'")
		val = strings.TrimSuffix(val, "'")
		val = strings.TrimSpace(val)

		if val != "" {
			values[key] = val
		}
	}
}

func resolveValue(s secretEntry, localValues map[string]string) string {
	source := s.source
	idx := strings.Index(source, ":")
	if idx < 0 {
		return ""
	}
	typ := source[:idx]
	rest := source[idx+1:]

	switch typ {
	case "tfvars":
		// rest is "section:key" — extract key after last ":"
		lastColon := strings.LastIndex(rest, ":")
		if lastColon < 0 {
			return ""
		}
		varName := rest[lastColon+1:]
		return localValues[varName]

	case "env":
		return os.Getenv(rest)

	case "op":
		if _, err := exec.LookPath("op"); err != nil {
			return ""
		}
		if os.Getenv("OP_SERVICE_ACCOUNT_TOKEN") == "" {
			return ""
		}
		out, err := exec.Command("op", "read", rest).Output()
		if err != nil {
			return ""
		}
		return strings.TrimSpace(string(out))

	case "derived":
		return rest

	default:
		return ""
	}
}

func tryResolveFromTfvars(name string, localValues map[string]string) string {
	if !strings.HasPrefix(name, "TF_VAR_") {
		return ""
	}
	lowerName := strings.ToLower(strings.TrimPrefix(name, "TF_VAR_"))
	return localValues[lowerName]
}

func fetchExistingSecrets() map[string]bool {
	result := make(map[string]bool)
	out, err := exec.Command("gh", "secret", "list", "-R", repo).Output()
	if err != nil {
		return result
	}

	scanner := bufio.NewScanner(strings.NewReader(string(out)))
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) > 0 {
			result[fields[0]] = true
		}
	}
	return result
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
