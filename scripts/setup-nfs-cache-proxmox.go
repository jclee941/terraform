package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	nc     = "\033[0m"
)

type config struct {
	nfsServer    string
	nfsShare     string
	mountPoint   string
	lxcID        string
	lxcMountPath string
	fstabEntry   string
}

func main() {
	if os.Geteuid() != 0 {
		fmt.Fprintf(os.Stderr, "%s[-]%s This script must be run as root\n", red, nc)
		os.Exit(1)
	}

	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "%s[-]%s %v\n", red, nc, err)
		os.Exit(1)
	}
}

func run() error {
	cfg := config{
		nfsServer:    "192.168.50.215",
		nfsShare:     "/volume1/gitlab-runner-cache",
		mountPoint:   "/mnt/gitlab-runner-cache",
		lxcID:        "101",
		lxcMountPath: "/srv/gitlab-runner/cache",
		fstabEntry:   "192.168.50.215:/volume1/gitlab-runner-cache /mnt/gitlab-runner-cache nfs _netdev,x-systemd.automount,hard,noatime,rsize=1048576,wsize=1048576,timeo=600 0 0",
	}

	log("=== GitLab Runner NFS Cache Setup for Proxmox Host ===")
	log("NFS Server: %s", cfg.nfsServer)
	log("NFS Share: %s", cfg.nfsShare)
	log("Mount Point: %s", cfg.mountPoint)
	log("LXC ID: %s", cfg.lxcID)
	log("")

	// Step 1: Install NFS client
	if err := installNFSClient(); err != nil {
		return fmt.Errorf("install NFS client: %w", err)
	}

	// Step 2: Create mount point
	if err := createMountPoint(cfg.mountPoint); err != nil {
		return fmt.Errorf("create mount point: %w", err)
	}

	// Step 3: Test NFS connectivity
	if err := testNFSConnectivity(cfg); err != nil {
		return err
	}

	// Step 4: Mount NFS share
	if err := mountNFSShare(cfg); err != nil {
		return fmt.Errorf("mount NFS share: %w", err)
	}

	// Step 5: Test write access
	if err := testWriteAccess(cfg); err != nil {
		return fmt.Errorf("test write access: %w", err)
	}

	// Step 6: Add to fstab
	if err := addToFstab(cfg); err != nil {
		return fmt.Errorf("add to fstab: %w", err)
	}

	// Step 7: Update LXC config
	if err := updateLXCConfig(cfg); err != nil {
		return fmt.Errorf("update LXC config: %w", err)
	}

	log("")
	log("=== Setup Complete ===")
	log("")
	log("Next steps:")
	log("1. Restart LXC %s if it's running:", cfg.lxcID)
	log("   pct stop %s && pct start %s", cfg.lxcID, cfg.lxcID)
	log("")
	log("2. Verify mount inside container:")
	log("   pct exec %s -- df -h %s", cfg.lxcID, cfg.lxcMountPath)
	log("")
	log("3. Test write inside container:")
	log("   pct exec %s -- touch %s/test && pct exec %s -- rm %s/test", cfg.lxcID, cfg.lxcMountPath, cfg.lxcID, cfg.lxcMountPath)
	log("")
	log("NFS cache is ready for GitLab Runner configuration!")

	return nil
}

func log(format string, args ...interface{}) {
	fmt.Printf("%s[+]%s %s\n", green, nc, fmt.Sprintf(format, args...))
}

func warn(format string, args ...interface{}) {
	fmt.Printf("%s[!]%s %s\n", yellow, nc, fmt.Sprintf(format, args...))
}

func installNFSClient() error {
	log("[1/6] Checking NFS client...")
	if _, err := exec.LookPath("mount.nfs"); err == nil {
		log("NFS client already installed")
		return nil
	}

	log("Installing NFS client...")
	cmd := exec.Command("apt-get", "update")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("apt-get update: %w\n%s", err, output)
	}

	cmd = exec.Command("apt-get", "install", "-y", "nfs-common")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("apt-get install nfs-common: %w\n%s", err, output)
	}
	log("NFS client installed")
	return nil
}

func createMountPoint(mountPoint string) error {
	log("[2/6] Creating mount point %s...", mountPoint)
	if err := os.MkdirAll(mountPoint, 0755); err != nil {
		return fmt.Errorf("create directory: %w", err)
	}
	log("Mount point created")
	return nil
}

func testNFSConnectivity(cfg config) error {
	log("[3/6] Testing NFS connectivity to %s...", cfg.nfsServer)

	// Check server reachability
	cmd := exec.Command("ping", "-c", "1", "-W", "2", cfg.nfsServer)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("cannot reach NFS server %s\nPlease ensure:\n  1. Synology NAS is online\n  2. Network connectivity exists", cfg.nfsServer)
	}

	// Check NFS exports
	cmd = exec.Command("showmount", "-e", cfg.nfsServer)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("cannot query NFS exports from %s: %w", cfg.nfsServer, err)
	}

	log("NFS exports on %s:", cfg.nfsServer)
	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.Contains(line, "gitlab-runner") || strings.HasPrefix(line, "Export") {
			fmt.Printf("  %s\n", line)
		}
	}

	return nil
}

