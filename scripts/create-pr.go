package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

type options struct {
	jsonOutput bool
	dryRun     bool
}

type result struct {
	Status       string `json:"status"`
	PRURL        string `json:"pr_url"`
	Branch       string `json:"branch"`
	Base         string `json:"base"`
	Title        string `json:"title"`
	FilesChanged int    `json:"files_changed"`
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}

func run() (retErr error) {
	repoRoot, err := repoRootFromScript()
	if err != nil {
		return errf("failed to resolve repository root: %v", err)
	}
	if err := os.Chdir(repoRoot); err != nil {
		return errf("failed to change directory to repository root: %v", err)
	}

	origBranch, _ := gitOutput("rev-parse", "--abbrev-ref", "HEAD")
	defer func() {
		if retErr == nil {
			return
		}
		if strings.TrimSpace(origBranch) == "" {
			return
		}
		_ = gitRunQuiet("checkout", strings.TrimSpace(origBranch))
	}()

	fs := flag.NewFlagSet("create-pr.go", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	opt := options{}
	fs.BoolVar(&opt.jsonOutput, "json", false, "Output result as JSON (for agent consumption)")
	fs.BoolVar(&opt.dryRun, "dry-run", false, "Show what would be done without executing")
	if err := fs.Parse(os.Args[1:]); err != nil {
		return errf("Unknown flag or invalid arguments")
	}

	args := fs.Args()
	if len(args) < 2 {
		return errf("Usage: create-pr.go [--json] [--dry-run] <branch-name> <commit-message> [pr-title] [pr-body]")
	}
	branch := args[0]
	commitMsg := args[1]
	prTitle := commitMsg
	if len(args) >= 3 {
		prTitle = args[2]
	}
	prBody := "Auto-generated PR from opencode session."
	if len(args) >= 4 {
		prBody = args[3]
	}

	log := func(msg string) {
		if !opt.jsonOutput {
			fmt.Println(msg)
		}
	}

	if _, err := exec.LookPath("gh"); err != nil {
		return errf("gh CLI not found")
	}
	if _, err := exec.LookPath("git"); err != nil {
		return errf("git not found")
	}
	if err := ghAuthStatus(); err != nil {
		return errf("gh not authenticated. Run 'gh auth login'")
	}

	cleanWorktree, err := hasNoChanges()
	if err != nil {
		return err
	}
	if cleanWorktree {
		return errf("No changes to commit")
	}

	baseBranch, err := gitOutput("rev-parse", "--abbrev-ref", "HEAD")
	if err != nil {
		return err
	}
	baseBranch = strings.TrimSpace(baseBranch)

	changedFiles, err := countLinesFromOutput("git", "status", "--porcelain")
	if err != nil {
		return err
	}

	if opt.dryRun {
		fmt.Println("=== DRY RUN ===")
		fmt.Printf("Base branch : %s\n", baseBranch)
		fmt.Printf("New branch  : %s\n", branch)
		fmt.Printf("Commit msg  : %s\n", commitMsg)
		fmt.Printf("PR title    : %s\n", prTitle)
		fmt.Printf("Files       : %d changed\n", changedFiles)
		fmt.Println()
		fmt.Println("Would execute:")
		fmt.Printf("  1. git checkout -b %s\n", branch)
		fmt.Printf("  2. git add -A && git commit -m '%s'\n", commitMsg)
		fmt.Printf("  3. git push -u origin %s\n", branch)
		fmt.Printf("  4. gh pr create --base %s --head %s\n", baseBranch, branch)
		fmt.Printf("  5. git checkout %s\n", baseBranch)
		return nil
	}

	log(fmt.Sprintf("Base branch: %s (%d files changed)", baseBranch, changedFiles))

	log(fmt.Sprintf("Creating branch: %s", branch))
	if branchExists(branch) {
		return errf("Branch '%s' already exists locally. Use a different name.", branch)
	}
	if err := gitRun("checkout", "-b", branch); err != nil {
		return err
	}

	if err := gitRun("add", "-A"); err != nil {
		return err
	}
	stagedCount, err := countLinesFromOutput("git", "diff", "--cached", "--numstat")
	if err != nil {
		return err
	}
	log(fmt.Sprintf("Staged %d files", stagedCount))
	if err := gitRun("commit", "-m", commitMsg); err != nil {
		return err
	}
	log(fmt.Sprintf("Committed: %s", commitMsg))

	log(fmt.Sprintf("Pushing to origin/%s...", branch))
	if err := gitRunQuiet("push", "-u", "origin", branch); err != nil {
		_ = gitRunQuiet("checkout", baseBranch)
		return errf("Push failed. Returned to %s.", baseBranch)
	}

	log("Creating PR...")
	prURL, err := ghOutput("pr", "create", "--base", baseBranch, "--head", branch, "--title", prTitle, "--body", prBody)
	if err != nil {
		_ = gitRunQuiet("checkout", baseBranch)
		return errf("PR creation failed. Branch '%s' was pushed. Create PR manually: gh pr create --base %s --head %s", branch, baseBranch, branch)
	}
	prURL = strings.TrimSpace(prURL)

	if err := gitRun("checkout", baseBranch); err != nil {
		return err
	}

	if opt.jsonOutput {
		out, err := json.Marshal(result{
			Status:       "success",
			PRURL:        prURL,
			Branch:       branch,
			Base:         baseBranch,
			Title:        prTitle,
			FilesChanged: stagedCount,
		})
		if err != nil {
			return errf("failed to encode JSON output: %v", err)
		}
		fmt.Println(string(out))
		return nil
	}

	fmt.Println()
	fmt.Println("===============================")
	fmt.Println("PR created successfully!")
	fmt.Printf("URL: %s\n", prURL)
	fmt.Printf("Branch: %s -> %s\n", branch, baseBranch)
	fmt.Printf("Files: %d changed\n", stagedCount)
	fmt.Println("===============================")

	return nil
}

func repoRootFromScript() (string, error) {
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		return "", errors.New("runtime.Caller failed")
	}
	return filepath.Clean(filepath.Join(filepath.Dir(file), "..")), nil
}

