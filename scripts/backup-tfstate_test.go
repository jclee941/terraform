package main

import (
	"bytes"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type fakeRunner struct {
	outputFn func(string, string, ...string) ([]byte, error)
	runFn    func(string, string, []byte, []string, ...string) error
	outputs  int
	runs     int
}

func (r *fakeRunner) Output(dir, name string, args ...string) ([]byte, error) {
	r.outputs++
	return r.outputFn(dir, name, args...)
}

func (r *fakeRunner) Run(dir, name string, stdin []byte, env []string, args ...string) error {
	r.runs++
	return r.runFn(dir, name, stdin, env, args...)
}

func TestRun_lists_configured_workspaces_without_runner_or_passphrase(t *testing.T) {
	// Given
	runner := &fakeRunner{
		outputFn: func(string, string, ...string) ([]byte, error) { return nil, nil },
		runFn:    func(string, string, []byte, []string, ...string) error { return nil },
	}
	var stdout, stderr bytes.Buffer

	// When
	err := runBackup([]string{"--list"}, "/unused", func(string) string { return "" }, &stdout, &stderr, runner, time.Now)

	// Then
	if err != nil {
		t.Fatalf("run list: %v", err)
	}
	const want = "elk\t105-elk/terraform\nsynology\t215-synology\ncloudflare\t300-cloudflare/terraform\n"
	if stdout.String() != want {
		t.Fatalf("list output = %q, want %q", stdout.String(), want)
	}
	if stderr.Len() != 0 || runner.outputs != 0 || runner.runs != 0 {
		t.Fatalf("list invoked runner or wrote stderr: outputs=%d runs=%d stderr=%q", runner.outputs, runner.runs, stderr.String())
	}
}

func TestRunBackup_prints_help_without_runner_or_passphrase(t *testing.T) {
	// Given
	runner := &fakeRunner{
		outputFn: func(string, string, ...string) ([]byte, error) { return nil, nil },
		runFn:    func(string, string, []byte, []string, ...string) error { return nil },
	}
	var stdout, stderr bytes.Buffer

	// When
	err := runBackup([]string{"--help"}, "/unused", func(string) string { return "" }, &stdout, &stderr, runner, time.Now)

	// Then
	if err != nil {
		t.Fatalf("run help: %v", err)
	}
	if !strings.Contains(stdout.String(), "Usage of backup-tfstate") {
		t.Fatalf("help output = %q", stdout.String())
	}
	if runner.outputs != 0 || runner.runs != 0 {
		t.Fatalf("help invoked runner: outputs=%d runs=%d", runner.outputs, runner.runs)
	}
}

func TestSelectWorkspaces_selects_repeated_flags_and_rejects_unknown_name(t *testing.T) {
	// Given
	names := []string{"cloudflare", "elk"}

	// When
	selected, err := selectWorkspaces(names)

	// Then
	if err != nil {
		t.Fatalf("select workspaces: %v", err)
	}
	if got := selected[0].Name + "," + selected[1].Name; got != "cloudflare,elk" {
		t.Fatalf("selected names = %q", got)
	}
	for _, name := range []string{"unknown", "pve"} {
		_, err = selectWorkspaces([]string{name})
		if err == nil || err.Error() != "unknown workspace" {
			t.Fatalf("%s workspace error = %v", name, err)
		}
	}
}

func TestResolveRepoRoot_resolves_cwd_and_explicit_root(t *testing.T) {
	// Given
	root := fixtureRepo(t)
	nested := filepath.Join(root, "105-elk", "terraform")

	// When
	fromCWD, cwdErr := resolveBackupRepoRoot(nested, "")
	fromFlag, flagErr := resolveBackupRepoRoot(nested, root)

	// Then
	if cwdErr != nil || flagErr != nil {
		t.Fatalf("resolve errors: cwd=%v flag=%v", cwdErr, flagErr)
	}
	if fromCWD != root || fromFlag != root {
		t.Fatalf("resolved roots = %q, %q; want %q", fromCWD, fromFlag, root)
	}
}

func TestVerifyLocalBackend_rejects_workspace_without_local_backend(t *testing.T) {
	// Given
	root := fixtureRepo(t)
	path := filepath.Join(root, "300-cloudflare", "terraform", "versions.tf")
	if err := os.WriteFile(path, []byte("terraform {}\n"), 0600); err != nil {
		t.Fatalf("write versions: %v", err)
	}

	// When
	err := verifyLocalBackend(root, configuredWorkspaces[2])

	// Then
	if err == nil {
		t.Fatalf("verify local backend error = %v", err)
	}
}

func TestVerifyLocalBackend_rejects_commented_local_backend(t *testing.T) {
	// Given
	root := fixtureRepo(t)
	path := filepath.Join(root, "300-cloudflare", "terraform", "versions.tf")
	if err := os.WriteFile(path, []byte("terraform {\n  # backend \"local\" {}\n}\n"), 0600); err != nil {
		t.Fatalf("write versions: %v", err)
	}

	// When
	err := verifyLocalBackend(root, configuredWorkspaces[2])

	// Then
	if err == nil {
		t.Fatal("commented local backend was accepted")
	}
}

func TestConfiguredWorkspaces_declare_local_backend_in_repository(t *testing.T) {
	// Given
	cwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}
	root, err := resolveBackupRepoRoot(cwd, "")
	if err != nil {
		t.Fatalf("resolve repository root: %v", err)
	}

	// When / Then
	for _, item := range configuredWorkspaces {
		if err := verifyLocalBackend(root, item); err != nil {
			t.Errorf("%s (%s): %v", item.Name, item.RelativePath, err)
		}
	}
}

