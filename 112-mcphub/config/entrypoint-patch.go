// Entrypoint wrapper that applies runtime patches before starting MCPHub.
// Origin: https://github.com/samanhappy/mcphub/pull/654 (closed without merge 2026-03-04)
// Permanent patch — upstream and MCP SDK do not handle _placeholder stripping.
package main

import (
	"fmt"
	"os"
	"os/exec"
)

const patchScript = "/app/patches/patch-placeholder.cjs"
const originalEntrypoint = "/usr/local/bin/entrypoint.sh"

func main() {
	// Apply _placeholder sanitization patch
	if _, err := os.Stat(patchScript); err == nil {
		cmd := exec.Command("node", patchScript)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: patch application failed: %v\n", err)
			// Continue anyway - patch is optional
		}
	}

	// Delegate to original entrypoint
	cmd := exec.Command(originalEntrypoint, os.Args[1:]...)
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
