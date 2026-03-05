package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

func main() {
	// Get script/binary directory
	execPath, err := os.Executable()
	if err != nil {
		execPath, err = os.Getwd()
		if err != nil {
			fmt.Fprintln(os.Stderr, "ERROR: Could not determine script location")
			os.Exit(1)
		}
	}
	scriptDir := filepath.Dir(execPath)
	repoRoot := filepath.Dir(scriptDir)

	tfDir := filepath.Join(repoRoot, "100-pve", "envs", "prod")
	backupDir := filepath.Join(repoRoot, ".backups")
	timestamp := time.Now().Format("20060102_150405")
	backupFile := filepath.Join(backupDir, fmt.Sprintf("tfstate_%s.enc", timestamp))

	// Cleanup on failure
	cleanupNeeded := true
	defer func() {
		if cleanupNeeded {
			os.Remove(backupFile)
		}
	}()

	// Ensure backup directory exists
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Failed to create backup directory: %v\n", err)
		os.Exit(1)
	}

	// Add .backups to .gitignore if not already present
	gitignorePath := filepath.Join(repoRoot, ".gitignore")
	gitignoreContent, err := os.ReadFile(gitignorePath)
	if err != nil && !os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "ERROR: Could not read .gitignore: %v\n", err)
		os.Exit(1)
	}
	if os.IsNotExist(err) || !strings.Contains(string(gitignoreContent), ".backups/") {
		f, err := os.OpenFile(gitignorePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: Could not update .gitignore: %v\n", err)
			os.Exit(1)
		}
		f.WriteString(".backups/\n")
		f.Close()
	}

	// Validate state file exists
	stateFile := filepath.Join(tfDir, "terraform.tfstate")
	if _, err := os.Stat(stateFile); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "ERROR: State file not found at %s\n", stateFile)
		os.Exit(1)
	}

	// Check for encryption passphrase
	passphrase := os.Getenv("TF_BACKUP_PASSPHRASE")
	if passphrase == "" {
		fmt.Fprintln(os.Stderr, "ERROR: TF_BACKUP_PASSPHRASE environment variable is not set")
		fmt.Fprintln(os.Stderr, "  Set it via: export TF_BACKUP_PASSPHRASE='your-secure-passphrase'")
		fmt.Fprintln(os.Stderr, "  Or use 1Password: export TF_BACKUP_PASSPHRASE=$(op read 'op://homelab/terraform/secrets/backup_passphrase')")
		os.Exit(1)
	}

	// Create encrypted backup
	fmt.Println("Creating encrypted backup of terraform.tfstate...")

	// Set the passphrase in environment for openssl
	cmd := exec.Command("openssl", "enc", "-aes-256-cbc", "-salt", "-pbkdf2", "-iter", "100000",
		"-in", stateFile,
		"-out", backupFile,
		"-pass", "env:TF_BACKUP_PASSPHRASE")
	cmd.Env = append(os.Environ(), "TF_BACKUP_PASSPHRASE="+passphrase)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: openssl command failed: %v\n", err)
		os.Exit(1)
	}

	// Verify backup was created
	if _, err := os.Stat(backupFile); os.IsNotExist(err) {
		fmt.Fprintln(os.Stderr, "ERROR: Backup file was not created")
		os.Exit(1)
	}

	info, err := os.Stat(backupFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Could not get backup file size: %v\n", err)
		os.Exit(1)
	}
	size := info.Size()
	fmt.Printf("Backup created: %s (%d bytes)\n", backupFile, size)

	// Prune old backups (keep last 10)
	entries, err := os.ReadDir(backupDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Could not read backup directory: %v\n", err)
		os.Exit(1)
	}

	var backupFiles []os.DirEntry
	for _, e := range entries {
		if !e.IsDir() && strings.HasPrefix(e.Name(), "tfstate_") && strings.HasSuffix(e.Name(), ".enc") {
			backupFiles = append(backupFiles, e)
		}
	}

	if len(backupFiles) > 10 {
		fmt.Println("Pruning old backups (keeping last 10)...")

		// Get file info with modification times
		type fileInfo struct {
			path    string
			modTime time.Time
		}
		var files []fileInfo
		for _, f := range backupFiles {
			info, err := f.Info()
			if err != nil {
				continue
			}
			files = append(files, fileInfo{
				path:    filepath.Join(backupDir, f.Name()),
				modTime: info.ModTime(),
			})
		}

		// Sort by modification time (oldest first)
		sort.Slice(files, func(i, j int) bool {
			return files[i].modTime.Before(files[j].modTime)
		})

		// Delete all but last 10
		toDelete := files[:len(files)-10]
		for _, f := range toDelete {
			os.Remove(f.path)
		}
	}

	fmt.Println("Backup complete.")
	cleanupNeeded = false
}
