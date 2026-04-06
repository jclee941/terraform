// Entrypoint wrapper that applies runtime patches before starting MCPHub.
// Patches:
//  1. _placeholder stripping (PR #654, closed without merge)
//  2. MCP SDK inputSchema.type default (Zod v4 strict validation fix)
package main

import (
	"fmt"
	"os"
	"os/exec"
)

const (
	patchPlaceholder = "/app/patches/patch-placeholder.cjs"
	patchSDKSchema   = "/app/patches/patch-sdk-schema.cjs"
	originalEntry    = "/usr/local/bin/entrypoint.sh"
)

func runPatch(script, name string) {
	if _, err := os.Stat(script); err == nil {
		cmd := exec.Command("node", script)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: %s patch failed: %v\n", name, err)
		}
	}
}

func main() {
	runPatch(patchPlaceholder, "placeholder")
	runPatch(patchSDKSchema, "sdk-schema")

	// Delegate to original entrypoint
	cmd := exec.Command(originalEntry, os.Args[1:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Run and preserve exit code
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		fmt.Fprintf(os.Stderr, "Error executing entrypoint: %v\n", err)
		os.Exit(1)
	}
}
