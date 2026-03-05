package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	blue   = "\033[0;34m"
	nc     = "\033[0m"
)

var (
	dryRun        bool
	target        = "all"
	secretFilter  string
	inventoryFile string
)

func usage() {
	fmt.Printf(`Usage: %s [--dry-run] [--target cf|github|vault|all] [--secret SECRET_NAME]

Options:
  --dry-run            Print actions without applying changes
  --target TARGET      One of: cf, github, vault, all (default: all)
  --secret NAME        Sync only one secret by name
  -h, --help           Show this help
`, filepath.Base(os.Args[0]))
}

func logMsg(msg string) {
	fmt.Printf("%s%s%s\n", blue, msg, nc)
}

func ok(msg string) {
	fmt.Printf("%s%s%s\n", green, msg, nc)
}

func warn(msg string) {
	fmt.Printf("%s%s%s\n", yellow, msg, nc)
}

func errMsg(msg string) {
	fmt.Fprintf(os.Stderr, "%s%s%s\n", red, msg, nc)
}

func requireCLI(name string) {
	if _, err := exec.LookPath(name); err != nil {
		errMsg("Missing required CLI: " + name)
		os.Exit(1)
	}
}

func runCmd(display string, fn func() error) {
	if dryRun {
		fmt.Printf("[DRY-RUN] %s\n", display)
		return
	}
	if err := fn(); err != nil {
		errMsg("Command failed: " + err.Error())
		os.Exit(1)
	}
}

func yqRead(query string) string {
	cmd := exec.Command("yq", "-r", query, inventoryFile)
	out, err := cmd.Output()
	if err != nil {
		errMsg("yq failed: " + err.Error())
		os.Exit(1)
	}
	return strings.TrimSpace(string(out))
}

func yqCheck(query string) bool {
	cmd := exec.Command("yq", "-e", query, inventoryFile)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func readSecretValue(secretName, vaultPath string) string {
	vaultMount := yqRead(".vault.mount")

	if vaultPath != "" {
		cmd := exec.Command("vault", "kv", "get", "-mount="+vaultMount, "-field="+secretName, vaultPath)
		cmd.Stderr = nil
		if out, err := cmd.Output(); err == nil {
			return strings.TrimSpace(string(out))
		}
	}

	warn("Enter value for " + secretName + ":")

	// Disable terminal echo (equivalent to bash read -r -s)
	sttyOff := exec.Command("stty", "-echo")
	sttyOff.Stdin = os.Stdin
	_ = sttyOff.Run()

	reader := bufio.NewReader(os.Stdin)
	value, _ := reader.ReadString('\n')

	// Re-enable terminal echo
	sttyOn := exec.Command("stty", "echo")
	sttyOn.Stdin = os.Stdin
	_ = sttyOn.Run()

	fmt.Println()

	return strings.TrimRight(value, "\n\r")
}

func syncCFSecret(secretName, secretValue string) {
	storeID := yqRead(".store.id")
	accountID := yqRead(".store.account_id")

	display := fmt.Sprintf(`printf '%%s' "%s" | wrangler secrets-store secret create "%s" --store-id "%s" --account-id "%s" --remote`,
		secretValue, secretName, storeID, accountID)

	runCmd(display, func() error {
		cmd := exec.Command("wrangler", "secrets-store", "secret", "create", secretName,
			"--store-id", storeID, "--account-id", accountID, "--remote")
		cmd.Stdin = strings.NewReader(secretValue)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	})
}

func syncGitHubSecret(secretName, secretValue string) {
	owner := yqRead(".github.owner")

	query := fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets.github[]?`, secretName)
	cmd := exec.Command("yq", "-r", query, inventoryFile)
	out, err := cmd.Output()
	if err != nil {
		return
	}

	for _, repoAlias := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		repoAlias = strings.TrimSpace(repoAlias)
		if repoAlias == "" {
			continue
		}

		repoName := yqRead(fmt.Sprintf(".github.repos.%s", repoAlias))

		display := fmt.Sprintf(`gh secret set "%s" -R "%s/%s" -b "%s"`, secretName, owner, repoName, secretValue)
		runCmd(display, func() error {
			c := exec.Command("gh", "secret", "set", secretName, "-R", owner+"/"+repoName, "-b", secretValue)
			c.Stdout = os.Stdout
			c.Stderr = os.Stderr
			return c.Run()
		})
	}
}

func syncVaultSecret(secretName, secretValue string) {
	vaultMount := yqRead(".vault.mount")

	query := fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets.vault // ""`, secretName)
	vaultPath := yqRead(query)
	if vaultPath == "" {
		return
	}

	display := fmt.Sprintf(`vault kv patch -mount="%s" "%s" "%s=%s"`, vaultMount, vaultPath, secretName, secretValue)
	runCmd(display, func() error {
		c := exec.Command("vault", "kv", "patch", "-mount="+vaultMount, vaultPath, secretName+"="+secretValue)
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		return c.Run()
	})
}

