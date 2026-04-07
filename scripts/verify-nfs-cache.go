// Usage: go run scripts/verify-nfs-cache.go [--json] [--fix]

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

var (
	synologyHost = "192.168.50.215"
	proxmoxHost  = "192.168.50.100"
	lxcID        = "101"
	outputJSON   = flag.Bool("json", false, "Output results as JSON")
	autoFix      = flag.Bool("fix", false, "Attempt to fix issues automatically")
)

type Check struct {
	Name    string `json:"name"`
	Status  string `json:"status"` // ok, warn, error
	Message string `json:"message"`
	Command string `json:"command,omitempty"`
}

type HealthReport struct {
	Overall string  `json:"overall"`
	Checks  []Check `json:"checks"`
}

func main() {
	flag.Parse()

	report := HealthReport{
		Checks: []Check{},
	}

	// Run all checks
	report.Checks = append(report.Checks, checkSynologyNFS())
	report.Checks = append(report.Checks, checkProxmoxMount())
	report.Checks = append(report.Checks, checkLXCConfig())
	report.Checks = append(report.Checks, checkLXCMount())
	report.Checks = append(report.Checks, checkRunnerService())
	report.Checks = append(report.Checks, checkRegistryRouting())

	// Determine overall status
	hasError := false
	hasWarn := false
	for _, check := range report.Checks {
		if check.Status == "error" {
			hasError = true
		} else if check.Status == "warn" {
			hasWarn = true
		}
	}

	if hasError {
		report.Overall = "unhealthy"
	} else if hasWarn {
		report.Overall = "degraded"
	} else {
		report.Overall = "healthy"
	}

	// Output results
	if *outputJSON {
		output, _ := json.MarshalIndent(report, "", "  ")
		fmt.Println(string(output))
	} else {
		printHumanReport(report)
	}

	// Exit with error code if unhealthy
	if hasError {
		os.Exit(1)
	}
}

func checkSynologyNFS() Check {
	check := Check{Name: "Synology NFS Export", Status: "ok", Command: fmt.Sprintf("showmount -e %s", synologyHost)}

	cmd := exec.Command("showmount", "-e", synologyHost)
	output, err := cmd.CombinedOutput()
	if err != nil {
		check.Status = "error"
		check.Message = fmt.Sprintf("Cannot query NFS exports: %v", err)
		return check
	}

	if strings.Contains(string(output), "gitlab-runner-cache") {
		check.Message = "NFS share is exported"
	} else {
		check.Status = "error"
		check.Message = "NFS share not found in exports"

		if *autoFix {
			fmt.Println("  → Attempting to create NFS share on Synology...")
			fixCmd := fmt.Sprintf(
				"ssh root@%s 'synoshare --add gitlab-runner-cache \"GitLab Runner Cache\" /volume1/gitlab-runner-cache; synoshare --setnfs gitlab-runner-cache enable; synonfsext --add-rule gitlab-runner-cache 192.168.50.0/24 rw'",
				synologyHost,
			)
			if err := exec.Command("bash", "-c", fixCmd).Run(); err == nil {
				check.Status = "warn"
				check.Message = "NFS share created, retry verification"
			}
		}
	}

	return check
}

func checkProxmoxMount() Check {
	check := Check{Name: "Proxmox NFS Mount", Status: "ok", Command: fmt.Sprintf("ssh %s 'mountpoint /mnt/gitlab-runner-cache'", proxmoxHost)}

	cmd := exec.Command("ssh", proxmoxHost, "mountpoint -q /mnt/gitlab-runner-cache && echo mounted")
	output, err := cmd.CombinedOutput()

	if err != nil || !strings.Contains(string(output), "mounted") {
		check.Status = "error"
		check.Message = "NFS not mounted on Proxmox"

		if *autoFix {
			fmt.Println("  → Attempting to mount NFS...")
			mountCmd := fmt.Sprintf(
				"ssh %s 'mkdir -p /mnt/gitlab-runner-cache && mount -t nfs -o vers=4.1 %s:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache'",
				proxmoxHost, synologyHost,
			)
			if err := exec.Command("bash", "-c", mountCmd).Run(); err == nil {
				check.Status = "warn"
				check.Message = "NFS mounted, retry verification"
			}
		}
	} else {
		check.Message = "NFS mounted at /mnt/gitlab-runner-cache"
	}

	return check
}

