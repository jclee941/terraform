// Usage: go run scripts/deploy-nfs-cache.go [--dry-run] [--step=all|synology|proxmox|runner]

package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

var (
	synologyHost = "192.168.50.215"
	proxmoxHost  = "192.168.50.100"
	lxcID        = "101"
	step         = flag.String("step", "all", "Deployment step: all, synology, proxmox, runner")
	dryRun       = flag.Bool("dry-run", false, "Show commands without executing")
	verbose      = flag.Bool("v", false, "Verbose output")
)

func main() {
	flag.Parse()

	fmt.Println("╔══════════════════════════════════════════════════════════╗")
	fmt.Println("║     GitLab Runner NFS Cache Deployment Tool             ║")
	fmt.Println("╚══════════════════════════════════════════════════════════╝")
	fmt.Println()

	switch *step {
	case "synology":
		deploySynology()
	case "proxmox":
		deployProxmox()
	case "runner":
		deployRunner()
	case "all":
		deploySynology()
		deployProxmox()
		deployRunner()
	default:
		fmt.Fprintf(os.Stderr, "Unknown step: %s\n", *step)
		os.Exit(1)
	}

	fmt.Println()
	fmt.Println("╔══════════════════════════════════════════════════════════╗")
	fmt.Println("║              Deployment Complete!                        ║")
	fmt.Println("╚══════════════════════════════════════════════════════════╝")
}

func deploySynology() {
	fmt.Println("▶ Step 1/3: Setting up NFS share on Synology...")

	// Check if share exists
	cmd := sshCommand(synologyHost, "synoshare --get gitlab-runner-cache")
	if err := cmd.Run(); err == nil {
		fmt.Println("  ✓ NFS share already exists on Synology")
		return
	}

	commands := []string{
		"mkdir -p /volume1/gitlab-runner-cache",
		"synoshare --add gitlab-runner-cache \"GitLab Runner Cache\" /volume1/gitlab-runner-cache",
		"synoshare --setnfs gitlab-runner-cache enable",
		"synonfsext --add-rule gitlab-runner-cache 192.168.50.0/24 rw",
	}

	for _, cmdStr := range commands {
		if *verbose || *dryRun {
			fmt.Printf("  $ %s\n", cmdStr)
		}
		if !*dryRun {
			cmd := sshCommand(synologyHost, cmdStr)
			if output, err := cmd.CombinedOutput(); err != nil {
				// Some commands may fail if already configured, that's ok
				if *verbose {
					fmt.Printf("    (may be already configured: %s)\n", strings.TrimSpace(string(output)))
				}
			}
		}
	}

	fmt.Println("  ✓ Synology NFS share configured")
}

