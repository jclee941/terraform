package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	nc     = "\033[0m"
)

type config struct {
	runnerVersion string
	runnerArch    string
	runnerUser    string
	runnerHome    string
	runnerDir     string
	gitlabURL     string
	gitlabToken   string
	skipDocker    bool
	tags          string
	concurrent    string
	cacheDir      string
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "%s[-]%s %v\n", red, nc, err)
		os.Exit(1)
	}
}

func run() error {
	if os.Geteuid() != 0 {
		return fmt.Errorf("this script must run as root")
	}

	cfg := config{
		runnerVersion: getenvDefault("RUNNER_VERSION", "17.8.0"),
		runnerArch:    getenvDefault("RUNNER_ARCH", "linux-amd64"),
		runnerUser:    "gitlab-runner",
		gitlabURL:     getenvDefault("GITLAB_URL", "http://gitlab.jclee.me"),
		gitlabToken:   os.Getenv("GITLAB_RUNNER_TOKEN"),
		skipDocker:    os.Getenv("SKIP_DOCKER") == "1",
		tags:          getenvDefault("RUNNER_TAGS", "homelab,docker,linux,terraform"),
		concurrent:    getenvDefault("RUNNER_CONCURRENT", "8"),
		cacheDir:      getenvDefault("RUNNER_CACHE_DIR", "/srv/gitlab-runner/cache"),
	}
	cfg.runnerDir = filepath.Join("/opt", "gitlab-runner")

	log("=== GitLab Runner Setup ===")
	log("Target: VMID 101 (192.168.50.101)")
	log("GitLab URL: %s", cfg.gitlabURL)
	log("Tags: %s", cfg.tags)
	log("Cache Dir: %s", cfg.cacheDir)
	log("")

	if err := installDependencies(); err != nil {
		return fmt.Errorf("install dependencies: %w", err)
	}

	if !cfg.skipDocker {
		if err := installDocker(); err != nil {
			return fmt.Errorf("install docker: %w", err)
		}
	} else {
		warn("Skipping Docker install (SKIP_DOCKER=1)")
	}

	if err := createRunnerUser(cfg); err != nil {
		return fmt.Errorf("create runner user: %w", err)
	}

	if err := installRunner(cfg); err != nil {
		return fmt.Errorf("install runner: %w", err)
	}

	if err := installTerraform(); err != nil {
		return fmt.Errorf("install terraform: %w", err)
	}

	if err := configureRunner(cfg); err != nil {
		return fmt.Errorf("configure runner: %w", err)
	}

	if err := setupCacheDirectory(cfg); err != nil {
		warn("Failed to setup cache directory: %v", err)
	}

	if err := installSystemdService(cfg); err != nil {
		return fmt.Errorf("install systemd service: %w", err)
	}

	log("")
	log("=== Setup Complete ===")
	if cfg.gitlabToken == "" {
		warn("GITLAB_RUNNER_TOKEN not set - registration skipped")
		log("To register: GITLAB_RUNNER_TOKEN=<token> go run setup-gitlab-runner.go")
	}
	log("")

	return nil
}

func getenvDefault(key, defaultValue string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultValue
}

func log(format string, args ...interface{}) {
	fmt.Printf("%s[+]%s %s\n", green, nc, fmt.Sprintf(format, args...))
}

func warn(format string, args ...interface{}) {
	fmt.Printf("%s[!]%s %s\n", yellow, nc, fmt.Sprintf(format, args...))
}

func installDependencies() error {
	log("Installing dependencies...")
	deps := []string{"curl", "jq", "ca-certificates", "apt-transport-https", "lsb-release", "gnupg"}
	cmd := exec.Command("apt-get", append([]string{"install", "-y"}, deps...)...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func installDocker() error {
	log("Installing Docker...")

	// Add Docker GPG key
	cmd := exec.Command("bash", "-c", "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("add docker gpg key: %w", err)
	}

	// Add Docker repository
	cmd = exec.Command("bash", "-c", "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" > /etc/apt/sources.list.d/docker.list")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("add docker repo: %w", err)
	}

	// Install Docker
	cmd = exec.Command("apt-get", "update")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("apt update: %w", err)
	}

	cmd = exec.Command("apt-get", "install", "-y", "docker-ce", "docker-ce-cli", "containerd.io", "docker-buildx-plugin", "docker-compose-plugin")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("install docker: %w", err)
	}

	log("Docker installed successfully")
	return nil
}