func mountNFSShare(cfg config) error {
	log("[4/6] Mounting NFS share...")

	// Check if already mounted
	cmd := exec.Command("mount")
	output, _ := cmd.Output()
	if strings.Contains(string(output), cfg.mountPoint) {
		log("Mount point already mounted, unmounting first...")
		cmd = exec.Command("umount", cfg.mountPoint)
		cmd.Run() // Ignore error
	}

	// Mount NFS
	cmd = exec.Command("mount", "-t", "nfs",
		"-o", "nfsvers=4.1,hard,noatime,rsize=1048576,wsize=1048576,timeo=600",
		cfg.nfsServer+":"+cfg.nfsShare,
		cfg.mountPoint)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("mount failed: %w\n%s", err, output)
	}

	log("Mount successful:")
	cmd = exec.Command("df", "-h", cfg.mountPoint)
	output, _ = cmd.CombinedOutput()
	fmt.Println(string(output))

	return nil
}

func testWriteAccess(cfg config) error {
	log("[5/6] Testing write access...")
	testFile := fmt.Sprintf("%s/.proxmox-mount-test-%d", cfg.mountPoint, time.Now().Unix())

	f, err := os.Create(testFile)
	if err != nil {
		return fmt.Errorf("cannot write to NFS share: %w", err)
	}
	f.Close()
	os.Remove(testFile)
	log("Write test successful")
	return nil
}

func addToFstab(cfg config) error {
	log("[6/6] Adding to /etc/fstab...")

	// Read current fstab
	content, err := os.ReadFile("/etc/fstab")
	if err != nil {
		return fmt.Errorf("read fstab: %w", err)
	}

	// Check if entry already exists
	if strings.Contains(string(content), cfg.mountPoint) {
		log("Mount point already in fstab, updating...")
		lines := strings.Split(string(content), "\n")
		for i, line := range lines {
			if strings.Contains(line, cfg.mountPoint) {
				lines[i] = cfg.fstabEntry
				break
			}
		}
		content = []byte(strings.Join(lines, "\n"))
	} else {
		log("Adding to fstab")
		content = append(content, []byte(cfg.fstabEntry+"\n")...)
	}

	// Write back
	if err := os.WriteFile("/etc/fstab", content, 0644); err != nil {
		return fmt.Errorf("write fstab: %w", err)
	}

	// Reload systemd
	log("Reloading systemd daemon...")
	cmd := exec.Command("systemctl", "daemon-reload")
	cmd.Run()
	cmd = exec.Command("systemctl", "restart", "remote-fs.target")
	cmd.Run()

	return nil
}

func updateLXCConfig(cfg config) error {
	log("")
	log("=== Updating LXC %s configuration ===", cfg.lxcID)
	log("Adding mount point to LXC config...")

	lxcConf := "/etc/pve/lxc/" + cfg.lxcID + ".conf"
	mountConfig := fmt.Sprintf("mp0: %s,mp=%s", cfg.mountPoint, cfg.lxcMountPath)

	// Check if LXC config exists
	if _, err := os.Stat(lxcConf); err != nil {
		log("LXC config file not found at %s", lxcConf)
		log("This will be managed by Terraform. Skipping manual config.")
		return nil
	}

	// Read config
	content, err := os.ReadFile(lxcConf)
	if err != nil {
		return fmt.Errorf("read LXC config: %w", err)
	}

	// Check if mount point already exists
	if strings.Contains(string(content), "mp0:") {
		log("Mount point mp0 already exists in LXC config")
		log("Current config:")
		for _, line := range strings.Split(string(content), "\n") {
			if strings.HasPrefix(line, "mp0:") {
				fmt.Println("  " + line)
			}
		}

		fmt.Print("Update to new mount point? (y/N): ")
		reader := bufio.NewReader(os.Stdin)
		response, _ := reader.ReadString('\n')
		if strings.ToLower(strings.TrimSpace(response)) == "y" {
			lines := strings.Split(string(content), "\n")
			for i, line := range lines {
				if strings.HasPrefix(line, "mp0:") {
					lines[i] = mountConfig
					break
				}
			}
			content = []byte(strings.Join(lines, "\n"))
			if err := os.WriteFile(lxcConf, content, 0644); err != nil {
				return fmt.Errorf("write LXC config: %w", err)
			}
			log("Updated mount point")
		}
	} else {
		// Add new mount point
		content = append(content, []byte(mountConfig+"\n")...)
		if err := os.WriteFile(lxcConf, content, 0644); err != nil {
			return fmt.Errorf("write LXC config: %w", err)
		}
		log("Added mount point to LXC config")
	}

	log("")
	log("LXC config updated:")
	for _, line := range strings.Split(string(content), "\n") {
		if strings.HasPrefix(line, "mp") {
			fmt.Println("  " + line)
		}
	}

	return nil
}