func resolveScriptDir() string {
	// Method 1: source file path via runtime (works with go run)
	_, sourceFile, _, ok := runtime.Caller(0)
	if ok {
		dir := filepath.Dir(sourceFile)
		inv := filepath.Join(dir, "..", "inventory", "secrets.yaml")
		if _, err := os.Stat(inv); err == nil {
			return dir
		}
	}

	// Method 2: executable path (works with compiled binary)
	if execPath, err := os.Executable(); err == nil {
		dir := filepath.Dir(execPath)
		inv := filepath.Join(dir, "..", "inventory", "secrets.yaml")
		if _, err := os.Stat(inv); err == nil {
			return dir
		}
	}

	// Method 3: current working directory fallback
	cwd, _ := os.Getwd()
	return cwd
}

func main() {
	scriptDir := resolveScriptDir()
	inventoryFile = filepath.Join(scriptDir, "..", "inventory", "secrets.yaml")

	// Parse arguments
	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--dry-run":
			dryRun = true
		case "--target":
			i++
			if i >= len(args) {
				errMsg("--target requires a value")
				os.Exit(1)
			}
			target = args[i]
		case "--secret":
			i++
			if i >= len(args) {
				errMsg("--secret requires a value")
				os.Exit(1)
			}
			secretFilter = args[i]
		case "-h", "--help":
			usage()
			os.Exit(0)
		default:
			errMsg("Unknown argument: " + args[i])
			usage()
			os.Exit(1)
		}
	}

	// Require yq always
	requireCLI("yq")

	// Require target-specific CLIs
	switch target {
	case "cf":
		requireCLI("wrangler")
	case "github":
		requireCLI("gh")
	case "vault":
		requireCLI("vault")
	case "all":
		requireCLI("wrangler")
		requireCLI("gh")
		requireCLI("vault")
	default:
		errMsg("Invalid --target value: " + target)
		os.Exit(1)
	}

	// Check inventory file exists
	if _, err := os.Stat(inventoryFile); os.IsNotExist(err) {
		errMsg("Inventory file not found: " + inventoryFile)
		os.Exit(1)
	}

	// Get secret names from inventory
	raw := yqRead(".secrets[].name")
	var secrets []string
	for _, s := range strings.Split(raw, "\n") {
		s = strings.TrimSpace(s)
		if s != "" {
			secrets = append(secrets, s)
		}
	}

	if secretFilter != "" {
		secrets = []string{secretFilter}
	}

	total := len(secrets)

	logMsg(fmt.Sprintf("Starting sync: target=%s, dry-run=%t, secrets=%d", target, dryRun, total))

	for i, secretName := range secrets { // pragma: allowlist secret
		fmt.Printf("[%d/%d] Processing %s\n", i+1, total, secretName)

		// Get vault path for this secret
		vaultPathQuery := fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets.vault // ""`, secretName)
		vaultPath := yqRead(vaultPathQuery)

		// Read secret value (from Vault or stdin prompt)
		secretValue := readSecretValue(secretName, vaultPath)

		if secretValue == "" {
			warn("Skipping " + secretName + ": empty value")
			continue
		}

		// Sync to Cloudflare Secrets Store
		if target == "cf" || target == "all" {
			cfQuery := fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets.cf_store // false`, secretName)
			if yqRead(cfQuery) == "true" {
				logMsg("Syncing " + secretName + " -> Cloudflare Secrets Store")
				syncCFSecret(secretName, secretValue)
			}
		}

		// Sync to GitHub Actions secrets
		if target == "github" || target == "all" {
			ghQuery := fmt.Sprintf(`.secrets[] | select(.name == "%s") | .targets.github`, secretName)
			if yqCheck(ghQuery) {
				logMsg("Syncing " + secretName + " -> GitHub Actions secrets")
				syncGitHubSecret(secretName, secretValue)
			}
		}

		// Sync to Vault
		if target == "vault" || target == "all" {
			if vaultPath != "" {
				logMsg("Syncing " + secretName + " -> Vault")
				syncVaultSecret(secretName, secretValue)
			}
		}

		ok("Done: " + secretName)
	}

	ok("Sync completed.")
}
