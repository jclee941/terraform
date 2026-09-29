package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadConfig_reads_credentials_from_secret_files(t *testing.T) {
	// Given
	secretDir := t.TempDir()
	secrets := map[string]string{
		"PROXMOX_ENDPOINT":   "https://proxmox.example.test:8006",
		"PROXMOX_API_TOKEN":  "user@pam!monitor=secret",
		"TELEGRAM_BOT_TOKEN": "telegram-token",
		"TELEGRAM_CHAT_ID":   "chat-1",
	}
	for name, value := range secrets {
		path := filepath.Join(secretDir, name)
		if err := os.WriteFile(path, []byte(value+"\n"), 0o600); err != nil {
			t.Fatalf("write %s: %v", name, err)
		}
		t.Setenv(name, "")
		t.Setenv(name+"_FILE", path)
	}

	// When
	settings, err := loadConfig()
	// Then
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	if settings.ProxmoxEndpoint != secrets["PROXMOX_ENDPOINT"] {
		t.Fatalf("ProxmoxEndpoint = %q", settings.ProxmoxEndpoint)
	}
	if settings.ProxmoxToken != secrets["PROXMOX_API_TOKEN"] {
		t.Fatalf("ProxmoxToken = %q", settings.ProxmoxToken)
	}
	if settings.TelegramToken != secrets["TELEGRAM_BOT_TOKEN"] {
		t.Fatalf("TelegramToken = %q", settings.TelegramToken)
	}
	if settings.TelegramChatID != secrets["TELEGRAM_CHAT_ID"] {
		t.Fatalf("TelegramChatID = %q", settings.TelegramChatID)
	}
}
