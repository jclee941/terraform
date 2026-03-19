//go:build register_repo
// +build register_repo

package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const (
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	red    = "\033[0;31m"
	nc     = "\033[0m"
)

type config struct {
	githubToken   string
	githubUser    string
	githubAPI     string
	repo          string
	instanceNum   string
	runnerUser    string
	runnerBase    string
	runnerVersion string
	runnerArch    string
	runnerLabels  string
	runnerCount   int
	httpClient    *http.Client
}

func main() {
	if err := run(); err != nil {
		os.Exit(1)
	}
}

func run() error {
	flag.Parse()
	args := flag.Args()
	if len(args) < 1 {
		err("Error: Repository name required. Usage: ./register-repo.sh <repo-name> [instance-number]")
		return fmt.Errorf("repository name required")
	}

	runnerCount, parseErr := parseInt(getenvDefault("RUNNER_COUNT", "2"))
	if parseErr != nil {
		return parseErr
	}

	cfg := config{
		githubToken:   requireEnv("GITHUB_TOKEN", "Error: GITHUB_TOKEN is required"),
		githubUser:    requireEnv("GITHUB_USER", "Error: GITHUB_USER is required"),
		githubAPI:     "https://api.github.com",
		repo:          args[0],
		runnerUser:    "runner",
		runnerVersion: getenvDefault("RUNNER_VERSION", "2.322.0"),
		runnerArch:    getenvDefault("RUNNER_ARCH", "linux-x64"),
		runnerLabels:  "self-hosted,linux,x64,homelab",
		runnerCount:   runnerCount,
		httpClient:    &http.Client{Timeout: 30 * time.Second},
	}
	if len(args) >= 2 {
		cfg.instanceNum = args[1]
	}
	cfg.runnerBase = filepath.Join("/home", cfg.runnerUser, "runners")

	log("=== Register Runner for %s/%s ===", cfg.githubUser, cfg.repo)

	tarball := fmt.Sprintf("actions-runner-%s-%s.tar.gz", cfg.runnerArch, cfg.runnerVersion)
	tmpTar := filepath.Join("/tmp", tarball)
	if _, statErr := os.Stat(tmpTar); os.IsNotExist(statErr) {
		log("Downloading runner v%s...", cfg.runnerVersion)
		url := fmt.Sprintf("https://github.com/actions/runner/releases/download/v%s/%s", cfg.runnerVersion, tarball)
		if err := runCmd("curl", "-sL", url, "-o", tmpTar); err != nil {
			return err
		}
	}

	if err := runCmd("sudo", "-u", cfg.runnerUser, "mkdir", "-p", cfg.runnerBase); err != nil {
		return err
	}

	if cfg.instanceNum != "" {
		log("Instance: %s", cfg.instanceNum)
		return registerInstance(cfg, cfg.instanceNum)
	}

	log("Instances: 1..%d", cfg.runnerCount)
	success := 0
	failed := 0

	for i := 1; i <= cfg.runnerCount; i++ {
		instance := fmt.Sprintf("%d", i)
		if err := registerInstance(cfg, instance); err != nil {
			failed++
		} else {
			success++
		}
	}

	log("")
	log("=== Registration Complete ===")
	log("Success: %d | Failed: %d", success, failed)
	return nil
}

