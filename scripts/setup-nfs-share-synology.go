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
	shareName     string
	sharePath     string
	clientNetwork string
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "%s[-]%s %v\n", red, nc, err)
		os.Exit(1)
	}
}

func run() error {
	cfg := config{
		shareName:     "gitlab-runner-cache",
		sharePath:     "/volume1/gitlab-runner-cache",
		clientNetwork: "192.168.50.0/24",
	}

	log("=== Creating GitLab Runner Cache NFS Share on Synology ===")
	log("Share Name: %s", cfg.shareName)
	log("Share Path: %s", cfg.sharePath)
	log("Client Network: %s", cfg.clientNetwork)
	log("")

	// Check if running on Synology
	if err := checkSynology(); err != nil {
		return err
	}

	// Step 1: Create shared folder
	if err := createSharedFolder(cfg); err != nil {
		return fmt.Errorf("create shared folder: %w", err)
	}

	// Step 2: Enable NFS protocol
	if err := enableNFS(cfg); err != nil {
		return fmt.Errorf("enable NFS: %w", err)
	}

	// Step 3: Set NFS permissions
	if err := setNFSPermissions(cfg); err != nil {
		return fmt.Errorf("set NFS permissions: %w", err)
	}

	// Step 4: Verify NFS export
	if err := verifyNFSExport(cfg); err != nil {
		return fmt.Errorf("verify NFS export: %w", err)
	}

	// Step 5: Test write access
	if err := testWriteAccess(cfg); err != nil {
		return fmt.Errorf("test write access: %w", err)
	}

	log("")
	log("=== Setup Complete ===")
	log("")
	log("NFS Export: %s", cfg.sharePath)
	log("Client Access: %s (Read/Write)", cfg.clientNetwork)
	log("")
	log("To mount from Proxmox:")
	log("  mount -t nfs 192.168.50.215:%s /mnt/gitlab-runner-cache", cfg.sharePath)
	log("")
	log("To verify from another host:")
	log("  showmount -e 192.168.50.215")

	return nil
}

func log(format string, args ...interface{}) {
	fmt.Printf("%s[+]%s %s\n", green, nc, fmt.Sprintf(format, args...))
}

func warn(format string, args ...interface{}) {
	fmt.Printf("%s[!]%s %s\n", yellow, nc, fmt.Sprintf(format, args...))
}

func checkSynology() error {
	log("[1/5] Checking if running on Synology...")
	if _, err := exec.LookPath("synoshare"); err != nil {
		return fmt.Errorf("this script must run on Synology NAS\nPlease SSH to 192.168.50.215 and run this script as admin")
	}
	log("Running on Synology")
	return nil
}

func createSharedFolder(cfg config) error {
	log("[1/5] Creating shared folder...")

	// Check if shared folder already exists
	cmd := exec.Command("synoshare", "--enum")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("check existing shares: %w", err)
	}

	sharePrefix := cfg.shareName + "\t"
	if strings.Contains(string(output), sharePrefix) {
		log("Shared folder '%s' already exists", cfg.shareName)
		return nil
	}

	log("Creating shared folder: %s", cfg.shareName)
	cmd = exec.Command("synoshare", "--add", cfg.shareName, "GitLab Runner Cache", cfg.sharePath)
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("create shared folder: %w\nOutput: %s", err, string(output))
	}
	log("Shared folder created successfully")
	return nil
}

func enableNFS(cfg config) error {
	log("[2/5] Enabling NFS protocol...")
	cmd := exec.Command("synoshare", "--setnfs", cfg.shareName, "enable")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("enable NFS: %w\nOutput: %s", err, string(output))
	}
	log("NFS enabled for share")
	return nil
}

func setNFSPermissions(cfg config) error {
	log("[3/5] Setting NFS permissions...")

	// Check if rule already exists
	cmd := exec.Command("synonfsext", "--list-rules", cfg.shareName)
	output, err := cmd.Output()
	if err == nil && strings.Contains(string(output), cfg.clientNetwork) {
		log("NFS rule for %s already exists", cfg.clientNetwork)
		return nil
	}

	log("Adding NFS rule: %s (RW)", cfg.clientNetwork)
	cmd = exec.Command("synonfsext", "--add-rule", cfg.shareName, cfg.clientNetwork, "rw")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("add NFS rule: %w\nOutput: %s", err, string(output))
	}
	log("NFS rule added")
	return nil
}

func verifyNFSExport(cfg config) error {
	log("[4/5] Verifying NFS export...")
	log("NFS exports on this server:")

	cmd := exec.Command("showmount", "-e", "localhost")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("showmount failed: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		if strings.Contains(line, cfg.shareName) || strings.HasPrefix(line, "Export") {
			fmt.Printf("  %s\n", line)
		}
	}

	return nil
}

func testWriteAccess(cfg config) error {
	log("[5/5] Testing write access...")
	testFile := fmt.Sprintf("%s/.nfs-setup-test-%d", cfg.sharePath, time.Now().Unix())

	// Try to create test file
	f, err := os.Create(testFile)
	if err != nil {
		warn("Write test failed - checking permissions...")
		cmd := exec.Command("ls", "-la", cfg.sharePath)
		output, _ := cmd.Output()
		fmt.Println(string(output))
		return fmt.Errorf("cannot write to share: %w", err)
	}
	f.Close()
	os.Remove(testFile)
	log("Write test successful")
	return nil
}

// confirm prompts user for confirmation
func confirm(prompt string) bool {
	fmt.Printf("%s (y/N): ", prompt)
	reader := bufio.NewReader(os.Stdin)
	response, _ := reader.ReadString('\n')
	response = strings.ToLower(strings.TrimSpace(response))
	return response == "y" || response == "yes"
}