func TestBackupsDirectory_is_ignored_by_git(t *testing.T) {
	// Given
	command := exec.Command("git", "check-ignore", ".backups/probe.enc")

	// When
	err := command.Run()

	// Then
	if err != nil {
		t.Fatalf(".backups must be ignored by git: %v", err)
	}
}

func TestBackupWorkspace_removes_partial_artifact_when_encryption_fails(t *testing.T) {
	// Given
	root := fixtureRepo(t)
	backupDir := filepath.Join(root, ".backups")
	runner := &fakeRunner{
		outputFn: func(string, string, ...string) ([]byte, error) { return []byte("fake-state"), nil },
		runFn:    func(string, string, []byte, []string, ...string) error { return errors.New("openssl failure") },
	}

	// When
	artifact, err := backupWorkspace(root, backupDir, configuredWorkspaces[0], "secret", runner, time.Date(2026, 7, 23, 1, 2, 3, 0, time.UTC))

	// Then
	if err == nil || artifact != "" {
		t.Fatalf("backup result = %q, %v", artifact, err)
	}
	entries, readErr := os.ReadDir(backupDir)
	if readErr != nil {
		t.Fatalf("read backup directory: %v", readErr)
	}
	if len(entries) != 0 {
		t.Fatalf("partial artifact remains: %v", entries)
	}
}

