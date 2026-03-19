package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type config struct {
	branch       string
	githubOwner  string
	githubRepo   string
	githubToken  string
	pollInterval time.Duration
	repoDir      string
	repoURL      string
	stateDir     string
	workflowFile string
	once         bool
}

type target struct {
	Name          string `json:"name"`
	Dir           string `json:"dir"`
	ApplyWorkflow string `json:"apply_workflow"`
	Reason        string `json:"reason"`
}

type resolveResult struct {
	Mode         string   `json:"mode"`
	ChangedPaths []string `json:"changed_paths,omitempty"`
	AutoApply    []target `json:"auto_apply"`
	ReportOnly   []target `json:"report_only"`
}

type targetDefinition struct {
	Name          string
	Dir           string
	ApplyWorkflow string
	Prefixes      []string
	AutoApply     bool
}

type dispatchRecord struct {
	Commit       string    `json:"commit"`
	ChangedPaths []string  `json:"changed_paths,omitempty"`
	Dispatched   []string  `json:"dispatched,omitempty"`
	ReportOnly   []string  `json:"report_only,omitempty"`
	DispatchedAt time.Time `json:"dispatched_at"`
}

type workflowRun struct {
	ID         int64     `json:"id"`
	HTMLURL    string    `json:"html_url"`
	Status     string    `json:"status"`
	Conclusion string    `json:"conclusion"`
	HeadSHA    string    `json:"head_sha"`
	CreatedAt  time.Time `json:"created_at"`
}

type workflowRunsResponse struct {
	WorkflowRuns []workflowRun `json:"workflow_runs"`
}

var controllerCatalog = []targetDefinition{
	{
		Name:          "traefik",
		Dir:           "102-traefik/terraform",
		ApplyWorkflow: "traefik-apply.yml",
		Prefixes:      []string{"102-traefik/"},
		AutoApply:     true,
	},
	{
		Name:          "archon",
		Dir:           "108-archon/terraform",
		ApplyWorkflow: "archon-apply.yml",
		Prefixes:      []string{"108-archon/"},
		AutoApply:     true,
	},
	{
		Name:          "github",
		Dir:           "301-github",
		ApplyWorkflow: "github-apply.yml",
		Prefixes:      []string{"301-github/", "modules/shared/onepassword-secrets/"},
		AutoApply:     true,
	},
	{
		Name:          "proxmox",
		Dir:           "100-pve",
		ApplyWorkflow: "terraform-apply.yml",
		Prefixes:      []string{"100-pve/", "modules/"},
		AutoApply:     false,
	},
}

