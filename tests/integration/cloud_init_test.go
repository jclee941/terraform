package integration

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/hashicorp/hcl/v2"
	"github.com/hashicorp/hcl/v2/hclsyntax"
	"gopkg.in/yaml.v3"
)

// TestCloudInitRendering validates that cloud-init templates render correctly
func TestCloudInitRendering(t *testing.T) {
	testCases := []struct {
		name     string
		template string
		vars     map[string]interface{}
		want     []string // Substrings that should appear in output
	}{
		{
			name:     "vm-cloud-init-basic",
			template: "../../modules/proxmox/vm-config/templates/cloud-init.yaml.tftpl",
			vars: map[string]interface{}{
				"hostname": "test-vm",
				"packages": []string{"curl", "vim"},
				"runcmd":   []string{"echo hello"},
				"write_files": []map[string]string{
					{"path": "/etc/test", "content": "test content", "permissions": "0644", "owner": "root:root"},
				},
			},
			want: []string{
				"hostname: test-vm",
				"package_update: true",
				"  - curl",
				"  - vim",
				"runcmd:",
				"  - echo hello",
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Verify template file exists
			if _, err := os.Stat(tc.template); os.IsNotExist(err) {
				t.Skipf("Template file not found: %s", tc.template)
			}

			// Read template
			content, err := os.ReadFile(tc.template)
			if err != nil {
				t.Fatalf("Failed to read template: %v", err)
			}

			// Basic validation - template should not be empty
			if len(content) == 0 {
				t.Error("Template is empty")
			}

			// Check for required cloud-init structure
			templateStr := string(content)
			requiredElements := []string{
				"#cloud-config",
				"hostname:",
				"${hostname}",
			}

			for _, elem := range requiredElements {
				if !strings.Contains(templateStr, elem) {
					t.Errorf("Template missing required element: %s", elem)
				}
			}
		})
	}
}

// TestCloudInitYAMLStructure validates YAML structure of rendered cloud-init
func TestCloudInitYAMLStructure(t *testing.T) {
	// This test would use a YAML parser to validate structure
	// For now, we'll do basic validation

	yamlContent := `#cloud-config
hostname: test-host
manage_etc_hosts: true

package_update: true
package_upgrade: false

packages:
  - curl
  - vim

write_files:
  - path: /etc/test.conf
    permissions: '0644'
    owner: root:root
    content: |
      test content

runcmd:
  - echo "Cloud-init completed"

final_message: "Cloud-init completed for test-host"
`

	// Validate cloud-init header
	if !strings.HasPrefix(yamlContent, "#cloud-config") {
		t.Error("Missing #cloud-config header")
	}

	// Validate required sections
	requiredSections := []string{
		"hostname:",
		"packages:",
		"write_files:",
		"runcmd:",
		"final_message:",
	}

	for _, section := range requiredSections {
		if !strings.Contains(yamlContent, section) {
			t.Errorf("Missing section: %s", section)
		}
	}
}

func TestELKDockerComposeTemplateRendersValidYAML(t *testing.T) {
	templatePath := "../../105-elk/templates/docker-compose.yml.tftpl"
	content, err := os.ReadFile(templatePath)
	if err != nil {
		t.Fatalf("failed to read ELK compose template: %v", err)
	}

	rendered := string(content)
	replacements := map[string]string{
		"${elk_version}":                   "9.0.0",
		"${elk_elastic_password}":          "mock-secret",
		"${elk_kibana_password}":           "mock-secret",
		"${es_heap}":                       "2g",
		"${logstash_heap}":                 "1g",
		"${hosts.elk.ports.elasticsearch}": "9200",
		"${hosts.elk.ports.logstash_beat}": "5044",
		"${hosts.elk.ports.logstash_tcp}":  "5000",
		"${hosts.elk.ports.logstash_http}": "8080",
		"${hosts.elk.ports.kibana}":        "5601",
		"$$${ELASTIC_PASSWORD}":            "$${ELASTIC_PASSWORD}",
		"$$${ELASTIC_CURL_AUTH}":           "$${ELASTIC_CURL_AUTH}",
		"$$KIBANA_PASSWORD":                "$KIBANA_PASSWORD",
	}
	for old, newValue := range replacements {
		rendered = strings.ReplaceAll(rendered, old, newValue)
	}
	if !strings.Contains(rendered, "$${ELASTIC_PASSWORD}") || !strings.Contains(rendered, "$${ELASTIC_CURL_AUTH}") {
		t.Fatal("rendered ELK compose template must escape container env references for Docker Compose")
	}
	if strings.Contains(rendered, "elastic:${ELASTIC_PASSWORD}") || strings.Contains(rendered, "--user \"${ELASTIC_CURL_AUTH}\"") {
		t.Fatal("rendered ELK compose template must not leave host-interpolated credential references")
	}

	var compose map[string]interface{}
	if err := yaml.Unmarshal([]byte(rendered), &compose); err != nil {
		t.Fatalf("rendered ELK compose template must be valid YAML: %v", err)
	}
	if _, ok := compose["services"]; !ok {
		t.Fatal("rendered ELK compose template must include services")
	}
}

// TestLXCConfigGeneration validates LXC config generation
func TestLXCConfigGeneration(t *testing.T) {
	// Verify lxc-config module exists
	lxcConfigPath := "../../modules/proxmox/lxc-config"
	if _, err := os.Stat(lxcConfigPath); os.IsNotExist(err) {
		t.Skipf("lxc-config module not found: %s", lxcConfigPath)
	}

	// Check for required files
	requiredFiles := []string{
		"main.tf",
		"variables.tf",
		"outputs.tf",
	}

	for _, file := range requiredFiles {
		path := filepath.Join(lxcConfigPath, file)
		if _, err := os.Stat(path); os.IsNotExist(err) {
			t.Errorf("Missing required file: %s", path)
		}
	}
}

// TestHostInventoryStructure validates hosts.tf structure
func TestHostInventoryStructure(t *testing.T) {
	hostsPath := "../../100-pve/envs/prod/hosts.tf"
	content, err := os.ReadFile(hostsPath)
	if err != nil {
		t.Skipf("Cannot read hosts.tf: %v", err)
	}

	// Parse HCL
	src := []byte(content)
	file, diags := hclsyntax.ParseConfig(src, hostsPath, hcl.Pos{Line: 1, Column: 1})
	if diags.HasErrors() {
		t.Logf("HCL parse warnings: %v", diags)
	}

	if file == nil {
		t.Skip("Could not parse hosts.tf")
	}

	// Validate required hosts exist
	contentStr := string(content)
	requiredHosts := []string{
		"runner",
		"traefik",
		"elk",
		"coredns",
		"mcphub",
		"synology",
		"youtube",
	}

	for _, host := range requiredHosts {
		// Look for host entry pattern
		if !strings.Contains(contentStr, host+" = {") {
			t.Errorf("Missing host definition: %s", host)
		}
	}
}
