//go:build unregister_all
// +build unregister_all

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
	githubToken string
	githubUser  string
	githubAPI   string
	runnerUser  string
	runnerBase  string
	httpClient  *http.Client
}

func main() {
	if err := run(); err != nil {
		os.Exit(1)
	}
}

func run() error {
	flag.Parse()

	cfg := config{
		githubToken: requireEnv("GITHUB_TOKEN", "Error: GITHUB_TOKEN is required"),
		githubUser:  requireEnv("GITHUB_USER", "Error: GITHUB_USER is required"),
		githubAPI:   "https://api.github.com",
		runnerUser:  "runner",
		httpClient:  &http.Client{Timeout: 30 * time.Second},
	}
	cfg.runnerBase = filepath.Join("/home", cfg.runnerUser, "runners")

	log("=== Unregistering All Runners ===")

	if err := stopAndDisableServices(); err != nil {
		return err
	}
	if err := unregisterMultiInstance(cfg); err != nil {
		return err
	}
	if err := unregisterLegacy(cfg); err != nil {
		return err
	}
	if err := cleanupDirs(cfg); err != nil {
		return err
	}

	log("All runners unregistered and cleaned up.")
	return nil
}

func stopAndDisableServices() error {
	services, err := filepath.Glob("/etc/systemd/system/github-runner-*.service")
	if err != nil {
		return err
	}
	for _, service := range services {
		fi, statErr := os.Stat(service)
		if statErr != nil || fi.IsDir() {
			continue
		}
		svcName := strings.TrimSuffix(filepath.Base(service), ".service")
		log("Stopping %s...", svcName)
		_ = runCmdQuiet("systemctl", "stop", svcName)
		_ = runCmdQuiet("systemctl", "disable", svcName)
		_ = os.Remove(service)
	}

	_ = runCmdQuiet("systemctl", "stop", "github-runner.service")
	_ = runCmdQuiet("systemctl", "disable", "github-runner.service")
	_ = os.Remove("/etc/systemd/system/github-runner.service")

	return runCmd("systemctl", "daemon-reload")
}

func unregisterMultiInstance(cfg config) error {
	instancePattern := filepath.Join(cfg.runnerBase, "instance-*")
	instanceDirs, err := filepath.Glob(instancePattern)
	if err != nil {
		return err
	}

	for _, instanceDir := range instanceDirs {
		fi, statErr := os.Stat(instanceDir)
		if statErr != nil || !fi.IsDir() {
			continue
		}

		instance := filepath.Base(instanceDir)
		log("Processing %s...", instance)

		runnerDirs, globErr := filepath.Glob(filepath.Join(instanceDir, "*"))
		if globErr != nil {
			return globErr
		}

		for _, runnerDir := range runnerDirs {
			runnerInfo, runnerStatErr := os.Stat(runnerDir)
			if runnerStatErr != nil || !runnerInfo.IsDir() {
				continue
			}

			repo := filepath.Base(runnerDir)
			log("  Removing runner config for %s (%s)...", repo, instance)

			token, tokenErr := getRemoveToken(cfg, repo)
			if tokenErr == nil && token != "" {
				cmd := fmt.Sprintf("cd '%s' && ./config.sh remove --token '%s'", runnerDir, token)
				_ = runCmdQuiet("sudo", "-u", cfg.runnerUser, "bash", "-c", cmd)
			} else {
				warn("  Failed to get removal token for %s (%s). Directory cleaned anyway.", repo, instance)
			}
		}
	}

	return nil
}

func unregisterLegacy(cfg config) error {
	runnerDirs, err := filepath.Glob(filepath.Join(cfg.runnerBase, "*"))
	if err != nil {
		return err
	}

	for _, runnerDir := range runnerDirs {
		fi, statErr := os.Stat(runnerDir)
		if statErr != nil || !fi.IsDir() {
			continue
		}

		dirName := filepath.Base(runnerDir)
		if strings.HasPrefix(dirName, "instance-") {
			continue
		}

		repo := dirName
		log("Removing legacy runner config for %s...", repo)

		token, tokenErr := getRemoveToken(cfg, repo)
		if tokenErr == nil && token != "" {
			cmd := fmt.Sprintf("cd '%s' && ./config.sh remove --token '%s'", runnerDir, token)
			_ = runCmdQuiet("sudo", "-u", cfg.runnerUser, "bash", "-c", cmd)
		}
	}

	return nil
}

func cleanupDirs(cfg config) error {
	if err := os.RemoveAll(cfg.runnerBase); err != nil {
		return err
	}
	if err := os.RemoveAll(filepath.Join("/home", cfg.runnerUser, "actions-runner")); err != nil {
		return err
	}
	if err := os.RemoveAll(filepath.Join("/home", cfg.runnerUser, "_work")); err != nil {
		return err
	}
	return nil
}

func getRemoveToken(cfg config, repo string) (string, error) {
	url := fmt.Sprintf("%s/repos/%s/%s/actions/runners/remove-token", cfg.githubAPI, cfg.githubUser, repo)
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
