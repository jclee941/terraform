package main

import (
	"bytes"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
)

// ANSI colors (match sync-vault-secrets.go)
const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	blue   = "\033[0;34m"
	cyan   = "\033[0;36m"
	bold   = "\033[1m"
	nc     = "\033[0m"
)

var httpClient = &http.Client{
	Timeout: 10 * time.Second,
	Transport: &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, //nolint:gosec // homelab self-signed certs
	},
}

// --- Types ---

type fieldSpec struct {
	label string // display label / map key
	opRef string // op:// reference
}

type serviceCheck struct {
	name     string
	fields   []fieldSpec
	validate func(vals map[string]string) (bool, string)
}

type fieldResult struct {
	label  string
	status string // "pass", "fail", "skip", "placeholder"
	detail string
}

type serviceResult struct {
	name       string
	fields     []fieldResult
	apiStatus  string // "pass", "fail", "skip", ""
	apiDetail  string
	hasAPITest bool
}

// --- Helpers ---

func opRead(ref string) (string, error) {
	cmd := exec.Command("op", "read", ref)
	var out, stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("%s", strings.TrimSpace(stderr.String()))
	}
	return strings.TrimRight(out.String(), "\n"), nil
}

func maskValue(v string) string {
	l := len(v)
	if l <= 4 {
		return "****"
	}
	if l <= 8 {
		return v[:2] + "****"
	}
	return v[:4] + "..." + v[l-2:]
}

func isPlaceholder(v string) bool {
	lower := strings.ToLower(strings.TrimSpace(v))
	return lower == "" || lower == "placeholder" || strings.HasPrefix(lower, "placeholder") || lower == "bootstrap"
}

func commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func runSilent(name string, args ...string) bool {
	cmd := exec.Command(name, args...)
	cmd.Stdout = nil
	cmd.Stderr = nil
	return cmd.Run() == nil
}

func httpGet(url string, headers map[string]string) (int, []byte, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("User-Agent", "validate-vault-secrets/1.0")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := httpClient.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, body, nil
}

func httpPost(url string, headers map[string]string) (int, []byte, error) {
	req, err := http.NewRequest("POST", url, nil)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("User-Agent", "validate-vault-secrets/1.0")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := httpClient.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, body, nil
}

func b64(s string) string {
	return base64.StdEncoding.EncodeToString([]byte(s))
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}

// --- Service Validators ---

func validateGitHub(vals map[string]string) (bool, string) {
	status, body, err := httpGet("https://api.github.com/user", map[string]string{
		"Authorization": "token " + vals["password"],
	})
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		var data map[string]interface{}
		if json.Unmarshal(body, &data) == nil {
			if login, ok := data["login"].(string); ok {
				return true, fmt.Sprintf("user=%s", login)
			}
		}
		return true, "authenticated"
	}
	return false, fmt.Sprintf("HTTP %d", status)
}

func validateCloudflare(vals map[string]string) (bool, string) {
	// Global API Key uses X-Auth-Email + X-Auth-Key (not Bearer token)
	status, body, err := httpGet("https://api.cloudflare.com/client/v4/user", map[string]string{
		"X-Auth-Email": vals["email"],
		"X-Auth-Key":   vals["password"],
	})
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		var data struct {
			Success bool `json:"success"`
			Result  struct {
				Email string `json:"email"`
			} `json:"result"`
		}
		if json.Unmarshal(body, &data) == nil && data.Success {
			return true, fmt.Sprintf("email=%s", data.Result.Email)
		}
	}
	return false, fmt.Sprintf("HTTP %d — %s", status, truncate(string(body), 80))
}



func validateELK(vals map[string]string) (bool, string) {
	clientID := vals["cf_access_client_id"]
	clientSecret := vals["cf_access_client_secret"]
	password := vals["elastic_password"]

	if clientID == "" || clientSecret == "" {
		return false, "missing CF Access credentials — field read failed"
	}

	status, body, err := httpGet("https://elk.jclee.me/_security/_authenticate", map[string]string{
		"CF-Access-Client-Id":     clientID,
		"CF-Access-Client-Secret": clientSecret,
		"Authorization":           "Basic " + b64("elastic:"+password),
	})
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		var data struct {
			Username string `json:"username"`
		}
		if json.Unmarshal(body, &data) == nil && data.Username != "" {
			return true, fmt.Sprintf("user=%s", data.Username)
		}
		return true, "authenticated"
	}
	return false, fmt.Sprintf("HTTP %d", status)
}


