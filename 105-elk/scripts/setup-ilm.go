//go:build setup_ilm
// +build setup_ilm

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

func main() {
	esHost := getEnv("ES_HOST", "http://localhost:9200")
	esUser := getEnv("ES_USER", "elastic")
	esPass := os.Getenv("ELASTIC_PASSWORD")
	if esPass == "" {
		fmt.Println("ELASTIC_PASSWORD must be set")
		os.Exit(1)
	}

	fmt.Println("=== Setting up ELK ILM Policies and Index Templates ===")

	// --- ILM Policies ---
	policies := []struct {
		name      string
		retention string
	}{
		{"homelab-logs-30d", "30d"},
		{"homelab-logs-critical-90d", "90d"},
		{"homelab-logs-ephemeral-7d", "7d"},
	}

	for _, p := range policies {
		fmt.Printf("Creating ILM policy: %s (delete after %s)...\n", p.name, p.retention)
		url := fmt.Sprintf("%s/_ilm/policy/%s", esHost, p.name)
		body := fmt.Sprintf(`{"policy":{"phases":{"hot":{"actions":{"set_priority":{"priority":100}}},"delete":{"min_age":"%s","actions":{"delete":{}}}}}`, p.retention)
		putRequest(url, esUser, esPass, body)
		fmt.Println("")
	}

	// --- Index Templates ---
	createIndexTemplate(esHost, esUser, esPass, "logs-template", []string{"logs-*"}, "homelab-logs-30d", 200)
	createIndexTemplate(esHost, esUser, esPass, "logs-critical", []string{"logs-archon-*", "logs-elk-*", "logs-supabase-*", "logs-grafana-*"}, "homelab-logs-critical-90d", 300)
	createIndexTemplate(esHost, esUser, esPass, "logs-ephemeral", []string{"logs-unknown-*", "logs-debug-*", "logs-runner-*"}, "homelab-logs-ephemeral-7d", 250)

	// --- Verify ---
	fmt.Println("=== Verification ===")
	fmt.Println("ILM policies:")
	verifyILM(esHost, esUser, esPass)
	fmt.Println("")
	fmt.Println("Index templates:")
	verifyTemplates(esHost, esUser, esPass)
	fmt.Println("")

	fmt.Println("=== ILM Setup Complete ===")
	fmt.Println("Policies: homelab-logs-30d, homelab-logs-critical-90d, homelab-logs-ephemeral-7d")
	fmt.Println("Templates: logs-template (p200), logs-critical (p300), logs-ephemeral (p250)")
	fmt.Println("Index pattern: logs-{service}-YYYY.MM.dd")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func putRequest(url, user, pass, body string) {
	req, err := http.NewRequest("PUT", url, strings.NewReader(body))
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	req.SetBasicAuth(user, pass)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	defer resp.Body.Close()
	io.Copy(os.Stdout, resp.Body)
}

func createIndexTemplate(host, user, pass, name string, patterns []string, ilmPolicy string, priority int) {
	fmt.Printf("Creating index template: %s (priority %d, %s)...\n", name, priority, strings.TrimSuffix(strings.TrimPrefix(ilmPolicy, "homelab-logs-"), "-30d:-90d:-7d"))

	url := fmt.Sprintf("%s/_index_template/%s", host, name)
	patternsJSON, _ := json.Marshal(patterns)
	body := fmt.Sprintf(`{"index_patterns":%s,"template":{"settings":{"number_of_shards":1,"number_of_replicas":0,"index.lifecycle.name":"%s"}},"priority":%d}`, string(patternsJSON), ilmPolicy, priority)
	putRequest(url, user, pass, body)
	fmt.Println("")
}

func verifyILM(host, user, pass string) {
	url := fmt.Sprintf("%s/_ilm/policy/homelab-logs-*", host)
	getAndFormatJSON(host, user, pass, url)
}

func verifyTemplates(host, user, pass string) {
	url := fmt.Sprintf("%s/_index_template/logs-*", host)
	resp, err := requestJSON(host, user, pass, url)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	defer resp.Body.Close()

	var data struct {
		IndexTemplates []struct {
			Name          string   `json:"name"`
			IndexPatterns []string `json:"index_patterns"`
			Priority      int      `json:"priority"`
		} `json:"index_templates"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		fmt.Println("Error parsing response:", err)
		return
	}
	for _, t := range data.IndexTemplates {
		fmt.Printf("  %s: patterns=%v, priority=%d\n", t.Name, t.IndexPatterns, t.Priority)
	}
}

func requestJSON(host, user, pass, url string) (*http.Response, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.SetBasicAuth(user, pass)
	return http.DefaultClient.Do(req)
}

func getAndFormatJSON(host, user, pass, url string) {
	resp, err := requestJSON(host, user, pass, url)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	defer resp.Body.Close()

	var prettyJSON bytes.Buffer
	if err := json.Indent(&prettyJSON, getBody(resp), "", "  "); err != nil {
		fmt.Println("Error formatting JSON:", err)
		return
	}
	fmt.Print(prettyJSON.String())
}

func getBody(resp *http.Response) []byte {
	body, _ := io.ReadAll(resp.Body)
	return body
}