func main() {
	var once bool
	flag.BoolVar(&once, "once", false, "run a single reconcile cycle and exit")
	flag.Parse()

	cfg, err := loadConfig()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	cfg.once = once

	if err := run(cfg); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func loadConfig() (config, error) {
	pollInterval, err := time.ParseDuration(strings.TrimSpace(os.Getenv("GITOPS_POLL_INTERVAL")))
	if err != nil {
		return config{}, fmt.Errorf("parse GITOPS_POLL_INTERVAL: %w", err)
	}

	cfg := config{
		branch:       strings.TrimSpace(os.Getenv("GITOPS_BRANCH")),
		githubOwner:  strings.TrimSpace(os.Getenv("GITOPS_GITHUB_OWNER")),
		githubRepo:   strings.TrimSpace(os.Getenv("GITOPS_GITHUB_REPO")),
		githubToken:  strings.TrimSpace(os.Getenv("GITOPS_GITHUB_TOKEN")),
		pollInterval: pollInterval,
		repoDir:      strings.TrimSpace(os.Getenv("GITOPS_REPO_DIR")),
		repoURL:      strings.TrimSpace(os.Getenv("GITOPS_REPO_URL")),
		stateDir:     strings.TrimSpace(os.Getenv("GITOPS_STATE_DIR")),
		workflowFile: strings.TrimSpace(os.Getenv("GITOPS_GITHUB_WORKFLOW")),
	}

	missing := make([]string, 0)
	for key, value := range map[string]string{
		"GITOPS_BRANCH":          cfg.branch,
		"GITOPS_GITHUB_OWNER":    cfg.githubOwner,
		"GITOPS_GITHUB_REPO":     cfg.githubRepo,
		"GITOPS_GITHUB_TOKEN":    cfg.githubToken,
		"GITOPS_GITHUB_WORKFLOW": cfg.workflowFile,
		"GITOPS_REPO_DIR":        cfg.repoDir,
		"GITOPS_REPO_URL":        cfg.repoURL,
		"GITOPS_STATE_DIR":       cfg.stateDir,
	} {
		if value == "" {
			missing = append(missing, key)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return config{}, fmt.Errorf("missing required env: %s", strings.Join(missing, ", "))
	}

	return cfg, nil
}

func run(cfg config) error {
	if cfg.once {
		return reconcile(cfg)
	}

	for {
		if err := reconcile(cfg); err != nil {
			fmt.Fprintf(os.Stderr, "gitops-agent reconcile failed: %v\n", err)
		}
		time.Sleep(cfg.pollInterval)
	}
}

func reconcile(cfg config) error {
	if err := os.MkdirAll(cfg.stateDir, 0o755); err != nil {
		return fmt.Errorf("create state dir: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(cfg.repoDir), 0o755); err != nil {
		return fmt.Errorf("create repo parent dir: %w", err)
	}

	if err := syncRepo(cfg); err != nil {
		return err
	}

	head, err := gitOutput(cfg.repoDir, "rev-parse", "HEAD")
	if err != nil {
		return fmt.Errorf("read repo HEAD: %w", err)
	}

	lastCommit, err := readOptionalFile(filepath.Join(cfg.stateDir, "last-dispatched-commit"))
	if err != nil {
		return err
	}
	if lastCommit == head {
		fmt.Printf("gitops-agent: no new commit to dispatch (%s)\n", head)
		return nil
	}

	changedPaths, err := changedPaths(cfg.repoDir, lastCommit, head)
	if err != nil {
		return err
	}

	result, err := resolveTargets(changedPaths)
	if err != nil {
		return err
	}

	autoApply := workspaceNames(result.AutoApply)
	reportOnly := workspaceNames(result.ReportOnly)
	if len(autoApply) == 0 {
		fmt.Printf("gitops-agent: report-only or no-op commit %s\n", head)
		return writeState(cfg.stateDir, head, changedPaths, nil, reportOnly)
	}

	run, err := dispatchWorkflow(cfg, head, autoApply)
	if err != nil {
		return err
	}

	fmt.Printf("gitops-agent: workflow run %d succeeded for commit %s\n", run.ID, head)
	return writeState(cfg.stateDir, head, changedPaths, autoApply, reportOnly)
}

func syncRepo(cfg config) error {
	authURL, err := authenticatedRepoURL(cfg.repoURL, cfg.githubToken)
	if err != nil {
		return err
	}

	gitDir := filepath.Join(cfg.repoDir, ".git")
	if _, err := os.Stat(gitDir); errors.Is(err, os.ErrNotExist) {
		if err := runCmd("", nil, "git", "clone", "--branch", cfg.branch, authURL, cfg.repoDir); err != nil {
			return fmt.Errorf("clone repo: %s", redactSecrets(err.Error(), cfg.githubToken, authURL))
		}
		if err := runCmd(cfg.repoDir, nil, "git", "remote", "set-url", "origin", cfg.repoURL); err != nil {
			return fmt.Errorf("reset origin after clone: %w", err)
		}
		return nil
	}
	if err := runCmd(cfg.repoDir, nil, "git", "fetch", authURL, cfg.branch); err != nil {
		return fmt.Errorf("fetch repo: %s", redactSecrets(err.Error(), cfg.githubToken, authURL))
	}
	if err := runCmd(cfg.repoDir, nil, "git", "checkout", "--force", cfg.branch); err != nil {
		return fmt.Errorf("checkout branch: %w", err)
	}
	if err := runCmd(cfg.repoDir, nil, "git", "reset", "--hard", "FETCH_HEAD"); err != nil {
		return fmt.Errorf("reset branch: %w", err)
	}
	if err := runCmd(cfg.repoDir, nil, "git", "clean", "-fd"); err != nil {
		return fmt.Errorf("clean repo: %w", err)
	}
	return nil
}

func changedPaths(repoDir, oldCommit, newCommit string) ([]string, error) {
	if oldCommit == "" {
		return nil, nil
	}
	if oldCommit == newCommit {
		return nil, nil
	}
	output, err := gitOutput(repoDir, "diff", "--name-only", oldCommit, newCommit)
	if err != nil {
		return nil, fmt.Errorf("diff changed paths: %w", err)
	}
	if output == "" {
		return nil, nil
	}
	lines := strings.Split(output, "\n")
	paths := make([]string, 0, len(lines))
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" {
			paths = append(paths, line)
		}
	}
	return paths, nil
}

func resolveTargets(changedPaths []string) (resolveResult, error) {
	result := resolveResult{
		Mode:         "reconcile",
		ChangedPaths: changedPaths,
		AutoApply:    []target{},
		ReportOnly:   []target{},
	}

	if len(changedPaths) == 0 {
		for _, definition := range controllerCatalog {
			if definition.AutoApply {
				appendResolvedTarget(&result, definition, "included in scheduled reconcile allowlist")
			}
		}
		return result, nil
	}

	for _, changedPath := range changedPaths {
		for _, definition := range controllerCatalog {
			if !matchesPrefix(changedPath, definition.Prefixes) {
				continue
			}
			appendResolvedTarget(&result, definition, fmt.Sprintf("matched changed path %q", changedPath))
		}
	}

	return result, nil
}

func dispatchWorkflow(cfg config, commit string, workspaces []string) (workflowRun, error) {
	dispatchedAt := time.Now().UTC()
	bodyBytes, err := json.Marshal(map[string]any{
		"ref": cfg.branch,
		"inputs": map[string]string{
			"mode":          "reconcile",
			"source_commit": commit,
			"workspaces":    strings.Join(workspaces, ","),
		},
	})
	if err != nil {
		return workflowRun{}, fmt.Errorf("marshal workflow dispatch request: %w", err)
	}

	endpoint := fmt.Sprintf(
		"https://api.github.com/repos/%s/%s/actions/workflows/%s/dispatches",
		cfg.githubOwner,
		cfg.githubRepo,
		cfg.workflowFile,
	)
	req, err := newGitHubRequest(cfg, http.MethodPost, endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return workflowRun{}, fmt.Errorf("create workflow dispatch request: %w", err)
	}

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return workflowRun{}, fmt.Errorf("dispatch workflow: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return workflowRun{}, fmt.Errorf("dispatch workflow status %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	run, err := waitForWorkflowRun(cfg, commit, dispatchedAt)
	if err != nil {
		return workflowRun{}, err
	}
	return waitForWorkflowConclusion(cfg, run)
}

func waitForWorkflowRun(cfg config, commit string, dispatchedAt time.Time) (workflowRun, error) {
	for attempt := 0; attempt < 24; attempt++ {
		runs, err := listWorkflowRuns(cfg)
		if err != nil {
			return workflowRun{}, err
		}
		for _, run := range runs {
			if run.HeadSHA != commit {
				continue
			}
			if run.CreatedAt.Before(dispatchedAt.Add(-10 * time.Second)) {
				continue
			}
			return run, nil
		}
		time.Sleep(5 * time.Second)
	}

	return workflowRun{}, fmt.Errorf("timed out waiting for workflow run for commit %s", commit)
}

func waitForWorkflowConclusion(cfg config, run workflowRun) (workflowRun, error) {
	for attempt := 0; attempt < 120; attempt++ {
		current, err := getWorkflowRun(cfg, run.ID)
		if err != nil {
			return workflowRun{}, err
		}
		if current.Status == "completed" {
			if current.Conclusion != "success" {
				return workflowRun{}, fmt.Errorf("workflow run %d failed with conclusion %s: %s", current.ID, current.Conclusion, current.HTMLURL)
			}
			return current, nil
		}
		time.Sleep(10 * time.Second)
	}

	return workflowRun{}, fmt.Errorf("timed out waiting for workflow run %d to complete", run.ID)
}

func listWorkflowRuns(cfg config) ([]workflowRun, error) {
	endpoint := fmt.Sprintf(
		"https://api.github.com/repos/%s/%s/actions/workflows/%s/runs?branch=%s&event=workflow_dispatch&per_page=20",
		cfg.githubOwner,
		cfg.githubRepo,
		url.PathEscape(cfg.workflowFile),
		url.QueryEscape(cfg.branch),
	)
	req, err := newGitHubRequest(cfg, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}

	var runs workflowRunsResponse
	if err := doGitHubJSON(req, &runs); err != nil {
		return nil, fmt.Errorf("list workflow runs: %w", err)
	}
	return runs.WorkflowRuns, nil
}

func getWorkflowRun(cfg config, runID int64) (workflowRun, error) {
	endpoint := fmt.Sprintf(
		"https://api.github.com/repos/%s/%s/actions/runs/%d",
		cfg.githubOwner,
		cfg.githubRepo,
		runID,
	)
	req, err := newGitHubRequest(cfg, http.MethodGet, endpoint, nil)
	if err != nil {
		return workflowRun{}, err
	}

	var run workflowRun
	if err := doGitHubJSON(req, &run); err != nil {
		return workflowRun{}, fmt.Errorf("get workflow run %d: %w", runID, err)
	}
	return run, nil
}

func newGitHubRequest(cfg config, method, endpoint string, body io.Reader) (*http.Request, error) {
	req, err := http.NewRequest(method, endpoint, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("Authorization", "Bearer "+cfg.githubToken)
	req.Header.Set("User-Agent", "gitops-agent/1.0")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	return req, nil
}

func doGitHubJSON(req *http.Request, out any) error {
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("status %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

func writeState(stateDir, commit string, changedPaths, dispatched, reportOnly []string) error {
	if err := os.WriteFile(filepath.Join(stateDir, "last-dispatched-commit"), []byte(commit), 0o600); err != nil {
		return fmt.Errorf("write last commit state: %w", err)
	}
	record := dispatchRecord{
		Commit:       commit,
		ChangedPaths: changedPaths,
		Dispatched:   dispatched,
		ReportOnly:   reportOnly,
		DispatchedAt: time.Now().UTC(),
	}
	body, err := json.MarshalIndent(record, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal dispatch record: %w", err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "last-result.json"), body, 0o600); err != nil {
		return fmt.Errorf("write dispatch record: %w", err)
	}
	return nil
}

func authenticatedRepoURL(repoURL, token string) (string, error) {
	if token == "" {
		return repoURL, nil
	}
	parsed, err := url.Parse(repoURL)
	if err != nil {
		return "", fmt.Errorf("parse repo url: %w", err)
	}
	if parsed.Scheme != "https" {
		return "", fmt.Errorf("repo url must use https for token auth: %s", repoURL)
	}
	parsed.User = url.UserPassword("x-access-token", token)
	return parsed.String(), nil
}

func workspaceNames(targets []target) []string {
	seen := make(map[string]struct{}, len(targets))
	names := make([]string, 0, len(targets))
	for _, target := range targets {
		if _, ok := seen[target.Name]; ok {
			continue
		}
		seen[target.Name] = struct{}{}
		names = append(names, target.Name)
	}
	return names
}

func matchesPrefix(path string, prefixes []string) bool {
	for _, prefix := range prefixes {
		if strings.HasPrefix(path, prefix) {
			return true
		}
	}
	return false
}

func appendResolvedTarget(result *resolveResult, definition targetDefinition, reason string) {
	if definition.AutoApply {
		if containsTarget(result.AutoApply, definition.Name) {
			return
		}
		result.AutoApply = append(result.AutoApply, target{
			Name:          definition.Name,
			Dir:           definition.Dir,
			ApplyWorkflow: definition.ApplyWorkflow,
			Reason:        reason,
		})
		return
	}

	if containsTarget(result.ReportOnly, definition.Name) {
		return
	}
	result.ReportOnly = append(result.ReportOnly, target{
		Name:          definition.Name,
		Dir:           definition.Dir,
		ApplyWorkflow: definition.ApplyWorkflow,
		Reason:        reason,
	})
}

func containsTarget(targets []target, name string) bool {
	for _, target := range targets {
		if target.Name == name {
			return true
		}
	}
	return false
}

func readOptionalFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("read state file %s: %w", path, err)
	}
	return strings.TrimSpace(string(data)), nil
}

func gitOutput(dir string, args ...string) (string, error) {
	return cmdOutput(dir, nil, "git", args...)
}

func cmdOutput(dir string, env []string, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	if env != nil {
		cmd.Env = env
	}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s %s: %w: %s", name, strings.Join(args, " "), err, strings.TrimSpace(string(output)))
	}
	return strings.TrimSpace(string(output)), nil
}

func runCmd(dir string, env []string, name string, args ...string) error {
	_, err := cmdOutput(dir, env, name, args...)
	return err
}

func redactSecrets(text string, secrets ...string) string {
	masked := text
	for _, secret := range secrets {
		if secret == "" {
			continue
		}
		masked = strings.ReplaceAll(masked, secret, "***")
	}
	return masked
}