func validateGoogleGemini(vals map[string]string) (bool, string) {
	status, _, err := httpGet(
		"https://generativelanguage.googleapis.com/v1beta/models?key="+vals["password"],
		nil,
	)
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		return true, "API key valid"
	}
	return false, fmt.Sprintf("HTTP %d", status)
}

func validateGrafana(vals map[string]string) (bool, string) {
	status, body, err := httpGet("http://192.168.50.108:3000/api/org", map[string]string{
		"Authorization": "Bearer " + vals["service_account_token"],
	})
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		var data struct {
			Name string `json:"name"`
		}
		if json.Unmarshal(body, &data) == nil && data.Name != "" {
			return true, fmt.Sprintf("org=%s", data.Name)
		}
		return true, "authenticated"
	}
	return false, fmt.Sprintf("HTTP %d", status)
}

func validateN8N(vals map[string]string) (bool, string) {
	status, body, err := httpGet("http://192.168.50.112:5678/api/v1/workflows?limit=1", map[string]string{
		"X-N8N-API-KEY": vals["api_key"],
	})
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		var data struct {
			Count int `json:"count"`
		}
		if json.Unmarshal(body, &data) == nil {
			return true, fmt.Sprintf("workflows=%d", data.Count)
		}
		return true, "authenticated"
	}
	return false, fmt.Sprintf("HTTP %d", status)
}

func validateProxmox(vals map[string]string) (bool, string) {
	status, body, err := httpGet("https://192.168.50.100:8006/api2/json/version", map[string]string{
		"Authorization": "PVEAPIToken=" + vals["api_token_value"],
	})
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		var data struct {
			Data struct {
				Version string `json:"version"`
			} `json:"data"`
		}
		if json.Unmarshal(body, &data) == nil && data.Data.Version != "" {
			return true, fmt.Sprintf("pve=%s", data.Data.Version)
		}
		return true, "authenticated"
	}
	return false, fmt.Sprintf("HTTP %d", status)
}

func validateSlack(vals map[string]string) (bool, string) {
	token := vals["opencode_bot_token"]
	if token == "" {
		return false, "bot token missing"
	}
	status, body, err := httpPost("https://slack.com/api/auth.test", map[string]string{
		"Authorization": "Bearer " + token,
	})
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		var data struct {
			OK    bool   `json:"ok"`
			Team  string `json:"team"`
			User  string `json:"user"`
			Error string `json:"error"`
		}
		if json.Unmarshal(body, &data) == nil {
			if data.OK {
				return true, fmt.Sprintf("bot=%s team=%s", data.User, data.Team)
			}
			return false, data.Error
		}
	}
	return false, fmt.Sprintf("HTTP %d", status)
}

func validateSupabase(vals map[string]string) (bool, string) {
	url := strings.TrimRight(vals["url"], "/")
	if url == "" {
		return false, "url missing"
	}
	status, _, err := httpGet(url+"/rest/v1/", map[string]string{
		"apikey":        vals["anon_key"],
		"Authorization": "Bearer " + vals["service_key"],
	})
	if err != nil {
		return false, fmt.Sprintf("connection: %v", err)
	}
	if status == 200 {
		return true, "authenticated"
	}
	return false, fmt.Sprintf("HTTP %d", status)
}

// --- Service Definitions ---