func deployProxmox() {
	fmt.Println("▶ Step 2/3: Configuring Proxmox and LXC...")

	// Check current mount status
	cmd := sshCommand(proxmoxHost, "mountpoint -q /mnt/gitlab-runner-cache && echo mounted")
	if output, _ := cmd.CombinedOutput(); strings.Contains(string(output), "mounted") {
		fmt.Println("  ✓ NFS already mounted on Proxmox")
	} else {
		// Mount NFS
		mountCmd := fmt.Sprintf(
			"mkdir -p /mnt/gitlab-runner-cache && mount -t nfs -o vers=4.1,hard,intr %s:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache",
			synologyHost,
		)
		if *verbose || *dryRun {
			fmt.Printf("  $ %s\n", mountCmd)
		}
		if !*dryRun {
			cmd := sshCommand(proxmoxHost, mountCmd)
			if err := cmd.Run(); err != nil {
				fmt.Printf("  ✗ Failed to mount NFS: %v\n", err)
				os.Exit(1)
			}
		}
	}

	// Add to fstab
	fstabEntry := fmt.Sprintf("%s:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache nfs vers=4.1,hard,intr 0 0", synologyHost)
	checkFstab := fmt.Sprintf("grep -q '%s' /etc/fstab", synologyHost)

	cmd = sshCommand(proxmoxHost, checkFstab)
	if err := cmd.Run(); err != nil {
		// Not in fstab, add it
		addFstab := fmt.Sprintf("echo '%s' >> /etc/fstab", fstabEntry)
		if *verbose || *dryRun {
			fmt.Printf("  $ %s\n", addFstab)
		}
		if !*dryRun {
			cmd := sshCommand(proxmoxHost, addFstab)
			if err := cmd.Run(); err != nil {
				fmt.Printf("  ⚠ Failed to update fstab: %v\n", err)
			}
		}
	}

	// Configure LXC
	fmt.Println("  Configuring LXC mount point...")

	// Backup config
	backupCmd := fmt.Sprintf(
		"cp /etc/pve/lxc/%s.conf /etc/pve/lxc/%s.conf.backup-$(date +%%Y%%m%%d-%%H%%M%%S)",
		lxcID, lxcID,
	)
	if !*dryRun {
		sshCommand(proxmoxHost, backupCmd).Run()
	}

	// Update LXC config
	lxcCommands := []string{
		fmt.Sprintf("sed -i '/mp0:.*gitlab-runner-cache/d' /etc/pve/lxc/%s.conf", lxcID),
		fmt.Sprintf("echo 'mp0: /mnt/gitlab-runner-cache,mp=/srv/gitlab-runner/cache' >> /etc/pve/lxc/%s.conf", lxcID),
	}

	for _, cmdStr := range lxcCommands {
		if *verbose || *dryRun {
			fmt.Printf("  $ %s\n", cmdStr)
		}
		if !*dryRun {
			if err := sshCommand(proxmoxHost, cmdStr).Run(); err != nil {
				fmt.Printf("  ✗ LXC config update failed: %v\n", err)
				os.Exit(1)
			}
		}
	}

	// Restart LXC
	fmt.Println("  Restarting LXC container...")
	restartCmds := []string{
		fmt.Sprintf("pct stop %s 2>/dev/null || true", lxcID),
		"sleep 2",
		fmt.Sprintf("pct start %s", lxcID),
	}

	for _, cmdStr := range restartCmds {
		if *verbose || *dryRun {
			fmt.Printf("  $ %s\n", cmdStr)
		}
		if !*dryRun {
			if err := sshCommand(proxmoxHost, cmdStr).Run(); err != nil {
				fmt.Printf("  ✗ LXC restart failed: %v\n", err)
				os.Exit(1)
			}
		}
	}

	// Wait for LXC to be ready
	fmt.Println("  Waiting for LXC to be ready...")
	if !*dryRun {
		for i := 0; i < 30; i++ {
			checkCmd := sshCommand(proxmoxHost, fmt.Sprintf("pct exec %s -- echo ready", lxcID))
			if err := checkCmd.Run(); err == nil {
				fmt.Println("  ✓ LXC is ready")
				break
			}
			time.Sleep(2 * time.Second)
		}
	}

	fmt.Println("  ✓ Proxmox configuration complete")
}

func deployRunner() {
	fmt.Println("▶ Step 3/3: Setting up GitLab Runner...")

	// Copy setup script to Proxmox temp
	copyCmd := fmt.Sprintf("scp scripts/setup-gitlab-runner-with-cache.go root@%s:/tmp/", proxmoxHost)
	if *verbose || *dryRun {
		fmt.Printf("  $ %s\n", copyCmd)
	}
	if !*dryRun {
		parts := strings.Fields(copyCmd)
		cmd := exec.Command(parts[0], parts[1:]...)
		if err := cmd.Run(); err != nil {
			fmt.Printf("  ✗ Failed to copy setup script: %v\n", err)
			os.Exit(1)
		}
	}

	// Push script into LXC and run it
	runnerCmd := fmt.Sprintf(
		"pct exec %s -- mkdir -p /opt/runner/scripts && "+
			"pct push %s /tmp/setup-gitlab-runner-with-cache.go /opt/runner/scripts/setup-gitlab-runner-with-cache.go && "+
			"pct exec %s -- bash -c 'cd /opt/runner/scripts && go run setup-gitlab-runner-with-cache.go'",
		lxcID, lxcID, lxcID,
	)

	if *verbose || *dryRun {
		fmt.Printf("  $ %s\n", runnerCmd)
	}
	if !*dryRun {
		cmd := sshCommand(proxmoxHost, runnerCmd)
		if output, err := cmd.CombinedOutput(); err != nil {
			fmt.Printf("  ✗ Runner setup failed: %v\n%s\n", err, output)
			os.Exit(1)
		}
	}

	// Verify runner status
	statusCmd := fmt.Sprintf("pct exec %s -- systemctl is-active gitlab-runner", lxcID)
	if *verbose || *dryRun {
		fmt.Printf("  $ %s\n", statusCmd)
	}
	if !*dryRun {
		cmd := sshCommand(proxmoxHost, statusCmd)
		if err := cmd.Run(); err != nil {
			fmt.Println("  ⚠ Runner service may not be active yet")
		} else {
			fmt.Println("  ✓ GitLab Runner is active")
		}
	}

	fmt.Println("  ✓ GitLab Runner setup complete")
}

func sshCommand(host, command string) *exec.Cmd {
	sshOpts := []string{
		"-o", "StrictHostKeyChecking=no",
		"-o", "UserKnownHostsFile=/dev/null",
		"-o", "ConnectTimeout=10",
	}
	args := append(sshOpts, fmt.Sprintf("root@%s", host), command)
	return exec.Command("ssh", args...)
}
