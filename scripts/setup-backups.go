package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strconv"
)

const (
	colorBackupsRed    = "\033[0;31m"
	colorBackupsGreen  = "\033[0;32m"
	colorBackupsYellow = "\033[1;33m"
	colorBackupsNC     = "\033[0m"

	storage  = "local"
	compress = "zstd"

	lxcVMIDs    = "102,104,105,106"
	vmVMIDs     = "112"
	lxcSchedule = "0 2 * * *"
	vmSchedule  = "0 3 * * *"
)

func main() {
	fmt.Printf("%s=== Proxmox Backup Job Configuration ===%s\n", colorBackupsYellow, colorBackupsNC)
	fmt.Printf("Storage: %s\n", storage)
	fmt.Printf("Compression: %s\n", compress)
	fmt.Printf("LXC Containers (02:00 UTC): %s\n", lxcVMIDs)
	fmt.Printf("VMs (03:00 UTC): %s\n", vmVMIDs)
	fmt.Println()

	if effectiveUID() != 0 {
		fmt.Fprintf(os.Stderr, "%s[ERROR] This script must be run as root%s\n", colorBackupsRed, colorBackupsNC)
		os.Exit(1)
	}

	if _, err := exec.LookPath("pvesh"); err != nil {
		fmt.Fprintf(os.Stderr, "%s[ERROR] pvesh command not found. Are you on the PVE host?%s\n", colorBackupsRed, colorBackupsNC)
		os.Exit(1)
	}

	fmt.Printf("%s[INFO] Creating LXC container backup job...%s\n", colorBackupsYellow, colorBackupsNC)
	if err := runPveshCreate([]string{
		"--vmid", lxcVMIDs,
		"--schedule", lxcSchedule,
		"--storage", storage,
		"--mode", "snapshot",
		"--compress", compress,
		"--prune-backups", "keep-last=7,keep-weekly=4,keep-monthly=3",
		"--enabled", "1",
		"--notes-template", "{{guestname}}-daily",
		"--mailto", "root",
	}); err != nil {
		fmt.Fprintf(os.Stderr, "%s[ERROR] Failed to create LXC backup job%s\n", colorBackupsRed, colorBackupsNC)
		os.Exit(1)
	}
	fmt.Printf("%s[OK] LXC backup job created%s\n", colorBackupsGreen, colorBackupsNC)

	fmt.Println()
	fmt.Printf("%s[INFO] Creating VM backup job...%s\n", colorBackupsYellow, colorBackupsNC)
	if err := runPveshCreate([]string{
		"--vmid", vmVMIDs,
		"--schedule", vmSchedule,
		"--storage", storage,
		"--mode", "snapshot",
		"--compress", compress,
		"--prune-backups", "keep-last=7,keep-weekly=4,keep-monthly=3",
		"--enabled", "1",
		"--notes-template", "{{guestname}}-daily",
		"--mailto", "root",
	}); err != nil {
		fmt.Fprintf(os.Stderr, "%s[ERROR] Failed to create VM backup job%s\n", colorBackupsRed, colorBackupsNC)
		os.Exit(1)
	}
	fmt.Printf("%s[OK] VM backup job created%s\n", colorBackupsGreen, colorBackupsNC)

	fmt.Println()
	fmt.Printf("%s[SUCCESS] Backup jobs configured successfully%s\n", colorBackupsGreen, colorBackupsNC)
	fmt.Println()
	fmt.Printf("%s=== Current Backup Jobs ===%s\n", colorBackupsYellow, colorBackupsNC)

	if err := printBackupJobs(); err != nil {
		os.Exit(1)
	}

	fmt.Println()
	fmt.Printf("%s=== Next Steps ===%s\n", colorBackupsYellow, colorBackupsNC)
	fmt.Println("1. Monitor backup execution in Proxmox GUI > Datacenter > Backup")
	fmt.Println("2. Check backup logs: grep vzdump /var/log/syslog")
	fmt.Println("3. Verify restoration: docs/backup-strategy.md")
}

func effectiveUID() int {
	if testUID := os.Getenv("TEST_EUID"); testUID != "" {
		if uid, err := strconv.Atoi(testUID); err == nil {
			return uid
		}
	}

	return os.Geteuid()
}

func runPveshCreate(extraArgs []string) error {
	args := append([]string{"create", "/cluster/backup"}, extraArgs...)
	cmd := exec.Command("pvesh", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return err
	}
	return nil
}

func printBackupJobs() error {
	if _, err := exec.LookPath("jq"); err == nil {
		getCmd := exec.Command("pvesh", "get", "/cluster/backup", "--output-format", "json-pretty")
		output, getErr := getCmd.Output()
		if getErr != nil {
			if exitErr, ok := getErr.(*exec.ExitError); ok {
				_, _ = os.Stderr.Write(exitErr.Stderr)
			}
			fmt.Fprintf(os.Stderr, "%s[ERROR] Failed to list backup jobs%s\n", colorBackupsRed, colorBackupsNC)
			return getErr
		}

		jqCmd := exec.Command("jq", ".data")
		jqCmd.Stdin = bytes.NewReader(output)
		jqCmd.Stdout = os.Stdout
		jqCmd.Stderr = os.Stderr
		if jqErr := jqCmd.Run(); jqErr != nil {
			fmt.Fprintf(os.Stderr, "%s[ERROR] Failed to process backup jobs with jq%s\n", colorBackupsRed, colorBackupsNC)
			return jqErr
		}
		return nil
	}

	fallbackCmd := exec.Command("pvesh", "get", "/cluster/backup")
	fallbackCmd.Stdout = os.Stdout
	fallbackCmd.Stderr = os.Stderr
	if err := fallbackCmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "%s[ERROR] Failed to list backup jobs%s\n", colorBackupsRed, colorBackupsNC)
		return err
	}

	return nil
}