var services = []serviceCheck{
	// --- API-validatable services ---
	{
		name: "github",
		fields: []fieldSpec{
			{"password", "op://homelab/github/password"},
		},
		validate: validateGitHub,
	},
	{
		name: "cloudflare",
		fields: []fieldSpec{
			{"password", "op://homelab/cloudflare/password"},
			{"api_key", "op://homelab/cloudflare/secrets/api_key"},
			{"email", "op://homelab/cloudflare/secrets/email"},
			{"account_id", "op://homelab/cloudflare/secrets/account_id"},
			{"zone_id", "op://homelab/cloudflare/secrets/zone_id"},
		},
		validate: validateCloudflare,
	},

	{
		name: "elk",
		fields: []fieldSpec{
			{"elastic_password", "op://homelab/elk/secrets/elastic_password"},
			{"kibana_password", "op://homelab/elk/secrets/kibana_password"},
			{"apikey_resume_cfw", "op://homelab/elk/apikey_resume_cfw"},
			{"apikey_resume_gha", "op://homelab/elk/apikey_resume_gha"},
			{"cf_access_client_id", "op://homelab/elk/cf_access_client_id"},
			{"cf_access_client_secret", "op://homelab/elk/cf_access_client_secret"},
		},
		validate: validateELK,
	},
	{
		name: "google-gemini",
		fields: []fieldSpec{
			{"password", "op://homelab/google-gemini/password"},
		},
		validate: validateGoogleGemini,
	},
	{
		name: "grafana",
		fields: []fieldSpec{
			{"service_account_token", "op://homelab/grafana/secrets/service_account_token"},
			{"admin_password", "op://homelab/grafana/secrets/admin_password"},
		},
		validate: validateGrafana,
	},
	{
		name: "n8n",
		fields: []fieldSpec{
			{"api_key", "op://homelab/n8n/secrets/api_key"},
		},
		validate: validateN8N,
	},
	{
		name: "proxmox",
		fields: []fieldSpec{
			{"api_token_value", "op://homelab/proxmox/secrets/api_token_value"},
			{"ssh_private_key", "op://homelab/proxmox/secrets/ssh_private_key"},
		},
		validate: validateProxmox,
	},
	{
		name: "slack",
		fields: []fieldSpec{
			{"opencode_bot_token", "op://homelab/slack/opencode_bot_token"},
			{"opencode_user_token", "op://homelab/slack/opencode_user_token"},
			{"opencode_app_token", "op://homelab/slack/opencode_app_token"},
			{"slack_mcp_xoxp_token", "op://homelab/slack/secrets/slack_mcp_xoxp_token"},
		},
		validate: validateSlack,
	},
	{
		name: "supabase",
		fields: []fieldSpec{
			{"url", "op://homelab/supabase/secrets/url"},
			{"anon_key", "op://homelab/supabase/secrets/anon_key"},
			{"service_key", "op://homelab/supabase/secrets/service_key"},
			{"db_password", "op://homelab/supabase/secrets/db_password"},
		},
		validate: validateSupabase,
	},
	// --- Presence-check only (no public API) ---
	{
		name: "mcphub",
		fields: []fieldSpec{
			{"password", "op://homelab/mcphub/password"},
		},
	},
	{
		name: "safetywallet",
		fields: []fieldSpec{
			{"username", "op://homelab/safetywallet/username"},
			{"password", "op://homelab/safetywallet/password"},
		},
	},
	// --- Known placeholder services ---
	{
		name: "archon",
		fields: []fieldSpec{
			{"anthropic_api_key", "op://homelab/archon/secrets/anthropic_api_key"},
			{"openai_api_key", "op://homelab/archon/secrets/openai_api_key"},
		},
	},

	{
		name: "splunk",
		fields: []fieldSpec{
			{"username", "op://homelab/splunk/secrets/username"},
			{"host", "op://homelab/splunk/secrets/host"},
		},
	},
}

// --- Runner ---