func TestRun_creates_encrypted_artifacts_continues_and_hides_sensitive_values(t *testing.T) {
	// Given
	root := fixtureRepo(t)
	binDir := t.TempDir()
	writeExecutable(t, filepath.Join(binDir, "terraform"), "#!/bin/sh\ncase \"$PWD\" in *\"/105-elk/terraform\") echo 'state pull failed' >&2; exit 7;; esac\nprintf 'FAKE_STATE_CONTENT'\n")
	writeExecutable(t, filepath.Join(binDir, "openssl"), "#!/bin/sh\nwhile [ \"$#\" -gt 0 ]; do\n  if [ \"$1\" = \"-out\" ]; then out=\"$2\"; shift 2; else shift; fi\ndone\ncat > \"$out\"\n")
	t.Setenv("PATH", binDir+string(os.PathListSeparator)+os.Getenv("PATH"))
	var stdout, stderr bytes.Buffer
	const passphrase = "test-passphrase"

	// When
	err := runBackup([]string{"--repo-root", root, "--workspace", "cloudflare", "--workspace", "elk", "--workspace", "synology"}, root, func(string) string { return passphrase }, &stdout, &stderr, execRunner{}, func() time.Time {
		return time.Date(2026, 7, 23, 1, 2, 3, 0, time.UTC)
	})

	// Then
	if err == nil {
		t.Fatal("run succeeded despite failed elk state pull")
	}
	combined := stdout.String() + stderr.String()
	if strings.Contains(combined, "FAKE_STATE_CONTENT") || strings.Contains(combined, passphrase) {
		t.Fatalf("sensitive value was printed: %q", combined)
	}
	if !strings.Contains(stdout.String(), "cloudflare") || !strings.Contains(stdout.String(), "synology") || !strings.Contains(err.Error(), "elk") {
		t.Fatalf("workspace results missing: stdout=%q stderr=%q", stdout.String(), stderr.String())
	}
	if !strings.Contains(err.Error(), "state pull failed") {
		t.Fatalf("root cause missing from error: %v", err)
	}
	backupDir := filepath.Join(root, ".backups")
	assertMode(t, backupDir, 0700)
	for _, name := range []string{"cloudflare", "synology"} {
		matches, globErr := filepath.Glob(filepath.Join(backupDir, name+"-tfstate_*.enc"))
		if globErr != nil || len(matches) != 1 {
			t.Fatalf("%s artifacts = %v, %v", name, matches, globErr)
		}
		assertMode(t, matches[0], 0600)
	}
	failed, globErr := filepath.Glob(filepath.Join(backupDir, "elk-tfstate_*.enc"))
	if globErr != nil || len(failed) != 0 {
		t.Fatalf("failed artifacts = %v, %v", failed, globErr)
	}
}

func TestPruneBackups_keeps_ten_artifacts_per_workspace(t *testing.T) {
	// Given
	backupDir := t.TempDir()
	for _, workspaceName := range []string{"pve", "elk"} {
		for index := 0; index < 11; index++ {
			name := workspaceName + "-tfstate_20260723_01020" + string(rune('0'+index)) + ".enc"
			if err := os.WriteFile(filepath.Join(backupDir, name), []byte("x"), 0600); err != nil {
				t.Fatalf("create artifact: %v", err)
			}
		}
	}

	// When
	err := pruneBackups(backupDir, "pve", 10)

	// Then
	if err != nil {
		t.Fatalf("prune backups: %v", err)
	}
	for workspaceName, want := range map[string]int{"pve": 10, "elk": 11} {
		matches, globErr := filepath.Glob(filepath.Join(backupDir, workspaceName+"-tfstate_*.enc"))
		if globErr != nil || len(matches) != want {
			t.Fatalf("%s artifacts = %v, %v", workspaceName, matches, globErr)
		}
	}
}

func fixtureRepo(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	if err := os.Mkdir(filepath.Join(root, ".git"), 0700); err != nil {
		t.Fatalf("create git directory: %v", err)
	}
	for _, item := range configuredWorkspaces {
		dir := filepath.Join(root, item.RelativePath)
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatalf("create workspace: %v", err)
		}
		if err := os.WriteFile(filepath.Join(dir, "versions.tf"), []byte("terraform {\n  backend \"local\" {}\n}\n"), 0600); err != nil {
			t.Fatalf("write versions: %v", err)
		}
	}
	return root
}

func writeExecutable(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0700); err != nil {
		t.Fatalf("write executable: %v", err)
	}
}

func assertMode(t *testing.T, path string, want os.FileMode) {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat %s: %v", path, err)
	}
	if got := info.Mode().Perm(); got != want {
		t.Fatalf("mode %s = %o, want %o", path, got, want)
	}
}
