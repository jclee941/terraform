package unit

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestLXCConfigVariables validates lxc-config module variables
func TestLXCConfigVariables(t *testing.T) {
	varsPath := "../../modules/proxmox/lxc-config/variables.tf"
	content, err := os.ReadFile(varsPath)
	if err != nil {
		t.Skipf("Cannot read variables.tf: %v", err)
	}

	contentStr := string(content)

	// Check for required variable patterns
	requiredPatterns := []string{
		"variable",
		"containers",
		"deploy_lxc_configs",
	}

	for _, pattern := range requiredPatterns {
		if !strings.Contains(contentStr, pattern) {
			t.Errorf("Missing pattern in variables.tf: %s", pattern)
		}
	}
}

// TestVMConfigVariables validates vm-config module variables
func TestVMConfigVariables(t *testing.T) {
	varsPath := "../../modules/proxmox/vm-config/variables.tf"
	content, err := os.ReadFile(varsPath)
	if err != nil {
		t.Skipf("Cannot read variables.tf: %v", err)
	}

	contentStr := string(content)

	// Check for required variable patterns
	requiredPatterns := []string{
		"variable",
		"vms",
		"cloud_init",
	}

	for _, pattern := range requiredPatterns {
		if !strings.Contains(contentStr, pattern) {
			t.Errorf("Missing pattern in variables.tf: %s", pattern)
		}
	}
}

// TestFilebeatScriptStructure validates install-filebeat.sh structure
func TestFilebeatScriptStructure(t *testing.T) {
	scriptPath := "../../scripts/install-filebeat.sh"
	content, err := os.ReadFile(scriptPath)
	if err != nil {
		t.Skipf("Cannot read install-filebeat.sh: %v", err)
	}

	contentStr := string(content)

	// Validate it's a proper bash script
	if !strings.HasPrefix(contentStr, "#!/usr/bin/env bash") &&
		!strings.HasPrefix(contentStr, "#!/bin/bash") {
		t.Error("Missing shebang")
	}

	// Check for required elements
	requiredElements := []string{
		"set -e",
		"FILEBEAT_VERSION",
		"apt-get",
		"systemctl",
	}

	for _, elem := range requiredElements {
		if !strings.Contains(contentStr, elem) {
			t.Errorf("Missing element: %s", elem)
		}
	}
}

// TestShellScriptNamingConvention validates no new .sh files are added
func TestShellScriptNamingConvention(t *testing.T) {
	// This test enforces the monorepo rule: operational scripts must be Go
	// Exception: Remote execution payloads for Terraform provisioners

	scriptsDir := "../../scripts"
	entries, err := os.ReadDir(scriptsDir)
	if err != nil {
		t.Skipf("Cannot read scripts directory: %v", err)
	}

	var shellScripts []string
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".sh") {
			shellScripts = append(shellScripts, entry.Name())
		}
	}

	// Only allow install-filebeat.sh (documented exception)
	allowedShellScripts := []string{"install-filebeat.sh"}

	for _, script := range shellScripts {
		isAllowed := false
		for _, allowed := range allowedShellScripts {
			if script == allowed {
				isAllowed = true
				break
			}
		}
		if !isAllowed {
			t.Errorf("Unauthorized shell script found: %s. Must be Go.", script)
		}
	}
}

// TestHostsTFStructure validates hosts.tf has required structure
func TestHostsTFStructure(t *testing.T) {
	hostsPath := "../../100-pve/envs/prod/hosts.tf"
	content, err := os.ReadFile(hostsPath)
	if err != nil {
		t.Skipf("Cannot read hosts.tf: %v", err)
	}

	contentStr := string(content)

	// Required structural elements
	requiredElements := []string{
		"locals",
		"hosts = {",
		"output \"hosts\"",
	}

	for _, elem := range requiredElements {
		if !strings.Contains(contentStr, elem) {
			t.Errorf("Missing structural element: %s", elem)
		}
	}

	// Each host should have required fields
	requiredFields := []string{
		"vmid",
		"ip",
		"roles",
		"ports",
	}

	for _, field := range requiredFields {
		if !strings.Contains(contentStr, field) {
			t.Errorf("Missing field pattern: %s", field)
		}
	}
}

// TestTerraformModuleStructure validates standard module structure
func TestTerraformModuleStructure(t *testing.T) {
	modules := []string{
		"../../modules/proxmox/lxc",
		"../../modules/proxmox/vm",
		"../../modules/proxmox/lxc-config",
		"../../modules/proxmox/vm-config",
		"../../modules/shared/onepassword-secrets",
	}

	for _, modulePath := range modules {
		t.Run(filepath.Base(modulePath), func(t *testing.T) {
			// Check module exists
			if _, err := os.Stat(modulePath); os.IsNotExist(err) {
				t.Skipf("Module not found: %s", modulePath)
			}

			// Required files
			requiredFiles := []string{"main.tf", "variables.tf", "outputs.tf"}
			for _, file := range requiredFiles {
				path := filepath.Join(modulePath, file)
				if _, err := os.Stat(path); os.IsNotExist(err) {
					t.Errorf("Missing required file: %s", file)
				}
			}
		})
	}
}