func errf(format string, args ...any) error {
	return fmt.Errorf("ERROR: "+format, args...)
}

func hasNoChanges() (bool, error) {
	quietUnstaged := cmdExitZero("git", "diff", "--quiet")
	quietStaged := cmdExitZero("git", "diff", "--cached", "--quiet")
	untracked, err := gitOutput("ls-files", "--others", "--exclude-standard")
	if err != nil {
		return false, err
	}
	return quietUnstaged && quietStaged && strings.TrimSpace(untracked) == "", nil
}

func branchExists(branch string) bool {
	return cmdExitZero("git", "show-ref", "--verify", "--quiet", "refs/heads/"+branch)
}

func cmdExitZero(name string, args ...string) bool {
	cmd := exec.Command(name, args...)
	cmd.Stdout = nil
	cmd.Stderr = nil
	err := cmd.Run()
	return err == nil
}

func countLinesFromOutput(name string, args ...string) (int, error) {
	out, err := output(name, args...)
	if err != nil {
		return 0, err
	}
	trimmed := strings.TrimSpace(out)
	if trimmed == "" {
		return 0, nil
	}
	return len(strings.Split(trimmed, "\n")), nil
}

func gitRun(args ...string) error {
	cmd := exec.Command("git", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return errf("git %s failed", strings.Join(args, " "))
	}
	return nil
}

func gitRunQuiet(args ...string) error {
	cmd := exec.Command("git", args...)
	if err := cmd.Run(); err != nil {
		return errf("git %s failed", strings.Join(args, " "))
	}
	return nil
}

func gitOutput(args ...string) (string, error) {
	return output("git", args...)
}

func ghOutput(args ...string) (string, error) {
	return output("gh", args...)
}

func ghAuthStatus() error {
	cmd := exec.Command("gh", "auth", "status")
	if err := cmd.Run(); err != nil {
		return errf("gh auth status failed")
	}
	return nil
}

func output(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		errMsg := strings.TrimSpace(stderr.String())
		if errMsg == "" {
			errMsg = err.Error()
		}
		return "", errf("%s %s failed: %s", name, strings.Join(args, " "), errMsg)
	}
	return stdout.String(), nil
}
