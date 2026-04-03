// GitLab Runner Setup Script for LXC 101
// Install and configure GitLab Runner with Docker executor

package main

import (
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
		concurrent:    getenvDefault("RUNNER_CONCURRENT", "4"),
	}
	cfg.runnerDir = filepath.Join("/opt", "gitlab-runner")

	log("=== GitLab Runner Setup ===")
	log("Target: VMID 101 (192.168.50.101)")
	log("GitLab URL: %s", cfg.gitlabURL)
	log("Tags: %s", cfg.tags)
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

	log("")
	log("=== Setup Complete ===")
	if cfg.gitlabToken == "" {
		warn("GITLAB_RUNNER_TOKEN not set - registration skipped")
		log("To register: GITLAB_RUNNER_TOKEN=<token> go run setup-gitlab-runner.go")
	}
	log("")

	return nil
}

func installDependencies() error {
	log("Installing system dependencies...")

	if err := runCmd("apt-get", "update", "-qq"); err != nil {
		return err
	}

	pkgs := []string{
		"curl", "jq", "git", "sudo", "ca-certificates",
		"gnupg", "lsb-release", "unzip", "wget",
	}

	args := append([]string{"install", "-y", "-qq"}, pkgs...)
	if err := runCmd("apt-get", args...); err != nil {
		return err
	}

	log("System dependencies installed")
	return nil
}

func installDocker() error {
	if _, err := exec.LookPath("docker"); err == nil {
		v, _ := cmdOutput("docker", "--version")
		log("Docker already installed: %s", strings.TrimSpace(v))
		return nil
	}

	log("Installing Docker...")

	if err := runCmd("install", "-m", "0755", "-d", "/etc/apt/keyrings"); err != nil {
		return err
	}

	cmd := `curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg`
	if err := runCmd("bash", "-c", cmd); err != nil {
		return err
	}

	if err := runCmd("chmod", "a+r", "/etc/apt/keyrings/docker.gpg"); err != nil {
		return err
	}

	repo := `echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null`
	if err := runCmd("bash", "-c", repo); err != nil {
		return err
	}

	if err := runCmd("apt-get", "update", "-qq"); err != nil {
		return err
	}

	if err := runCmd("apt-get", "install", "-y", "-qq",
		"docker-ce", "docker-ce-cli", "containerd.io",
		"docker-buildx-plugin", "docker-compose-plugin"); err != nil {
		return err
	}

	if err := runCmd("systemctl", "enable", "docker"); err != nil {
		return err
	}

	if err := runCmd("systemctl", "start", "docker"); err != nil {
		return err
	}

	v, _ := cmdOutput("docker", "--version")
	log("Docker installed: %s", strings.TrimSpace(v))
	return nil
}

func createRunnerUser(cfg config) error {
	if err := runCmd("id", cfg.runnerUser); err == nil {
		log("Runner user '%s' already exists", cfg.runnerUser)
	} else {
		log("Creating runner user '%s'...", cfg.runnerUser)
		if err := runCmd("useradd", "-m", "-s", "/bin/bash", cfg.runnerUser); err != nil {
			return err
		}
	}

	if err := runCmd("usermod", "-aG", "docker", cfg.runnerUser); err != nil {
		return err
	}

	if err := runCmd("mkdir", "-p", cfg.runnerDir); err != nil {
		return err
	}

	if err := runCmd("chown", fmt.Sprintf("%s:%s", cfg.runnerUser, cfg.runnerUser), cfg.runnerDir); err != nil {
		return err
	}

	return nil
}

func installRunner(cfg config) error {
	log("Installing GitLab Runner v%s...", cfg.runnerVersion)

	binary := fmt.Sprintf("gitlab-runner-%s", cfg.runnerArch)
	url := fmt.Sprintf("https://gitlab-runner-downloads.s3.amazonaws.com/v%s/binaries/%s",
		cfg.runnerVersion, binary)

	binaryPath := filepath.Join("/usr/local/bin", "gitlab-runner")

	if _, err := os.Stat(binaryPath); err == nil {
		v, _ := cmdOutput("gitlab-runner", "--version")
		log("GitLab Runner already installed: %s", strings.Split(v, "\n")[0])
		return nil
	}

	if err := runCmd("curl", "-sL", url, "-o", binaryPath); err != nil {
		return err
	}

	if err := runCmd("chmod", "+x", binaryPath); err != nil {
		return err
	}

	log("GitLab Runner installed to %s", binaryPath)
	return nil
}

func installTerraform() error {
	version := getenvDefault("TERRAFORM_VERSION", "1.10.5")

	if _, err := exec.LookPath("terraform"); err == nil {
		v, _ := cmdOutput("terraform", "version")
		log("Terraform already installed: %s", strings.Split(v, "\n")[0])
		return nil
	}

	log("Installing Terraform v%s...", version)

	zipPath := "/tmp/terraform.zip"
	url := fmt.Sprintf("https://releases.hashicorp.com/terraform/%s/terraform_%s_linux_amd64.zip",
		version, version)

	if err := runCmd("wget", "-q", url, "-O", zipPath); err != nil {
		return err
	}

	if err := runCmd("unzip", "-o", "-q", zipPath, "-d", "/usr/local/bin/"); err != nil {
		return err
	}

	os.Remove(zipPath)

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

	cmd := exec.Command("gitlab-runner", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = cfg.runnerDir

	if err := cmd.Run(); err != nil {
		return err
	}

	log("Runner registered successfully")

	// Update config.toml with concurrent setting
	if err := updateConfigConcurrent(cfg); err != nil {
		warn("Failed to update concurrent setting: %v", err)
	}

	if err := installSystemdService(cfg); err != nil {

	return nil
}

func updateConfigConcurrent(cfg config) error {
	configPath := filepath.Join(cfg.runnerDir, "config.toml")

	// Read existing config
	content, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}

	configStr := string(content)

	// Add concurrent setting at the beginning if not exists
	if !strings.Contains(configStr, "concurrent") {
		configStr = fmt.Sprintf("concurrent = %s\n\n%s", cfg.concurrent, configStr)
		if err := os.WriteFile(configPath, []byte(configStr), 0644); err != nil {
			return err
		}
		log("Updated concurrent = %s in config.toml", cfg.concurrent)
	}

	return nil
}

func getenvDefault(key, def string) string {
func getenvDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func log(format string, args ...interface{}) {
	fmt.Printf(green+"[+]"+nc+" "+format+"\n", args...)
}

func warn(format string, args ...interface{}) {
	fmt.Printf(yellow+"[!]"+nc+" "+format+"\n", args...)
}

func runCmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func cmdOutput(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return string(out), err
}