func createRunnerUser(cfg config) error {
	log("Creating runner user: %s", cfg.runnerUser)

	// Check if user exists
	cmd := exec.Command("id", cfg.runnerUser)
	if err := cmd.Run(); err == nil {
		log("User %s already exists", cfg.runnerUser)
	} else {
		cmd = exec.Command("useradd", "-m", "-s", "/bin/bash", cfg.runnerUser)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("create user: %w", err)
		}
	}

	// Add user to docker group
	cmd = exec.Command("usermod", "-aG", "docker", cfg.runnerUser)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("add user to docker group: %w", err)
	}

	return nil
}

func installRunner(cfg config) error {
	log("Installing GitLab Runner...")

	// Create runner directory
	if err := os.MkdirAll(cfg.runnerDir, 0755); err != nil {
		return fmt.Errorf("create runner dir: %w", err)
	}

	// Download runner binary
	url := fmt.Sprintf("https://gitlab-runner-downloads.s3.amazonaws.com/v%s/binaries/gitlab-runner-linux-amd64", cfg.runnerVersion)
	binaryPath := filepath.Join(cfg.runnerDir, "gitlab-runner")

	cmd := exec.Command("curl", "-L", "--output", binaryPath, url)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("download runner: %w", err)
	}

	// Make executable
	if err := os.Chmod(binaryPath, 0755); err != nil {
		return fmt.Errorf("chmod runner: %w", err)
	}

	// Create symlink
	cmd = exec.Command("ln", "-sf", binaryPath, "/usr/local/bin/gitlab-runner")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("create symlink: %w", err)
	}

	log("GitLab Runner %s installed", cfg.runnerVersion)
	return nil
}

func installTerraform() error {
	log("Installing Terraform...")

	cmd := exec.Command("bash", "-c", "curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("add hashicorp gpg key: %w", err)
	}

	cmd = exec.Command("bash", "-c", "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" > /etc/apt/sources.list.d/hashicorp.list")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("add hashicorp repo: %w", err)
	}

	cmd = exec.Command("apt-get", "update")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("apt update: %w", err)
	}

	cmd = exec.Command("apt-get", "install", "-y", "terraform")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("install terraform: %w", err)
	}

	v, _ := cmdOutput("terraform", "version")
	log("Terraform installed: %s", strings.Split(v, "\n")[0])
	return nil
}

func configureRunner(cfg config) error {
	if cfg.gitlabToken == "" {
		return nil
	}

	log("Registering GitLab Runner...")

	configPath := filepath.Join(cfg.runnerDir, "config.toml")
	if _, err := os.Stat(configPath); err == nil {
		log("Runner config already exists, skipping registration")
		return nil
	}

	args := []string{
		"register",
		"--non-interactive",
		"--url", cfg.gitlabURL,
		"--registration-token", cfg.gitlabToken,
		"--executor", "docker",
		"--docker-image", "alpine:latest",
		"--name", "homelab-101",
		"--tag-list", cfg.tags,
		"--run-untagged", "false",
		"--locked", "false",
		"--access-level", "not_protected",
		"--config", configPath,
		"--docker-memory", "512m",
		"--docker-cpus", "1.5",
	}
	cmd := exec.Command("gitlab-runner", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = cfg.runnerDir

	if err := cmd.Run(); err != nil {
		return err
	}

	log("Runner registered successfully")

	// Update config.toml with cache and concurrent settings
	if err := updateRunnerConfig(cfg); err != nil {
		warn("Failed to update runner config: %v", err)
	}

	return nil
}

func setupCacheDirectory(cfg config) error {
	log("Setting up cache directory: %s", cfg.cacheDir)

	// Create cache directory
	if err := os.MkdirAll(cfg.cacheDir, 0755); err != nil {
		return fmt.Errorf("create cache dir: %w", err)
	}

	// Set ownership to gitlab-runner user
	cmd := exec.Command("chown", "-R", fmt.Sprintf("%s:%s", cfg.runnerUser, cfg.runnerUser), cfg.cacheDir)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("chown cache dir: %w", err)
	}

	log("Cache directory ready: %s", cfg.cacheDir)
	return nil
}