func runChecks(checks []serviceCheck, auditOnly bool, filter string, verbose bool) []serviceResult {
	var results []serviceResult

	for _, svc := range checks {
		if filter != "" && !strings.EqualFold(svc.name, filter) {
			continue
		}

		result := serviceResult{
			name:       svc.name,
			hasAPITest: svc.validate != nil,
		}

		// Phase 1: Read all fields from 1Password (concurrent)
		vals := make(map[string]string)
		allPresent := true
		fieldResults := make([]fieldResult, len(svc.fields))
		var mu sync.Mutex
		var wg sync.WaitGroup

		for i, f := range svc.fields {
			wg.Add(1)
			go func(idx int, fs fieldSpec) {
				defer wg.Done()
				val, err := opRead(fs.opRef)
				fr := fieldResult{label: fs.label}

				if err != nil {
					fr.status = "fail"
					fr.detail = fmt.Sprintf("op read failed: %s", err)
					mu.Lock()
					allPresent = false
					mu.Unlock()
				} else if isPlaceholder(val) {
					fr.status = "placeholder"
					fr.detail = fmt.Sprintf("placeholder (%s)", maskValue(val))
					mu.Lock()
					allPresent = false
					mu.Unlock()
				} else {
					fr.status = "pass"
					if verbose {
						fr.detail = fmt.Sprintf("present (%d chars) %s", len(val), maskValue(val))
					} else {
						fr.detail = fmt.Sprintf("present (%d chars)", len(val))
					}
					mu.Lock()
					vals[fs.label] = val
					mu.Unlock()
				}

				fieldResults[idx] = fr
			}(i, f)
		}
		wg.Wait()
		result.fields = fieldResults

		// Phase 2: API validation (skip in audit mode or if validator absent)
		if svc.validate != nil {
			if auditOnly {
				result.apiStatus = "skip"
				result.apiDetail = "audit mode — skipped"
			} else if !allPresent {
				result.apiStatus = "skip"
				result.apiDetail = "skipped — missing fields"
			} else {
				ok, detail := svc.validate(vals)
				if ok {
					result.apiStatus = "pass"
				} else {
					result.apiStatus = "fail"
				}
				result.apiDetail = detail
			}
		}

		results = append(results, result)
	}

	return results
}

// --- Output ---

func printResults(results []serviceResult) {
	totalFields := 0
	passFields := 0
	failFields := 0
	skipFields := 0
	placeholderFields := 0

	apiPass := 0
	apiFail := 0
	apiSkip := 0
	apiTotal := 0

	for _, r := range results {
		line := strings.Repeat("─", 40-len(r.name))
		fmt.Printf("\n%s── %s %s%s\n", bold, r.name, line, nc)

		for _, f := range r.fields {
			totalFields++
			label := fmt.Sprintf("%-28s", f.label)

			switch f.status {
			case "pass":
				passFields++
				fmt.Printf("  %s[PASS]%s %s %s\n", green, nc, label, f.detail)
			case "fail":
				failFields++
				fmt.Printf("  %s[FAIL]%s %s %s\n", red, nc, label, f.detail)
			case "placeholder":
				placeholderFields++
				fmt.Printf("  %s[HOLD]%s %s %s\n", yellow, nc, label, f.detail)
			case "skip":
				skipFields++
				fmt.Printf("  %s[SKIP]%s %s %s\n", blue, nc, label, f.detail)
			}
		}

		if r.hasAPITest {
			apiTotal++
			label := fmt.Sprintf("%-28s", "API validation")
			switch r.apiStatus {
			case "pass":
				apiPass++
				fmt.Printf("  %s[API✓]%s %s %s\n", green, nc, label, r.apiDetail)
			case "fail":
				apiFail++
				fmt.Printf("  %s[API✗]%s %s %s\n", red, nc, label, r.apiDetail)
			case "skip":
				apiSkip++
				fmt.Printf("  %s[API–]%s %s %s\n", yellow, nc, label, r.apiDetail)
			}
		}
	}

	// Summary
	fmt.Printf("\n%s── Summary %s%s\n", bold, strings.Repeat("─", 30), nc)
	fmt.Printf("  Services: %d\n", len(results))
	fmt.Printf("  Fields:   %d total — %s%d pass%s, %s%d fail%s, %s%d placeholder%s, %s%d skip%s\n",
		totalFields,
		green, passFields, nc,
		red, failFields, nc,
		yellow, placeholderFields, nc,
		blue, skipFields, nc,
	)
	if apiTotal > 0 {
		fmt.Printf("  APIs:     %d total — %s%d pass%s, %s%d fail%s, %s%d skip%s\n",
			apiTotal,
			green, apiPass, nc,
			red, apiFail, nc,
			yellow, apiSkip, nc,
		)
	}

	if failFields > 0 || apiFail > 0 {
		fmt.Printf("\n  %sResult: FAIL%s — %d field error(s), %d API error(s)\n", red, nc, failFields, apiFail)
	} else if placeholderFields > 0 {
		fmt.Printf("\n  %sResult: WARN%s — all reads OK but %d placeholder(s) found\n", yellow, nc, placeholderFields)
	} else {
		fmt.Printf("\n  %sResult: PASS%s — all secrets valid\n", green, nc)
	}
}