func registerInstance(cfg config, instance string) error {
	runnerName := fmt.Sprintf("homelab-101-%s", instance)
	runnerDir := filepath.Join(cfg.runnerBase, fmt.Sprintf("instance-%s", instance), cfg.repo)
	tarball := fmt.Sprintf("actions-runner-%s-%s.tar.gz", cfg.runnerArch, cfg.runnerVersion)
	serviceName := fmt.Sprintf("github-runner-%s-%s", instance, cfg.repo)

	log("Registering instance %s for %s/%s (runner: %s)...", instance, cfg.githubUser, cfg.repo, runnerName)

	_ = runCmdQuiet("systemctl", "stop", serviceName+".service")

	if err := runCmd("sudo", "-u", cfg.runnerUser, "mkdir", "-p", runnerDir); err != nil {
		return err
	}

	if _, err := os.Stat(filepath.Join(runnerDir, "run.sh")); os.IsNotExist(err) {
		if err := runCmdQuiet("sudo", "-u", cfg.runnerUser, "tar", "xzf", filepath.Join("/tmp", tarball), "-C", runnerDir); err != nil {
			return err
		}
	}

	if _, err := os.Stat(filepath.Join(runnerDir, ".runner")); err == nil {
		removeToken, tokenErr := getGitHubToken(cfg, cfg.repo, "remove-token")
		if tokenErr == nil && removeToken != "" {
			cmd := fmt.Sprintf("cd '%s' && ./config.sh remove --token '%s'", runnerDir, removeToken)
			_ = runCmdQuiet("sudo", "-u", cfg.runnerUser, "bash", "-c", cmd)
		}
	}

	token, tokenErr := getGitHubToken(cfg, cfg.repo, "registration-token")
	if tokenErr != nil || token == "" || token == "null" {
		err("Failed to get registration token for instance %s. Check GITHUB_TOKEN permissions.", instance)
		if tokenErr != nil {
			return tokenErr
		}
		return fmt.Errorf("empty registration token")
	}

	configScript := fmt.Sprintf("cd '%s' && ./config.sh --url 'https://github.com/%s/%s' --token '%s' --name '%s' --labels '%s' --work '%s/_work' --replace --unattended", runnerDir, cfg.githubUser, cfg.repo, token, runnerName, cfg.runnerLabels, runnerDir)
	if cmdErr := runCmd("sudo", "-u", cfg.runnerUser, "bash", "-c", configScript); cmdErr != nil {
		err("Failed to register instance %s for %s.", instance, cfg.repo)
		return cmdErr
	}

	unitContent := fmt.Sprintf(`[Unit]
Description=GitHub Actions Runner - instance %s - %s
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=%s
Group=%s
WorkingDirectory=%s
ExecStart=%s/run.sh
Restart=always
RestartSec=10
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min

Environment="DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1"

[Install]
WantedBy=multi-user.target
`, instance, cfg.repo, cfg.runnerUser, cfg.runnerUser, runnerDir, runnerDir)

	unitPath := filepath.Join("/etc/systemd/system", serviceName+".service")
	if err := os.WriteFile(unitPath, []byte(unitContent), 0o644); err != nil {
		return err
	}

	if err := runCmd("systemctl", "daemon-reload"); err != nil {
		return err
	}
	if err := runCmd("systemctl", "enable", serviceName+".service"); err != nil {
		return err
	}
	if err := runCmd("systemctl", "start", serviceName+".service"); err != nil {
		return err
	}

	log("Runner started: systemctl status %s", serviceName)
	return nil
}

func getGitHubToken(cfg config, repo, tokenType string) (string, error) {
	url := fmt.Sprintf("%s/repos/%s/%s/actions/runners/%s", cfg.githubAPI, cfg.githubUser, repo, tokenType)
	req, err := http.NewRequest(http.MethodPost, url, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "token "+cfg.githubToken)
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := cfg.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var parsed struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return "", err
	}

	return parsed.Token, nil
}

func requireEnv(key, msg string) string {
	v := os.Getenv(key)
	if v == "" {
		err(msg)
		os.Exit(1)
	}
	return v
}

func getenvDefault(key, def string) string {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	return v
}

func parseInt(v string) (int, error) {
	var x int
	_, err := fmt.Sscanf(strings.TrimSpace(v), "%d", &x)
	if err != nil {
		return 0, err
	}
	return x, nil
}

func runCmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runCmdQuiet(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	return cmd.Run()
}

func log(format string, args ...any) {
	fmt.Printf(green+"[+]"+nc+" "+format+"\n", args...)
}

func warn(format string, args ...any) {
	fmt.Printf(yellow+"[!]"+nc+" "+format+"\n", args...)
}

func err(format string, args ...any) {
	fmt.Fprintf(os.Stderr, red+"[-]"+nc+" "+format+"\n", args...)
}

func cmdOutput(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return "", err
	}
	return out.String(), nil
}
