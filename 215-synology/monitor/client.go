package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const maxResponseBytes = 8 << 20

type remoteError struct {
	Service string
	Status  string
	Detail  string
}

func (err remoteError) Error() string {
	if err.Detail == "" {
		return fmt.Sprintf("%s returned %s", err.Service, err.Status)
	}
	return fmt.Sprintf("%s returned %s: %s", err.Service, err.Status, err.Detail)
}

func newHTTPClient(insecure bool) *http.Client {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.MaxIdleConns = 20
	transport.MaxIdleConnsPerHost = 10
	transport.IdleConnTimeout = 90 * time.Second
	transport.TLSClientConfig = &tls.Config{MinVersion: tls.VersionTLS12, InsecureSkipVerify: insecure}
	return &http.Client{Transport: transport, Timeout: 15 * time.Second}
}

func fetchResources(ctx context.Context, client *http.Client, endpoint, token string) (resources []resource, resultErr error) {
	requestURL := strings.TrimRight(endpoint, "/") + "/api2/json/cluster/resources"
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL, nil)
	if err != nil {
		return nil, fmt.Errorf("build Proxmox request: %w", err)
	}
	request.Header.Set("Authorization", "PVEAPIToken="+token)
	response, err := client.Do(request)
	if err != nil {
		return nil, fmt.Errorf("fetch Proxmox resources: %w", err)
	}
	defer func() {
		resultErr = errors.Join(resultErr, response.Body.Close())
	}()
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return nil, remoteError{Service: "Proxmox API", Status: response.Status}
	}
	var payload clusterResourcesResponse
	if err := json.NewDecoder(io.LimitReader(response.Body, maxResponseBytes)).Decode(&payload); err != nil {
		return nil, fmt.Errorf("decode Proxmox resources: %w", err)
	}
	return payload.Data, nil
}

type telegramResponse struct {
	OK          bool   `json:"ok"`
	Description string `json:"description"`
}

func sendTelegram(ctx context.Context, client *http.Client, apiBase, token, chatID, text string) (resultErr error) {
	form := url.Values{
		"chat_id":                  {chatID},
		"text":                     {text},
		"disable_web_page_preview": {"true"},
	}
	requestURL := strings.TrimRight(apiBase, "/") + "/bot" + token + "/sendMessage"
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, requestURL, strings.NewReader(form.Encode()))
	if err != nil {
		return fmt.Errorf("build Telegram request: %w", err)
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	response, err := client.Do(request)
	if err != nil {
		return fmt.Errorf("send Telegram message: %w", err)
	}
	defer func() {
		resultErr = errors.Join(resultErr, response.Body.Close())
	}()
	var payload telegramResponse
	if err := json.NewDecoder(io.LimitReader(response.Body, maxResponseBytes)).Decode(&payload); err != nil {
		return fmt.Errorf("decode Telegram response: %w", err)
	}
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices || !payload.OK {
		return remoteError{Service: "Telegram API", Status: response.Status, Detail: payload.Description}
	}
	return nil
}
