package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

const backupsToKeep = 10

var localBackendPattern = regexp.MustCompile(`(?m)^[[:space:]]*backend[[:space:]]+"local"[[:space:]]*\{`)

type workspace struct {
	Name, RelativePath string
}

// Local-backend roots only; 100-pve/terraform keeps its state in the Cloudflare R2 (S3) backend.
var configuredWorkspaces = []workspace{
	{Name: "elk", RelativePath: "105-elk/terraform"},
	{Name: "synology", RelativePath: "215-synology"},
	{Name: "cloudflare", RelativePath: "300-cloudflare/terraform"},
}

type backupOptions struct {
	repoRoot   string
	workspaces []string
	list       bool
}

type commandRunner interface {
	Output(dir, name string, args ...string) ([]byte, error)
	Run(dir, name string, stdin []byte, env []string, args ...string) error
}

type execRunner struct{}

func (execRunner) Output(dir, name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("run %s: %s: %w", name, strings.TrimSpace(stderr.String()), err)
	}
	return output, nil
}

func (execRunner) Run(dir, name string, stdin []byte, env []string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir, cmd.Stdin, cmd.Env = dir, bytes.NewReader(stdin), append(os.Environ(), env...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("run %s: %s: %w", name, strings.TrimSpace(stderr.String()), err)
	}
	return nil
}

type workspaceError struct {
	workspace, operation string
	err                  error
}

func (e *workspaceError) Error() string {
	return fmt.Sprintf("%s: %s failed: %v", e.workspace, e.operation, e.err)
}
func (e *workspaceError) Unwrap() error { return e.err }

