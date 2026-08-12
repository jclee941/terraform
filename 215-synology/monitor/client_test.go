package main

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"
)

func TestProxmoxClient_fetches_cluster_resources_with_token(t *testing.T) {
	// Given
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if got := request.Header.Get("Authorization"); got != "PVEAPIToken=user@pam!monitor=secret" {
			t.Errorf("authorization = %q", got)
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(writer, `{"data":[{"id":"node/pve3","type":"node","node":"pve3","status":"online"}]}`)
	}))
	defer server.Close()
	client := newHTTPClient(false)

	// When
	resources, err := fetchResources(context.Background(), client, server.URL, "user@pam!monitor=secret")
	// Then
	if err != nil {
		t.Fatalf("fetchResources() error = %v", err)
	}
	if len(resources) != 1 || resources[0].ID != "node/pve3" {
		t.Fatalf("resources = %v", resources)
	}
}

func TestTelegramClient_posts_message_to_configured_chat(t *testing.T) {
	// Given
	requests := make(chan url.Values, 1)
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if err := request.ParseForm(); err != nil {
			t.Errorf("ParseForm() error = %v", err)
		}
		requests <- request.PostForm
		writer.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(writer, `{"ok":true,"result":{}}`)
	}))
	defer server.Close()
	client := newHTTPClient(false)

	// When
	err := sendTelegram(context.Background(), client, server.URL, "token", "chat-1", "alert text")
	// Then
	if err != nil {
		t.Fatalf("sendTelegram() error = %v", err)
	}
	select {
	case form := <-requests:
		if form.Get("chat_id") != "chat-1" || form.Get("text") != "alert text" {
			t.Fatalf("form = %v", form)
		}
	case <-time.After(time.Second):
		t.Fatal("telegram request not received")
	}
}