// --- Main ---

func usage() {
	fmt.Fprintf(os.Stdout, `Usage: validate-vault-secrets [OPTIONS]

Validate all secrets in the 1Password homelab vault.

Phase 1 reads every op:// reference and checks presence.
Phase 2 calls live service APIs to verify authentication.

Options:
  --audit        Read op:// refs only, skip API validation
  --filter NAME  Validate a single service (e.g. --filter github)
  --verbose      Show masked secret values
  -h, --help     Show this help

Environment:
  OP_SERVICE_ACCOUNT_TOKEN  1Password service account token (required)

Services validated (%d total):
`, len(services))
	for _, s := range services {
		api := "  "
		if s.validate != nil {
			api = "→ "
		}
		fmt.Fprintf(os.Stdout, "  %s%-16s  %d field(s)\n", api, s.name, len(s.fields))
	}
	fmt.Fprintf(os.Stdout, "\n  → = has live API validation\n")
}

func main() {
	var auditOnly, verbose, help bool
	var filter string

	flag.BoolVar(&auditOnly, "audit", false, "Read op:// refs only, skip API validation")
	flag.StringVar(&filter, "filter", "", "Validate a single service")
	flag.BoolVar(&verbose, "verbose", false, "Show masked secret values")
	flag.BoolVar(&help, "help", false, "Show this help")
	flag.BoolVar(&help, "h", false, "Show this help")

	flag.Usage = usage
	flag.Parse()

	if help {
		usage()
		os.Exit(0)
	}

	if flag.NArg() > 0 {
		fmt.Fprintf(os.Stderr, "%sUnknown argument: %s%s\n", red, flag.Arg(0), nc)
		usage()
		os.Exit(1)
	}

	// --- Dependency check ---
	if !commandExists("op") {
		fmt.Fprintf(os.Stderr, "%sop CLI required. Install: https://developer.1password.com/docs/cli/get-started/%s\n", red, nc)
		os.Exit(1)
	}

	if os.Getenv("OP_SERVICE_ACCOUNT_TOKEN") == "" {
		fmt.Fprintf(os.Stderr, "%sOP_SERVICE_ACCOUNT_TOKEN not set%s\n", red, nc)
		fmt.Fprintf(os.Stderr, "Set via: export OP_SERVICE_ACCOUNT_TOKEN='ops_xxx'\n")
		os.Exit(1)
	}

	if !runSilent("op", "whoami") {
		fmt.Fprintf(os.Stderr, "%s1Password authentication failed%s\n", red, nc)
		fmt.Fprintf(os.Stderr, "Check OP_SERVICE_ACCOUNT_TOKEN\n")
		os.Exit(1)
	}

	// --- Filter validation ---
	if filter != "" {
		found := false
		for _, s := range services {
			if strings.EqualFold(s.name, filter) {
				found = true
				break
			}
		}
		if !found {
			fmt.Fprintf(os.Stderr, "%sUnknown service: %s%s\n", red, filter, nc)
			fmt.Fprintf(os.Stderr, "Available: ")
			names := make([]string, len(services))
			for i, s := range services {
				names[i] = s.name
			}
			fmt.Fprintf(os.Stderr, "%s\n", strings.Join(names, ", "))
			os.Exit(1)
		}
	}

	// --- Header ---
	mode := "full validation"
	if auditOnly {
		mode = "audit (op refs only)"
	}
	fmt.Printf("%s1Password Vault Secret Validation%s\n", bold, nc)
	fmt.Printf("Vault:  homelab\n")
	fmt.Printf("Mode:   %s\n", mode)
	if filter != "" {
		fmt.Printf("Filter: %s\n", filter)
	}

	// --- Run ---
	results := runChecks(services, auditOnly, filter, verbose)
	printResults(results)

	// --- Exit code ---
	for _, r := range results {
		for _, f := range r.fields {
			if f.status == "fail" {
				os.Exit(1)
			}
		}
		if r.apiStatus == "fail" {
			os.Exit(1)
		}
	}
}
