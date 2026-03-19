//go:build register_all_repos
// +build register_all_repos

package main

import (
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

	runnerCount, parseErr := parseInt(getenvDefault("RUNNER_COUNT", "2"))
	if parseErr != nil {
		return parseErr
	}

	cfg := config{
		githubToken:   requireEnv("GITHUB_TOKEN", "Error: GITHUB_TOKEN is required"),
		githubUser:    requireEnv("GITHUB_USER", "Error: GITHUB_USER is required"),
		githubAPI:     "https://api.github.com",
		runnerUser:    "runner",
		runnerVersion: getenvDefault("RUNNER_VERSION", "2.322.0"),
		runnerArch:    getenvDefault("RUNNER_ARCH", "linux-x64"),
		runnerLabels:  "self-hosted,linux,x64,homelab",
		runnerCount:   runnerCount,
		httpClient:    &http.Client{Timeout: 30 * time.Second},
	}
	cfg.runnerBase = filepath.Join("/home", cfg.runnerUser, "runners")

	log("=== Bulk Runner Registration ===")
	log("User: %s", cfg.githubUser)
	log("Instances per repo: %d", cfg.runnerCount)
	log("")

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

	repos, fetchErr := fetchRepos(cfg)
	if fetchErr != nil {
		return fetchErr
	}
	if len(repos) == 0 {
		err("No repos found for %s.", cfg.githubUser)
		return fmt.Errorf("no repos found")
	}

	total := 0
	success := 0
	failed := 0

	for i := 1; i <= cfg.runnerCount; i++ {
		log("")
		log("--- Instance %d of %d ---", i, cfg.runnerCount)

		instance := fmt.Sprintf("%d", i)
		for _, repo := range repos {
			if repo == "" {
				continue
			}
			total++
			if err := setupRunnerInstance(cfg, instance, repo); err != nil {
				failed++
			} else {
				success++
			}
		}
	}

	log("")
	log("=== Registration Complete ===")
	log("Total: %d | Success: %d | Failed: %d", total, success, failed)
	log("")
	log("Manage runners:")
	log("  systemctl list-units 'github-runner-*'")
	log("  systemctl status github-runner-<instance>-<repo>")
	log("  journalctl -u github-runner-<instance>-<repo> -f")

	return nil
}

func fetchRepos(cfg config) ([]string, error) {
	page := 1
	allRepos := make([]string, 0)

	for {
		url := fmt.Sprintf("%s/user/repos?per_page=100&page=%d&affiliation=owner", cfg.githubAPI, page)
		req, err := http.NewRequest(http.MethodGet, url, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("Authorization", "token "+cfg.githubToken)

		resp, err := cfg.httpClient.Do(req)
		if err != nil {
			return nil, err
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			return nil, readErr
		}

		var repos []struct {
			Name string `json:"name"`
		}
		if err := json.Unmarshal(body, &repos); err != nil {
			return nil, err
		}

		names := make([]string, 0)
		for _, r := range repos {
			if r.Name != "" {
				names = append(names, r.Name)
			}
		}

		if len(names) == 0 {
			break
		}

		allRepos = append(allRepos, names...)
		page++
	}

	return allRepos, nil
}

func setupRunnerInstance(cfg config, instance, repo string) error {
	runnerName := fmt.Sprintf("homelab-101-%s", instance)
	runnerDir := filepath.Join(cfg.runnerBase, fmt.Sprintf("instance-%s", instance), repo)
	tarball := fmt.Sprintf("actions-runner-%s-%s.tar.gz", cfg.runnerArch, cfg.runnerVersion)
	serviceName := fmt.Sprintf("github-runner-%s-%s", instance, repo)

	log("Setting up instance %s for %s/%s (runner: %s)...", instance, cfg.githubUser, repo, runnerName)

	if err := runCmd("sudo", "-u", cfg.runnerUser, "mkdir", "-p", runnerDir); err != nil {
		return err
	}

	if _, err := os.Stat(filepath.Join(runnerDir, "run.sh")); os.IsNotExist(err) {
		if err := runCmdQuiet("sudo", "-u", cfg.runnerUser, "tar", "xzf", filepath.Join("/tmp", tarball), "-C", runnerDir); err != nil {
			return err
		}
	}

	token, tokenErr := getRegistrationToken(cfg, repo)
	if tokenErr != nil || token == "" {
		warn("Failed to get token for %s (instance %s). Skipping.", repo, instance)
		if tokenErr != nil {
			return tokenErr
		}
		return fmt.Errorf("empty token")
	}

	configScript := fmt.Sprintf("cd '%s' && ./config.sh --url 'https://github.com/%s/%s' --token '%s' --name '%s' --labels '%s' --work '%s/_work' --replace --unattended", runnerDir, cfg.githubUser, repo, token, runnerName, cfg.runnerLabels, runnerDir)
	if cmdErr := runCmd("sudo", "-u", cfg.runnerUser, "bash", "-c", configScript); cmdErr != nil {
		warn("Failed to register instance %s for %s. Skipping.", instance, repo)
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
`, instance, repo, cfg.runnerUser, cfg.runnerUser, runnerDir, runnerDir)

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

func getRegistrationToken(cfg config, repo string) (string, error) {
	url := fmt.Sprintf("%s/repos/%s/%s/actions/runners/registration-token", cfg.githubAPI, cfg.githubUser, repo)
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
