//go:build setup_runner
// +build setup_runner

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
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
	githubUser    string
	skipDocker    string
}

func main() {
	if err := run(); err != nil {
		os.Exit(1)
	}
}

func run() (runErr error) {
	defer cleanup(&runErr)

	if os.Geteuid() != 0 {
		err("This script must run as root.")
		return fmt.Errorf("not running as root")
	}

	cfg := config{
		runnerVersion: getenvDefault("RUNNER_VERSION", "2.322.0"),
		runnerArch:    getenvDefault("RUNNER_ARCH", "linux-x64"),
		runnerUser:    "runner",
		githubUser:    getenvDefault("GITHUB_USER", "runner"),
		skipDocker:    getenvDefault("SKIP_DOCKER", "0"),
	}
	cfg.runnerHome = filepath.Join("/home", cfg.runnerUser)
	cfg.runnerDir = filepath.Join(cfg.runnerHome, "actions-runner")

	if err := os.Setenv("RUNNER_LABELS", "self-hosted,linux,x64,homelab"); err != nil {
		return err
	}

	log("=== GitHub Actions Runner Setup ===")
	log("Target: VMID 101 (192.168.50.101)")
	log("User: %s", cfg.githubUser)
	log("")

	if err := installDependencies(); err != nil {
		return err
	}

	if cfg.skipDocker != "1" {
		if err := installDocker(); err != nil {
			return err
		}
	} else {
		warn("Skipping Docker install (SKIP_DOCKER=1, unprivileged LXC)")
	}

	if err := createRunnerUser(cfg); err != nil {
		return err
	}
	if err := installRunner(cfg); err != nil {
		return err
	}
	if err := installInfraTools(); err != nil {
		return err
	}
	if err := installService(cfg); err != nil {
		return err
	}

	log("")
	log("=== Setup Complete ===")
	log("Next: Run register-all-repos.sh to register runner instances to all repos")
	log("")

	return nil
}

func cleanup(runErr *error) {
	if runErr != nil && *runErr != nil {
		err("Setup failed with exit code 1. Partial install may exist.")
		err("Review output above and re-run after fixing the issue.")
	}
	_ = os.RemoveAll("/tmp/terraform.zip")
	tmpMatches, _ := filepath.Glob("/tmp/actions-runner-*.tar.gz")
	for _, f := range tmpMatches {
		_ = os.Remove(f)
	}
}

func installDependencies() error {
	log("Installing system dependencies...")
	if err := runCmd("apt-get", "update", "-qq"); err != nil {
		return err
	}
	args := []string{
		"install", "-y", "-qq",
		"curl",
		"jq",
		"git",
		"sudo",
		"ca-certificates",
		"gnupg",
		"lsb-release",
		"build-essential",
		"libssl-dev",
		"libffi-dev",
		"python3",
		"python3-pip",
		"python3-venv",
		"unzip",
		"zip",
		"wget",
		"apt-transport-https",
		"software-properties-common",
	}
	if err := runCmdQuiet("apt-get", args...); err != nil {
		return err
	}
	log("System dependencies installed.")
	return nil
}

func installDocker() error {
	if _, err := exec.LookPath("docker"); err == nil {
		v, verr := cmdOutput("docker", "--version")
		if verr != nil {
			return verr
		}
		log("Docker already installed: %s", trimNL(v))
		return nil
	}

	log("Installing Docker...")
	if err := runCmd("install", "-m", "0755", "-d", "/etc/apt/keyrings"); err != nil {
		return err
	}
	if err := runCmd("bash", "-c", "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"); err != nil {
		return err
	}
	if err := runCmd("chmod", "a+r", "/etc/apt/keyrings/docker.gpg"); err != nil {
		return err
	}
	if err := runCmd("bash", "-c", "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null"); err != nil {
		return err
	}
	if err := runCmd("apt-get", "update", "-qq"); err != nil {
		return err
	}
	if err := runCmdQuiet("apt-get", "install", "-y", "-qq", "docker-ce", "docker-ce-cli", "containerd.io", "docker-buildx-plugin", "docker-compose-plugin"); err != nil {
		return err
	}
	if err := runCmd("systemctl", "enable", "docker"); err != nil {
		return err
	}
	if err := runCmd("systemctl", "start", "docker"); err != nil {
		return err
	}
	v, err := cmdOutput("docker", "--version")
	if err != nil {
		return err
	}
	log("Docker installed: %s", trimNL(v))
	return nil
}

func createRunnerUser(cfg config) error {
	if err := runCmdSilently("id", cfg.runnerUser); err == nil {
		log("Runner user '%s' already exists.", cfg.runnerUser)
	} else {
		log("Creating runner user '%s'...", cfg.runnerUser)
		if err := runCmd("useradd", "-m", "-s", "/bin/bash", cfg.runnerUser); err != nil {
			return err
		}
		if err := runCmd("usermod", "-aG", "sudo", cfg.runnerUser); err != nil {
			return err
		}
		sudoersPath := filepath.Join("/etc/sudoers.d", cfg.runnerUser)
		content := fmt.Sprintf("%s ALL=(ALL) NOPASSWD:ALL\n", cfg.runnerUser)
		if err := os.WriteFile(sudoersPath, []byte(content), 0o644); err != nil {
			return err
		}
	}

	if err := runCmdSilently("getent", "group", "docker"); err == nil {
		if err := runCmd("usermod", "-aG", "docker", cfg.runnerUser); err != nil {
			return err
		}
	}

	return nil
}

