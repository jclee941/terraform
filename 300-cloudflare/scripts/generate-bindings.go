// generate-bindings generates Wrangler secret binding declarations from inventory metadata.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func usage() {
	fmt.Print(`Usage: generate-bindings [--format toml|jsonc] [--out FILE]

Options:
  --format FORMAT    Output format: toml (default) or jsonc
  --out FILE        Write output to file (default: stdout)
  -h, --help        Show this help
`)
}

func main() {
	// Check for help flags before parsing to match shell script behavior
	for _, arg := range os.Args[1:] {
		if arg == "-h" || arg == "--help" {
			usage()
			os.Exit(0)
		}
	}

	format := flag.String("format", "toml", "Output format: toml or jsonc")
	outFile := flag.String("out", "", "Write output to file (default: stdout)")
	flag.Parse()

	// Check for yq
	// Check for yq
	if _, err := exec.LookPath("yq"); err != nil {
		fmt.Fprintln(os.Stderr, "yq is required")
		os.Exit(1)
	}

	// Resolve inventory file path relative to current working directory
	// (scripts are run from repo root: ./300-cloudflare/scripts/...)
	cwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Failed to get current directory")
		os.Exit(1)
	}
	inventoryFile := filepath.Join(cwd, "300-cloudflare", "inventory", "secrets.yaml")

	if _, err := os.Stat(inventoryFile); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Inventory file not found: %s\n", inventoryFile)
		os.Exit(1)
	}

	// Extract store.id
	storeID, err := runYq("-r", ".store.id", inventoryFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to extract store.id: %v\n", err)
		os.Exit(1)
	}
	storeID = strings.TrimSpace(storeID)

	// Extract secret names where targets.cf_store == true
	rawSecrets, err := runYq("-r", ".secrets[] | select(.targets.cf_store == true) | .name", inventoryFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to extract secrets: %v\n", err)
		os.Exit(1)
	}

	var cfSecrets []string
	for _, s := range strings.Split(rawSecrets, "\n") {
		s = strings.TrimSpace(s)
		if s != "" {
			cfSecrets = append(cfSecrets, s)
		}
	}

	// Generate output
	var content string
	switch *format {
	case "toml":
		content = generateToml(cfSecrets, storeID)
	case "jsonc":
		content = generateJsonc(cfSecrets, storeID)
	default:
		fmt.Fprintf(os.Stderr, "Invalid --format: %s\n", *format)
		os.Exit(1)
	}

	// Write output
	if *outFile != "" {
		if err := os.WriteFile(*outFile, []byte(content), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to write output: %v\n", err)
			os.Exit(1)
		}
	} else {
		fmt.Print(content)
	}
}

func runYq(args ...string) (string, error) {
	cmd := exec.Command("yq", args...)
	output, err := cmd.Output()
	if err != nil {
		if ex, ok := err.(*exec.ExitError); ok {
			return "", fmt.Errorf("%s", string(ex.Stderr))
		}
		return "", err
	}
	return string(output), nil
}

func generateToml(secrets []string, storeID string) string {
	var sb strings.Builder
	for _, name := range secrets {
		sb.WriteString("[[secrets_store_secrets]]\n")
		sb.WriteString(fmt.Sprintf("binding = \"%s\"\n", name))
		sb.WriteString(fmt.Sprintf("secret_name = \"%s\"\n", name))
		sb.WriteString(fmt.Sprintf("store_id = \"%s\"\n\n", storeID))
	}
	return sb.String()
}

func generateJsonc(secrets []string, storeID string) string {
	var sb strings.Builder
	sb.WriteString("{\n")
	sb.WriteString("  // Generated from inventory/secrets.yaml\n")
	sb.WriteString("  \"secrets_store_secrets\": [\n")

	lastIdx := len(secrets) - 1
	for i, name := range secrets {
		sb.WriteString("    {\n")
		sb.WriteString(fmt.Sprintf("      \"binding\": \"%s\",\n", name))
		sb.WriteString(fmt.Sprintf("      \"secret_name\": \"%s\",\n", name))
		sb.WriteString(fmt.Sprintf("      \"store_id\": \"%s\"\n", storeID))
		if i == lastIdx {
			sb.WriteString("    }\n")
		} else {
			sb.WriteString("    },\n")
		}
	}

	sb.WriteString("  ]\n")
	sb.WriteString("}\n")
	return sb.String()
}
