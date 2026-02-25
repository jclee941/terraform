package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"unicode"
)

func main() {
	dryRun := flag.Bool("dry-run", false, "print what would be created without creating")
	flag.Parse()
	args := flag.Args()

	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Usage: go run scripts/scaffold-workspace.go <number> <name>")
		fmt.Fprintln(os.Stderr, "Example: go run scripts/scaffold-workspace.go 113 redis")
		os.Exit(1)
	}

	numberStr := args[0]
	name := args[1]

	// Validate number
	num, err := strconv.Atoi(numberStr)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: '%s' is not a valid integer\n", numberStr)
		os.Exit(1)
	}
	if num < 1 || num > 999 {
		fmt.Fprintln(os.Stderr, "Error: number must be between 1 and 999")
		os.Exit(1)
	}

	// Validate name (kebab-case)
	matched, err := regexp.MatchString(`^[a-z0-9]+(-[a-z0-9]+)*$`, name)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: invalid name pattern: %v\n", err)
		os.Exit(1)
	}
	if !matched {
		fmt.Fprintln(os.Stderr, "Error: name must be lowercase alphanumeric with hyphens only (kebab-case)")
		os.Exit(1)
	}

	// Form directory name
	dirName := fmt.Sprintf("%03d-%s", num, name)
	dirPath := filepath.Join(os.Getenv("PWD"), dirName)

	// Check if directory already exists
	if !*dryRun {
		if _, err := os.Stat(dirPath); err == nil {
			fmt.Fprintf(os.Stderr, "Error: directory '%s' already exists\n", dirName)
			os.Exit(1)
		}
	} else {
		fmt.Printf("[DRY-RUN] Would check if directory '%s' exists (skipping)\n", dirName)
	}

	// Prepare files to create
	// Use string concatenation to avoid nesting backticks
	titleName := titleCase(name)
	agentsStruct := dirName + "/\n" +
		"├── BUILD.bazel\n" +
		"├── OWNERS\n" +
		"├── README.md\n" +
		"├── AGENTS.md\n" +
		"├── main.tf\n" +
		"├── variables.tf\n" +
		"├── outputs.tf\n" +
		"└── versions.tf"

	files := map[string]string{
		"BUILD.bazel":  "package(default_visibility = [\"//visibility:public\"])\n",
		"OWNERS":       "qws941\n",
		"README.md":    "# " + dirName + "\n\n## Overview\n\n" + name + " service workspace.\n\n## Usage\n\n```bash\nmake plan SVC=" + name + "\n```\n",
		"AGENTS.md":    "# " + dirName + "/ Knowledge Base\n\n## OVERVIEW\n\n" + titleName + " service Terraform workspace.\n\n## STRUCTURE\n\n```text\n" + agentsStruct + "\n```\n\n## CONVENTIONS\n\nSee root `AGENTS.md` for global conventions.\n",
		"main.tf":      "# " + titleName + " Service Configuration\n",
		"variables.tf": "# " + titleName + " Variables\n",
		"outputs.tf":   "# " + titleName + " Outputs\n",
		"versions.tf":  "terraform {\n  required_version = \">= 1.0\"\n}\n",
	}

	// Create files
	if *dryRun {
		fmt.Printf("[DRY-RUN] Would create directory: %s\n", dirName)
		for filename := range files {
			fmt.Printf("[DRY-RUN] Would create file: %s/%s\n", dirName, filename)
		}
	} else {
		// Create directory with 0755 permissions
		if err := os.MkdirAll(dirPath, 0755); err != nil {
			fmt.Fprintf(os.Stderr, "Error creating directory: %v\n", err)
			os.Exit(1)
		}

		for filename, content := range files {
			filePath := filepath.Join(dirPath, filename)
			if err := os.WriteFile(filePath, []byte(content), 0644); err != nil {
				fmt.Fprintf(os.Stderr, "Error creating file %s: %v\n", filename, err)
				os.Exit(1)
			}
		}

		fmt.Printf("Created directory: %s\n", dirName)
		for filename := range files {
			fmt.Printf("Created file: %s/%s\n", dirName, filename)
		}
	}
}

// titleCase capitalises the first letter of each hyphen-separated segment.
func titleCase(s string) string {
	parts := strings.Split(s, "-")
	for i, p := range parts {
		if len(p) > 0 {
			runes := []rune(p)
			runes[0] = unicode.ToUpper(runes[0])
			parts[i] = string(runes)
		}
	}
	return strings.Join(parts, " ")
}