func checkLXCConfig() Check {
	check := Check{Name: "LXC Mount Configuration", Status: "ok", Command: fmt.Sprintf("ssh %s 'cat /etc/pve/lxc/%s.conf | grep mp0'", proxmoxHost, lxcID)}

	cmd := exec.Command("ssh", proxmoxHost, fmt.Sprintf("cat /etc/pve/lxc/%s.conf", lxcID))
	output, err := cmd.CombinedOutput()
	if err != nil {
		check.Status = "error"
		check.Message = fmt.Sprintf("Cannot read LXC config: %v", err)
		return check
	}

	if strings.Contains(string(output), "gitlab-runner-cache") {
		check.Message = "LXC has NFS cache mount point configured"
	} else {
		check.Status = "error"
		check.Message = "LXC missing NFS cache mount point"
	}

	return check
}

func checkLXCMount() Check {
	check := Check{Name: "LXC Container Mount", Status: "ok", Command: fmt.Sprintf("ssh %s 'pct exec %s -- df -h /srv/gitlab-runner/cache'", proxmoxHost, lxcID)}

	cmd := exec.Command("ssh", proxmoxHost, fmt.Sprintf("pct exec %s -- mountpoint -q /srv/gitlab-runner/cache && echo mounted", lxcID))
	output, err := cmd.CombinedOutput()

	if err != nil || !strings.Contains(string(output), "mounted") {
		check.Status = "error"
		check.Message = fmt.Sprintf("Cache directory not mounted inside LXC %s", lxcID)
	} else {
		// Get disk usage
		dfCmd := exec.Command("ssh", proxmoxHost, fmt.Sprintf("pct exec %s -- df -h /srv/gitlab-runner/cache", lxcID))
		dfOutput, _ := dfCmd.CombinedOutput()
		lines := strings.Split(string(dfOutput), "\n")
		if len(lines) > 1 {
			check.Message = fmt.Sprintf("Mounted: %s", strings.TrimSpace(lines[1]))
		} else {
			check.Message = "Cache directory mounted"
		}
	}

	return check
}

func checkRunnerService() Check {
	check := Check{Name: "GitLab Runner Service", Status: "ok", Command: fmt.Sprintf("ssh %s 'pct exec %s -- systemctl is-active gitlab-runner'", proxmoxHost, lxcID)}

	cmd := exec.Command("ssh", proxmoxHost, fmt.Sprintf("pct exec %s -- systemctl is-active gitlab-runner", lxcID))
	_, err := cmd.CombinedOutput()

	if err != nil {
		check.Status = "error"
		check.Message = "GitLab Runner service is not active"

		if *autoFix {
			fmt.Println("  → Attempting to start GitLab Runner...")
			startCmd := fmt.Sprintf("ssh %s 'pct exec %s -- systemctl start gitlab-runner'", proxmoxHost, lxcID)
			if err := exec.Command("bash", "-c", startCmd).Run(); err == nil {
				check.Status = "warn"
				check.Message = "Service started, retry verification"
			}
		}
	} else {
		check.Message = "GitLab Runner is active"
	}

	return check
}

func checkRegistryRouting() Check {
	check := Check{Name: "Registry DNS/Routing", Status: "ok", Command: "curl -sI https://registry.jclee.me"}

	cmd := exec.Command("curl", "-sI", "https://registry.jclee.me")
	output, err := cmd.CombinedOutput()

	if err != nil {
		check.Status = "warn"
		check.Message = fmt.Sprintf("Cannot reach registry: %v", err)
	} else if strings.Contains(string(output), "200") || strings.Contains(string(output), "401") {
		// 401 is ok - means registry is reachable but requires auth
		check.Message = "registry.jclee.me is reachable"
	} else {
		check.Status = "warn"
		check.Message = "Unexpected response from registry"
	}

	return check
}

func printHumanReport(report HealthReport) {
	fmt.Println()
	fmt.Println("╔══════════════════════════════════════════════════════════╗")
	fmt.Println("║          NFS Cache Infrastructure Health Check           ║")
	fmt.Println("╚══════════════════════════════════════════════════════════╝")
	fmt.Println()

	for _, check := range report.Checks {
		symbol := "✓"
		if check.Status == "warn" {
			symbol = "⚠"
		} else if check.Status == "error" {
			symbol = "✗"
		}

		fmt.Printf("%s %-35s %s\n", symbol, check.Name+":", check.Status)
		fmt.Printf("  %s\n", check.Message)
		if check.Command != "" {
			fmt.Printf("  Command: %s\n", check.Command)
		}
		fmt.Println()
	}

	fmt.Println(strings.Repeat("─", 60))

	symbol := "✓"
	if report.Overall == "degraded" {
		symbol = "⚠"
	} else if report.Overall == "unhealthy" {
		symbol = "✗"
	}

	fmt.Printf("%s Overall Status: %s\n", symbol, strings.ToUpper(report.Overall))
	fmt.Println()
}
