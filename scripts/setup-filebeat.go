package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

const (
	colorRed    = "\033[0;31m"
	colorGreen  = "\033[0;32m"
	colorYellow = "\033[1;33m"
	colorBlue   = "\033[0;34m"
	colorReset  = "\033[0m"

	filebeatVersion = "8.12.0"
	keyringPath     = "/usr/share/keyrings/elasticsearch-keyring.gpg"
	repoFilePath    = "/etc/apt/sources.list.d/elastic-8.x.list"
	repoLine        = "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main"
	configPath      = "/etc/filebeat/filebeat.yml"
)

func main() {
	if os.Geteuid() != 0 {
		errLog("This script must be run as root")
		os.Exit(1)
	}

	info("Starting Filebeat " + filebeatVersion + " installation...")

	osID, codename, err := readOSRelease()
	if err != nil {
		errLog("Failed to read /etc/os-release: " + err.Error())
		os.Exit(1)
	}
	info("Detected OS: " + osID + " " + codename)

	if isCommandAvailable("filebeat") {
		currentVersion, vErr := getFilebeatVersion()
		if vErr != nil {
			errLog("Failed to detect current Filebeat version: " + vErr.Error())
			os.Exit(1)
		}

		if currentVersion == filebeatVersion {
			skip("Filebeat " + filebeatVersion + " is already installed")
		} else {
			warn("Filebeat version mismatch: found " + currentVersion + ", expected " + filebeatVersion)
		}
	} else {
		info("Filebeat not found. Proceeding with installation.")
	}

	info("Installing dependencies (gnupg, apt-transport-https, curl)...")
	mustRun("apt-get", "update", "-qq")
	mustRun("apt-get", "install", "-y", "-qq", "gnupg", "apt-transport-https", "curl")

	if fileExists(keyringPath) {
		skip("Elastic GPG key already exists")
	} else {
		info("Adding Elastic GPG key...")
		if err := addElasticGPGKey(); err != nil {
			errLog("Failed to add Elastic GPG key: " + err.Error())
			os.Exit(1)
		}
	}

	if fileExists(repoFilePath) {
		skip("Elastic 8.x repository already configured")
	} else {
		info("Adding Elastic 8.x repository...")
		if err := os.WriteFile(repoFilePath, []byte(repoLine+"\n"), 0o644); err != nil {
			errLog("Failed to write repository file: " + err.Error())
			os.Exit(1)
		}
	}

	info("Installing Filebeat " + filebeatVersion + "...")
	mustRun("apt-get", "update", "-qq")
	if err := runCommand("apt-get", "install", "-y", "-qq", "--allow-downgrades", "filebeat="+filebeatVersion); err != nil {
		errLog("Failed to install Filebeat: " + err.Error())
		os.Exit(1)
	}
	ok("Filebeat " + filebeatVersion + " installed successfully")

	if groupExists("docker") {
		info("Adding filebeat user to docker group...")
		mustRun("usermod", "-aG", "docker", "filebeat")
		ok("Permissions configured for /var/lib/docker/containers")
	} else {
		warn("Docker group not found. Skipping group assignment.")
	}

	info("Enabling Filebeat systemd service...")
	mustRun("systemctl", "enable", "filebeat")

	if fileExists(configPath) {
		info("Configuration found at " + configPath + ". Starting service...")
		mustRun("systemctl", "restart", "filebeat")
		ok("Filebeat service started")
	} else {
		warn("Configuration NOT found at " + configPath + ". Service will NOT be started.")
		info("Please deploy configuration before starting the service.")
	}

	ok("Filebeat setup completed successfully")
}

func addElasticGPGKey() error {
	curlCmd := exec.Command("curl", "-fsSL", "https://artifacts.elastic.co/GPG-KEY-elasticsearch")
	gpgCmd := exec.Command("gpg", "--dearmor", "-o", keyringPath)

	stdoutPipe, err := curlCmd.StdoutPipe()
	if err != nil {
		return fmt.Errorf("create curl stdout pipe: %w", err)
	}

	curlCmd.Stderr = os.Stderr
	gpgCmd.Stdin = stdoutPipe
	gpgCmd.Stdout = os.Stdout
	gpgCmd.Stderr = os.Stderr

	if err := curlCmd.Start(); err != nil {
		return fmt.Errorf("start curl: %w", err)
	}
	if err := gpgCmd.Start(); err != nil {
		_ = curlCmd.Process.Kill()
		_ = curlCmd.Wait()
		return fmt.Errorf("start gpg: %w", err)
	}

	if err := curlCmd.Wait(); err != nil {
		_ = gpgCmd.Process.Kill()
		_ = gpgCmd.Wait()
		return fmt.Errorf("curl command failed: %w", err)
	}
	if err := gpgCmd.Wait(); err != nil {
		return fmt.Errorf("gpg command failed: %w", err)
	}

	return nil
}

func readOSRelease() (string, string, error) {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return "", "", err
	}
	defer f.Close()

	values := map[string]string{}
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") || !strings.Contains(line, "=") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		key := strings.TrimSpace(parts[0])
		val := strings.Trim(strings.TrimSpace(parts[1]), `"`)
		values[key] = val
	}
	if err := scanner.Err(); err != nil {
		return "", "", err
	}

	return values["ID"], values["VERSION_CODENAME"], nil
}

func getFilebeatVersion() (string, error) {
	output, err := commandOutput("filebeat", "version")
	if err != nil {
		return "", err
	}

	fields := strings.Fields(output)
	if len(fields) < 3 {
		return "", fmt.Errorf("unexpected filebeat version output: %q", strings.TrimSpace(output))
	}

	return fields[2], nil
}

func isCommandAvailable(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func groupExists(group string) bool {
	cmd := exec.Command("getent", "group", group)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func mustRun(name string, args ...string) {
	if err := runCommand(name, args...); err != nil {
		errLog(err.Error())
		os.Exit(1)
	}
}

func runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		trimmed := strings.TrimSpace(string(output))
		if trimmed != "" {
			return fmt.Errorf("%s %s failed: %w: %s", name, strings.Join(args, " "), err, trimmed)
		}
		return fmt.Errorf("%s %s failed: %w", name, strings.Join(args, " "), err)
	}
	return nil
}

func commandOutput(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		trimmed := strings.TrimSpace(string(output))
		if trimmed != "" {
			return "", fmt.Errorf("%s %s failed: %w: %s", name, strings.Join(args, " "), err, trimmed)
		}
		return "", fmt.Errorf("%s %s failed: %w", name, strings.Join(args, " "), err)
	}
	return string(output), nil
}

func logLine(level, msg, color string) {
	fmt.Printf("%s[%s] [%s] %s%s\n", color, time.Now().Format("2006-01-02 15:04:05"), level, msg, colorReset)
}

func ok(msg string) {
	logLine("OK", msg, colorGreen)
}

func info(msg string) {
	logLine("INFO", msg, colorBlue)
}

func warn(msg string) {
	logLine("WARN", msg, colorYellow)
}

func errLog(msg string) {
	logLine("FAIL", msg, colorRed)
}

func skip(msg string) {
	logLine("SKIP", msg, colorYellow)
}