func installRunner(cfg config) error {
	log("Installing GitHub Actions Runner v%s...", cfg.runnerVersion)

	tarball := fmt.Sprintf("actions-runner-%s-%s.tar.gz", cfg.runnerArch, cfg.runnerVersion)
	url := fmt.Sprintf("https://github.com/actions/runner/releases/download/v%s/%s", cfg.runnerVersion, tarball)

	if err := runCmd("sudo", "-u", cfg.runnerUser, "mkdir", "-p", cfg.runnerDir); err != nil {
		return err
	}

	runnerMarker := filepath.Join(cfg.runnerDir, ".runner")
	if _, err := os.Stat(runnerMarker); os.IsNotExist(err) {
		target := filepath.Join("/tmp", tarball)
		if err := runCmd("curl", "-sL", url, "-o", target); err != nil {
			return err
		}
		if err := runCmd("sudo", "-u", cfg.runnerUser, "tar", "xzf", target, "-C", cfg.runnerDir); err != nil {
			return err
		}
		_ = os.Remove(target)
		log("Runner binary extracted to %s", cfg.runnerDir)
	} else {
		log("Runner already installed at %s", cfg.runnerDir)
	}

	instScript := filepath.Join(cfg.runnerDir, "bin", "installdependencies.sh")
	_ = runCmdQuiet(instScript)
	return nil
}

func installInfraTools() error {
	terraformVersion := getenvDefault("TERRAFORM_VERSION", "1.10.5")

	if _, err := exec.LookPath("terraform"); err == nil {
		v, verr := terraformVersionOutput()
		if verr != nil {
			return verr
		}
		log("Terraform already installed: %s", v)
	} else {
		log("Installing Terraform v%s...", terraformVersion)
		zipPath := "/tmp/terraform.zip"
		url := fmt.Sprintf("https://releases.hashicorp.com/terraform/%s/terraform_%s_linux_amd64.zip", terraformVersion, terraformVersion)
		if err := runCmd("wget", "-q", url, "-O", zipPath); err != nil {
			return err
		}
		if err := runCmdQuiet("unzip", "-o", zipPath, "-d", "/usr/local/bin/"); err != nil {
			return err
		}
		_ = os.Remove(zipPath)
		v, verr := terraformVersionOutput()
		if verr != nil {
			return verr
		}
		log("Terraform installed: %s", v)
	}

	if _, err := exec.LookPath("bazel"); err == nil {
		log("Bazelisk already installed.")
	} else {
		log("Installing Bazelisk...")
		if err := runCmd("wget", "-q", "https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64", "-O", "/usr/local/bin/bazel"); err != nil {
			return err
		}
		if err := runCmd("chmod", "+x", "/usr/local/bin/bazel"); err != nil {
			return err
		}
		log("Bazelisk installed at /usr/local/bin/bazel")
	}

	return nil
}

func installService(cfg config) error {
	log("Installing runner service template...")

	service := fmt.Sprintf(`[Unit]
Description=GitHub Actions Runner - %%i
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=%s
Group=%s
WorkingDirectory=/home/%s/runners/%%i
ExecStart=/home/%s/runners/%%i/run.sh
Restart=always
RestartSec=10
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min

Environment="DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1"

[Install]
WantedBy=multi-user.target
`, cfg.runnerUser, cfg.runnerUser, cfg.runnerUser, cfg.runnerUser)

	if err := os.WriteFile("/etc/systemd/system/github-runner@.service", []byte(service), 0o644); err != nil {
		return err
	}
	if err := runCmd("systemctl", "daemon-reload"); err != nil {
		return err
	}
	log("Systemd template service installed: github-runner@<name>.service")
	return nil
}

func terraformVersionOutput() (string, error) {
	out, err := cmdOutput("terraform", "version", "-json")
	if err != nil {
		return "", err
	}
	var parsed struct {
		TerraformVersion string `json:"terraform_version"`
	}
	if err := json.Unmarshal([]byte(out), &parsed); err != nil {
		return "", err
	}
	if parsed.TerraformVersion == "" {
		return "", fmt.Errorf("terraform_version missing")
	}
	return parsed.TerraformVersion, nil
}

func getenvDefault(key, def string) string {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	return v
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

func runCmdSilently(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	return cmd.Run()
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

func trimNL(s string) string {
	for len(s) > 0 && (s[len(s)-1] == '\n' || s[len(s)-1] == '\r') {
		s = s[:len(s)-1]
	}
	return s
}