func main() {
	cwd, err := os.Getwd()
	if err == nil {
		err = runBackup(os.Args[1:], cwd, os.Getenv, os.Stdout, os.Stderr, execRunner{}, time.Now)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func runBackup(args []string, cwd string, getenv func(string) string, stdout, stderr io.Writer, runner commandRunner, now func() time.Time) error {
	parsed, err := parseOptions(args, stdout)
	if errors.Is(err, flag.ErrHelp) {
		return nil
	}
	if err != nil {
		return err
	}
	items, err := selectWorkspaces(parsed.workspaces)
	if err != nil {
		return err
	}
	if parsed.list {
		for _, item := range items {
			if _, err := fmt.Fprintf(stdout, "%s\t%s\n", item.Name, item.RelativePath); err != nil {
				return fmt.Errorf("write workspace list: %w", err)
			}
		}
		return nil
	}
	passphrase := getenv("TF_BACKUP_PASSPHRASE")
	if passphrase == "" {
		return errors.New("TF_BACKUP_PASSPHRASE is required when creating backups")
	}
	repoRoot, err := resolveBackupRepoRoot(cwd, parsed.repoRoot)
	if err != nil {
		return err
	}
	backupDir, failures := filepath.Join(repoRoot, ".backups"), make([]error, 0)
	for _, item := range items {
		if err := verifyLocalBackend(repoRoot, item); err != nil {
			failures = append(failures, &workspaceError{workspace: item.Name, operation: "backend verification", err: err})
			continue
		}
		artifact, err := backupWorkspace(repoRoot, backupDir, item, passphrase, runner, now())
		if err != nil {
			failures = append(failures, &workspaceError{workspace: item.Name, operation: "backup", err: err})
			continue
		}
		info, err := os.Stat(artifact)
		if err != nil {
			failures = append(failures, &workspaceError{workspace: item.Name, operation: "artifact inspection", err: err})
			continue
		}
		if err := pruneBackups(backupDir, item.Name, backupsToKeep); err != nil {
			failures = append(failures, &workspaceError{workspace: item.Name, operation: "prune", err: err})
			continue
		}
		if _, err := fmt.Fprintf(stdout, "%s: saved %s (%d bytes)\n", item.Name, artifact, info.Size()); err != nil {
			return fmt.Errorf("write backup result: %w", err)
		}
	}
	return errors.Join(failures...)
}

func parseOptions(args []string, output io.Writer) (backupOptions, error) {
	flags, parsed := flag.NewFlagSet("backup-tfstate", flag.ContinueOnError), backupOptions{}
	flags.SetOutput(output)
	flags.StringVar(&parsed.repoRoot, "repo-root", "", "repository root")
	flags.BoolVar(&parsed.list, "list", false, "list configured workspaces")
	flags.Func("workspace", "workspace to back up", func(name string) error { parsed.workspaces = append(parsed.workspaces, name); return nil })
	if err := flags.Parse(args); err != nil {
		return backupOptions{}, fmt.Errorf("parse arguments: %w", err)
	}
	if flags.NArg() != 0 {
		return backupOptions{}, errors.New("unexpected positional arguments")
	}
	return parsed, nil
}

func resolveBackupRepoRoot(cwd, explicit string) (string, error) {
	if explicit != "" {
		root, err := filepath.Abs(explicit)
		if err != nil {
			return "", fmt.Errorf("resolve explicit repository root: %w", err)
		}
		return filepath.Clean(root), nil
	}
	root, err := filepath.Abs(cwd)
	if err != nil {
		return "", fmt.Errorf("resolve working directory: %w", err)
	}
	for {
		if _, err := os.Stat(filepath.Join(root, ".git")); err == nil {
			return root, nil
		} else if !os.IsNotExist(err) {
			return "", fmt.Errorf("stat repository marker: %w", err)
		}
		parent := filepath.Dir(root)
		if parent == root {
			return "", errors.New("repository root not found")
		}
		root = parent
	}
}

func selectWorkspaces(names []string) ([]workspace, error) {
	if len(names) == 0 {
		return append([]workspace(nil), configuredWorkspaces...), nil
	}
	selected := make([]workspace, 0, len(names))
	for _, name := range names {
		found := false
		for _, item := range configuredWorkspaces {
			if name == item.Name {
				selected, found = append(selected, item), true
				break
			}
		}
		if !found {
			return nil, errors.New("unknown workspace")
		}
	}
	return selected, nil
}

func verifyLocalBackend(repoRoot string, item workspace) error {
	content, err := os.ReadFile(filepath.Join(repoRoot, item.RelativePath, "versions.tf"))
	if err != nil {
		return fmt.Errorf("read workspace backend declaration: %w", err)
	}
	if !localBackendPattern.Match(content) {
		return errors.New("local backend required")
	}
	return nil
}

func backupWorkspace(repoRoot, backupDir string, item workspace, passphrase string, runner commandRunner, now time.Time) (artifact string, err error) {
	workspaceDir := filepath.Join(repoRoot, item.RelativePath)
	state, err := runner.Output(workspaceDir, "terraform", "state", "pull")
	if err != nil {
		return "", fmt.Errorf("pull state: %w", err)
	}
	if err := os.MkdirAll(backupDir, 0700); err != nil {
		return "", fmt.Errorf("create backup directory: %w", err)
	}
	if err := os.Chmod(backupDir, 0700); err != nil {
		return "", fmt.Errorf("secure backup directory: %w", err)
	}
	path := filepath.Join(backupDir, fmt.Sprintf("%s-tfstate_%s.enc", item.Name, now.Format("20060102_150405")))
	created := false
	defer func() {
		if err != nil && created {
			err = errors.Join(err, os.Remove(path))
			artifact = ""
		}
	}()
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return "", fmt.Errorf("create backup artifact: %w", err)
	}
	created = true
	if err := file.Close(); err != nil {
		return "", fmt.Errorf("close backup artifact: %w", err)
	}
	if err := runner.Run(workspaceDir, "openssl", state, []string{"TF_BACKUP_PASSPHRASE=" + passphrase}, "enc", "-aes-256-cbc", "-salt", "-pbkdf2", "-iter", "100000", "-out", path, "-pass", "env:TF_BACKUP_PASSPHRASE"); err != nil {
		return "", fmt.Errorf("encrypt state: %w", err)
	}
	return path, nil
}

func pruneBackups(backupDir, workspaceName string, keep int) error {
	entries, err := os.ReadDir(backupDir)
	if err != nil {
		return fmt.Errorf("read backup directory: %w", err)
	}
	prefix, artifacts := workspaceName+"-tfstate_", make([]string, 0)
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasPrefix(entry.Name(), prefix) && strings.HasSuffix(entry.Name(), ".enc") {
			artifacts = append(artifacts, entry.Name())
		}
	}
	sort.Strings(artifacts)
	deleteCount := max(0, len(artifacts)-keep)
	for _, name := range artifacts[:deleteCount] {
		if err := os.Remove(filepath.Join(backupDir, name)); err != nil {
			return fmt.Errorf("remove expired backup: %w", err)
		}
	}
	return nil
}
