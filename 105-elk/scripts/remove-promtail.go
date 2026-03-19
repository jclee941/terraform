//go:build remove_promtail
// +build remove_promtail

package main

import (
	"fmt"
	"os"
	"os/exec"
)

func main() {
	fmt.Println("=== Promtail Removal Script ===")
	fmt.Println("This will remove Promtail and its configurations.")

	if !checkPromtailExists() {
		fmt.Println("Promtail not found. Skipping.")
		os.Exit(0)
	}

	fmt.Println("Stopping Promtail service...")
	exec.Command("sudo", "systemctl", "stop", "promtail").Run()
	exec.Command("sudo", "systemctl", "disable", "promtail").Run()

	fmt.Println("Removing Promtail binary and config...")
	paths := []string{
		"/usr/local/bin/promtail",
		"/usr/bin/promtail",
		"/etc/promtail",
		"/etc/systemd/system/promtail.service",
	}
	for _, p := range paths {
		exec.Command("sudo", "rm", "-f", p).Run()
		exec.Command("sudo", "rm", "-rf", p).Run()
	}

	fmt.Println("Cleaning up logs...")
	exec.Command("sudo", "rm", "-rf", "/var/log/promtail").Run()

	fmt.Println("Reloading systemd...")
	exec.Command("sudo", "systemctl", "daemon-reload").Run()

	fmt.Println("")
	fmt.Println("=== Promtail Removed ===")
	fmt.Println("Install Filebeat: /opt/elk/scripts/install-filebeat.sh")
}

func checkPromtailExists() bool {
	// Check if promtail command exists
	cmd := exec.Command("command", "-v", "promtail")
	if cmd.Run() == nil {
		return true
	}

	// Check if promtail service is active
	cmd = exec.Command("systemctl", "is-active", "promtail")
	if cmd.Run() == nil {
		return true
	}

	return false
}
