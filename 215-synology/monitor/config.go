package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type config struct {
	ProxmoxEndpoint  string
	ProxmoxToken     string
	TelegramToken    string
	TelegramChatID   string
	TelegramAPIBase  string
	StatePath        string
	RunbookURL       string
	Interval         time.Duration
	FailureThreshold int
	Limits           thresholds
	Insecure         bool
}

type configError struct {
	Field  string
	Reason string
}

func (err configError) Error() string {
	return fmt.Sprintf("invalid %s: %s", err.Field, err.Reason)
}

func loadConfig() (config, error) {
	proxmoxEndpoint, err := credentialEnv("PROXMOX_ENDPOINT")
	if err != nil {
		return config{}, err
	}
	proxmoxToken, err := credentialEnv("PROXMOX_API_TOKEN")
	if err != nil {
		return config{}, err
	}
	telegramToken, err := credentialEnv("TELEGRAM_BOT_TOKEN")
	if err != nil {
		return config{}, err
	}
	telegramChatID, err := credentialEnv("TELEGRAM_CHAT_ID")
	if err != nil {
		return config{}, err
	}
	values := config{
		ProxmoxEndpoint: proxmoxEndpoint,
		ProxmoxToken:    proxmoxToken,
		TelegramToken:   telegramToken,
		TelegramChatID:  telegramChatID,
		TelegramAPIBase: envOrDefault("TELEGRAM_API_BASE", "https://api.telegram.org"),
		StatePath:       envOrDefault("MONITOR_STATE_PATH", "/data/state.json"),
		RunbookURL: envOrDefault(
			"MONITOR_RUNBOOK_URL",
			"https://github.com/qws941/terraform/blob/master/docs/runbooks/service-down.md",
		),
	}
	for field, value := range map[string]string{
		"PROXMOX_ENDPOINT":   values.ProxmoxEndpoint,
		"PROXMOX_API_TOKEN":  values.ProxmoxToken,
		"TELEGRAM_BOT_TOKEN": values.TelegramToken,
		"TELEGRAM_CHAT_ID":   values.TelegramChatID,
	} {
		if value == "" {
			return config{}, configError{Field: field, Reason: "must not be empty"}
		}
	}

	if values.Interval, err = durationEnv("MONITOR_INTERVAL", time.Minute); err != nil {
		return config{}, err
	}
	if values.FailureThreshold, err = intEnv("MONITOR_FAILURE_THRESHOLD", 3); err != nil {
		return config{}, err
	}
	if values.Limits.CPUPercent, err = floatEnv("MONITOR_CPU_PERCENT", 95); err != nil {
		return config{}, err
	}
	if values.Limits.MemoryPercent, err = floatEnv("MONITOR_MEMORY_PERCENT", 95); err != nil {
		return config{}, err
	}
	if values.Limits.DiskPercent, err = floatEnv("MONITOR_DISK_PERCENT", 90); err != nil {
		return config{}, err
	}
	if values.Insecure, err = boolEnv("PROXMOX_INSECURE", true); err != nil {
		return config{}, err
	}
	return values, nil
}

func credentialEnv(name string) (string, error) {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value, nil
	}
	path := strings.TrimSpace(os.Getenv(name + "_FILE"))
	if path == "" {
		return "", nil
	}
	content, err := os.ReadFile(path)
	if err != nil {
		return "", configError{Field: name + "_FILE", Reason: err.Error()}
	}
	return strings.TrimSpace(string(content)), nil
}

func envOrDefault(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func durationEnv(name string, fallback time.Duration) (time.Duration, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := time.ParseDuration(raw)
	if err != nil || value <= 0 {
		return 0, configError{Field: name, Reason: "must be a positive duration"}
	}
	return value, nil
}

func intEnv(name string, fallback int) (int, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		return 0, configError{Field: name, Reason: "must be a positive integer"}
	}
	return value, nil
}

func floatEnv(name string, fallback float64) (float64, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.ParseFloat(raw, 64)
	if err != nil || value <= 0 || value > 100 {
		return 0, configError{Field: name, Reason: "must be within (0, 100]"}
	}
	return value, nil
}

func boolEnv(name string, fallback bool) (bool, error) {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.ParseBool(raw)
	if err != nil {
		return false, configError{Field: name, Reason: "must be true or false"}
	}
	return value, nil
}