func updateRunnerConfig(cfg config) error {
	configPath := filepath.Join(cfg.runnerDir, "config.toml")

	// Read current config
	content, err := os.ReadFile(configPath)
	if err != nil {
		return fmt.Errorf("read config: %w", err)
	}

	lines := strings.Split(string(content), "\n")
	var newLines []string
	inRunnerSection := false
	cacheAdded := false
	concurrentAdded := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		// Detect runner section start
		if strings.HasPrefix(trimmed, "[[runners]]") {
			inRunnerSection = true
		}

		// Check if cache is already configured
		if inRunnerSection && strings.HasPrefix(trimmed, "[runners.cache]") {
			cacheAdded = true
		}

		// Add cache configuration before the end of first runners section
		if inRunnerSection && !cacheAdded && (trimmed == "" || strings.HasPrefix(trimmed, "[[runners]]")) {
			newLines = append(newLines, "  [runners.cache]")
			newLines = append(newLines, "    Type = \"local\"")
			newLines = append(newLines, fmt.Sprintf("    Path = \"%s\"", cfg.cacheDir))
			newLines = append(newLines, "")
			cacheAdded = true
		}

		newLines = append(newLines, line)

		// Check for concurrent at top level
		if strings.HasPrefix(trimmed, "concurrent = ") {
			concurrentAdded = true
		}
	}

	// Update concurrent at top level
	if !concurrentAdded {
		// Insert concurrent at the beginning
		newLines = append([]string{fmt.Sprintf("concurrent = %s", cfg.concurrent), ""}, newLines...)
	} else {
		// Replace existing concurrent line
		for i, line := range newLines {
			if strings.HasPrefix(strings.TrimSpace(line), "concurrent = ") {
				newLines[i] = fmt.Sprintf("concurrent = %s", cfg.concurrent)
				break
			}
		}
	}

	// Write updated config
	newContent := strings.Join(newLines, "\n")
	if err := os.WriteFile(configPath, []byte(newContent), 0600); err != nil {
		return fmt.Errorf("write config: %w", err)
	}

	log("Runner config updated with cache and concurrent settings")
	return nil
}

func installSystemdService(cfg config) error {
	log("Installing systemd service...")

	serviceName := "gitlab-runner"
	servicePath := filepath.Join("/etc/systemd/system", serviceName+".service")

	// Check if service exists
	if _, err := os.Stat(servicePath); err == nil {
		log("Systemd service already exists")
		return nil
	}

	serviceContent := fmt.Sprintf(`[Unit]
Description=GitLab Runner
After=syslog.target network.target
ConditionFileIsExecutable=%s/gitlab-runner

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=%s/gitlab-runner run --working-directory=%s --config=%s/config.toml --service gitlab-runner --user %s
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
`, cfg.runnerDir, cfg.runnerDir, cfg.runnerDir, cfg.runnerDir, cfg.runnerUser)

	if err := os.WriteFile(servicePath, []byte(serviceContent), 0644); err != nil {
		return fmt.Errorf("write service file: %w", err)
	}

	// Reload systemd and enable service
	cmd := exec.Command("systemctl", "daemon-reload")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("daemon reload: %w", err)
	}

	cmd = exec.Command("systemctl", "enable", serviceName)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("enable service: %w", err)
	}

	log("Systemd service installed: %s", serviceName)
	return nil
}

func cmdOutput(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}
