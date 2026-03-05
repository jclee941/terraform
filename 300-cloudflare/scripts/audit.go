package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const (
	green  = "\033[0;32m"
	red    = "\033[0;31m"
	yellow = "\033[1;33m"
	nc     = "\033[0m"
)

func usage() {
	fmt.Printf(`Usage: %s [OPTIONS]

Audit all secrets defined in inventory/secrets.yaml against actual targets
(GitHub repos, Vault paths, Cloudflare Secrets Store).

Options:
  --help    Show this help message

Required CLIs: yq, gh, vault, wrangler
`, filepath.Base(os.Args[0]))
	os.Exit(0)
}

func requireCLI(cli string) {
	if _, err := exec.LookPath(cli); err != nil {
		fmt.Fprintf(os.Stderr, "%s❌ Missing required CLI: %s%s\n", red, cli, nc)
		os.Exit(1)
	}
}

func printPresent(label string) {
	fmt.Printf("%s✅ present%s %s\n", green, nc, label)
}

func printMissing(label string) {
	fmt.Printf("%s❌ missing%s %s\n", red, nc, label)
}

func printUnknown(label string) {
	fmt.Printf("%s⚠️ unknown%s %s\n", yellow, nc, label)
}

func yqRead(expr, file string) string {
	out, err := exec.Command("yq", "-r", expr, file).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func yqReadLines(expr, file string) []string {
	out, err := exec.Command("yq", "-r", expr, file).Output()
	if err != nil {
		return nil
	}
	var lines []string
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}

func checkGitHubSecret(owner, repo, secretName string) bool {
	out, err := exec.Command("gh", "secret", "list", "-R", owner+"/"+repo).Output()
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(line)
		if len(fields) > 0 && fields[0] == secretName {
			return true
		}
	}
	return false
}

func checkVaultSecret(mount, path, secretName string) bool {
	cmd := exec.Command("vault", "kv", "get", "-mount="+mount, "-field="+secretName, path)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func checkCFSecret(storeID, accountID, secretName string) bool {
	out, err := exec.Command("wrangler", "secrets-store", "secret", "list",
		"--store-id", storeID, "--account-id", accountID).Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), secretName)
}

func main() {
	if len(os.Args) > 1 && (os.Args[1] == "--help" || os.Args[1] == "-h") {
		usage()
	}

	requireCLI("yq")
	requireCLI("gh")
	requireCLI("vault")
	requireCLI("wrangler")

	// Resolve inventory file relative to the script/executable location
	exePath, err := os.Executable()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s❌ missing%s cannot determine script directory\n", red, nc)
		os.Exit(1)
	}
	// If running via "go run", os.Executable() points to a temp dir.
	// Fall back to working directory in that case.
	scriptDir := filepath.Dir(exePath)
	inventoryFile := filepath.Join(scriptDir, "..", "inventory", "secrets.yaml")

	// Heuristic: if the executable is in a tmp/go-build directory, use CWD-based resolution
	if strings.Contains(exePath, "go-build") || strings.Contains(exePath, "/tmp/") {
		// When run via "go run 300-cloudflare/scripts/audit.go", find the source file
		// relative to the current working directory
		cwd, err := os.Getwd()
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s❌ missing%s cannot determine working directory\n", red, nc)
			os.Exit(1)
		}
		// Check if invoked with a path argument containing the script location
		for _, arg := range os.Args {
			if strings.HasSuffix(arg, "audit.go") {
				dir := filepath.Dir(arg)
				inventoryFile = filepath.Join(cwd, dir, "..", "inventory", "secrets.yaml")
				break
			}
		}
		// If no matching arg found, fall back to scriptDir-based path
		if _, err := os.Stat(inventoryFile); err != nil {
			inventoryFile = filepath.Join(cwd, "300-cloudflare", "inventory", "secrets.yaml")
		}
	}

	if _, err := os.Stat(inventoryFile); err != nil {
		fmt.Fprintf(os.Stderr, "%s❌ missing%s inventory file: %s\n", red, nc, inventoryFile)
		os.Exit(1)
	}

	owner := yqRead(".github.owner", inventoryFile)
	vaultMount := yqRead(".vault.mount", inventoryFile)
	storeID := yqRead(".store.id", inventoryFile)
	accountID := yqRead(".store.account_id", inventoryFile)

	missingCount := 0

	secretNames := yqReadLines(".secrets[].name", inventoryFile)
	for _, secretName := range secretNames { // pragma: allowlist secret
		// Check GitHub targets
		repoAliases := yqReadLines(
			fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets.github[]?`, secretName),
			inventoryFile,
		)
		for _, repoAlias := range repoAliases {
			repoName := yqRead(fmt.Sprintf(".github.repos.%s", repoAlias), inventoryFile)
			if checkGitHubSecret(owner, repoName, secretName) {
				printPresent(fmt.Sprintf("github:%s/%s:%s", owner, repoName, secretName))
			} else {
				printMissing(fmt.Sprintf("github:%s/%s:%s", owner, repoName, secretName))
				missingCount++
			}
		}

		// Check Vault target
		vaultPath := yqRead(
			fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets.vault // ""`, secretName),
			inventoryFile,
		)
		if vaultPath != "" {
			if checkVaultSecret(vaultMount, vaultPath, secretName) {
				printPresent(fmt.Sprintf("vault:%s/%s:%s", vaultMount, vaultPath, secretName))
			} else {
				printMissing(fmt.Sprintf("vault:%s/%s:%s", vaultMount, vaultPath, secretName))
				missingCount++
			}
		}

		// Check CF Secrets Store target
		cfStore := yqRead(
			fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets.cf_store // false`, secretName),
			inventoryFile,
		)
		if cfStore == "true" {
			if checkCFSecret(storeID, accountID, secretName) {
				printPresent(fmt.Sprintf("cf_store:%s:%s", storeID, secretName))
			} else {
				printMissing(fmt.Sprintf("cf_store:%s:%s", storeID, secretName))
				missingCount++
			}
		}

		// Check if targets are defined
		cmd := exec.Command("yq", "-e",
			fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets`, secretName),
			inventoryFile,
		)
		cmd.Stdout = nil
		cmd.Stderr = nil
		if err := cmd.Run(); err != nil {
			printUnknown(fmt.Sprintf("targets-not-defined:%s", secretName))
		}
	}

	if missingCount > 0 {
		fmt.Printf("%s❌ Audit failed%s: %d missing secret bindings\n", red, nc, missingCount)
		os.Exit(1)
	}

	fmt.Printf("%s✅ Audit passed%s: all configured secret bindings were found\n", green, nc)
}
