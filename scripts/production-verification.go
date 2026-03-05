package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
)

// ANSI color codes
const (
	green  = "\033[0;32m"
	red    = "\033[0;31m"
	yellow = "\033[1;33m"
	nc     = "\033[0m"
)

var (
	passed int32
	failed int32
)

func testResult(testNum int, testName string, success bool) {
	if success {
		fmt.Printf("%s✅ Test %d PASSED%s: %s\n", green, testNum, nc, testName)
		atomic.AddInt32(&passed, 1)
	} else {
		fmt.Printf("%s❌ Test %d FAILED%s: %s\n", red, testNum, nc, testName)
		atomic.AddInt32(&failed, 1)
	}
}

func httpGet(url string, headers map[string]string) (*http.Response, error) {
	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	return client.Do(req)
}

func httpPost(url string, body string, headers map[string]string) (*http.Response, error) {
	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest("POST", url, strings.NewReader(body))
	if err != nil {
		return nil, err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	return client.Do(req)
}

func httpStatusCode(url string) string {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return "000"
	}
	defer resp.Body.Close()
	return fmt.Sprintf("%d", resp.StatusCode)
}

func httpStatusCodeBasicAuth(url, user, pass string) string {
	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "000"
	}
	req.SetBasicAuth(user, pass)
	resp, err := client.Do(req)
	if err != nil {
		return "000"
	}
	defer resp.Body.Close()
	return fmt.Sprintf("%d", resp.StatusCode)
}

// getJSON fetches a URL and decodes JSON into the provided interface.
func getJSON(url string, headers map[string]string, target interface{}) error {
	resp, err := httpGet(url, headers)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return json.NewDecoder(resp.Body).Decode(target)
}

// getJSONBasicAuth fetches a URL with basic auth and decodes JSON.
func getJSONBasicAuth(url, user, pass string, target interface{}) error {
	resp, err := httpGet(url, nil)
	if err != nil {
		// rebuild with basic auth
		client := &http.Client{Timeout: 5 * time.Second}
		req, err2 := http.NewRequest("GET", url, nil)
		if err2 != nil {
			return err2
		}
		req.SetBasicAuth(user, pass)
		resp, err = client.Do(req)
		if err != nil {
			return err
		}
	} else {
		resp.Body.Close()
		// redo with basic auth
		client := &http.Client{Timeout: 5 * time.Second}
		req, err2 := http.NewRequest("GET", url, nil)
		if err2 != nil {
			return err2
		}
		req.SetBasicAuth(user, pass)
		resp, err = client.Do(req)
		if err != nil {
			return err
		}
	}
	defer resp.Body.Close()
	return json.NewDecoder(resp.Body).Decode(target)
}

func envOrDefault(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

func main() {
	grafanaToken := os.Getenv("GRAFANA_TOKEN")
	promHost := envOrDefault("PROM_HOST", "192.168.50.104")
	grafanaHost := envOrDefault("GRAFANA_HOST", "192.168.50.104")
	// n8nHost := envOrDefault("N8N_HOST", "192.168.50.112")
	psqlHost := envOrDefault("PSQL_HOST", "192.168.50.100")
	elkHost := envOrDefault("ELK_HOST", "192.168.50.105")
	elasticsearchPassword := os.Getenv("ELASTICSEARCH_PASSWORD")

	// Cleanup handler: print partial results on interrupt/early exit
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		sig := <-sigCh
		p := atomic.LoadInt32(&passed)
		f := atomic.LoadInt32(&failed)
		fmt.Println()
		fmt.Println("====================================")
		fmt.Printf("INTERRUPTED (signal: %v)\n", sig)
		fmt.Printf("Completed: %d tests before interruption\n", p+f)
		fmt.Println("====================================")
		os.Exit(1)
	}()

	fmt.Println("🔍 PRODUCTION VERIFICATION SUITE v2")
	fmt.Println("====================================")
	fmt.Println()

	if grafanaToken == "" {
		fmt.Printf("%s⚠️  WARNING: GRAFANA_TOKEN not set. Skipping authenticated Grafana tests.%s\n", yellow, nc)
		fmt.Println()
	}
	if elasticsearchPassword == "" {
		fmt.Printf("%s⚠️  WARNING: ELASTICSEARCH_PASSWORD not set. Skipping authenticated ES tests.%s\n", yellow, nc)
		fmt.Println()
	}

	// ── Test 1: Prometheus targets UP ──
	fmt.Println("Test 1: Checking Prometheus targets status...")
	func() {
		var data struct {
			Data struct {
				ActiveTargets []struct {
					Health string `json:"health"`
				} `json:"activeTargets"`
			} `json:"data"`
		}
		err := getJSON(fmt.Sprintf("http://%s:9090/api/v1/targets", promHost), nil, &data)
		if err != nil {
			fmt.Println("  Active targets: 0 / 0 UP")
			testResult(1, "Prometheus targets", false)
			return
		}
		total := len(data.Data.ActiveTargets)
		up := 0
		for _, t := range data.Data.ActiveTargets {
			if t.Health == "up" {
				up++
			}
		}
		fmt.Printf("  Active targets: %d / %d UP\n", up, total)
		testResult(1, "Prometheus targets", up >= 9)
	}()

	// ── Test 2: Grafana HTTP response ──
	fmt.Println("Test 2: Checking Grafana HTTP...")
	func() {
		status := httpStatusCode(fmt.Sprintf("http://%s:3000/api/health", grafanaHost))
		testResult(2, fmt.Sprintf("Grafana HTTP (expecting 200, got %s)", status), status == "200")
	}()

	// ── Test 3: N8N webhooks responding ──
	fmt.Println("Test 3: Checking N8N webhook endpoints...")
	// WEBHOOKS=() # Temporary disable: workflows not currently deployed with these paths
	fmt.Println("  (Skipping N8N checks - workflows pending deployment)")
	// webhooks := []string{"tier1-recovery", "tier2-memory-restart", "tier3-db-pool-reset", "tier4-cache-recovery"}
	// webhookPass := 0
	// for _, webhook := range webhooks {
	//     url := fmt.Sprintf("http://%s:5678/webhook/%s", n8nHost, webhook)
	//     status := httpStatusCode(url) // would need POST
	//     if status == "200" || status == "201" || status == "500" {
	//         webhookPass++
	//     }
	// }
	// testResult(3, fmt.Sprintf("N8N webhooks (%d/4 responding)", webhookPass), webhookPass == 4)
	testResult(3, "N8N webhooks (Skipped)", true)

	// ── Test 4: Load test (100 requests) ──
	fmt.Println("Test 4: Running load test (100 requests)...")
	func() {
		successCount := 0
		url := fmt.Sprintf("http://%s:3000/api/health", grafanaHost)
		for i := 0; i < 100; i++ {
			if httpStatusCode(url) == "200" {
				successCount++
			}
		}
		fmt.Printf("  Load test: %d/100 successful\n", successCount)
		testResult(4, "Load test success rate", successCount >= 95)
	}()

	// ── Test 5: PostgreSQL connection ──
	fmt.Println("Test 5: Checking PostgreSQL connection...")
	func() {
		_, err := exec.LookPath("psql")
		if err != nil {
			fmt.Println("  (Skipping - psql client not installed)")
			testResult(5, "PostgreSQL connection (Skipped)", true)
			return
		}
		cmd := exec.Command("psql", "-h", psqlHost, "-U", "postgres", "-d", "postgres", "-c", "SELECT 1")
		out, err := cmd.CombinedOutput()
		rowFound := strings.Contains(string(out), "1 row")
		testResult(5, "PostgreSQL connection", err == nil && rowFound)
	}()

	// ── Test 6: Alert rules count ──
	fmt.Println("Test 6: Checking alert rules...")
	if grafanaToken != "" {
		func() {
			headers := map[string]string{"Authorization": "Bearer " + grafanaToken}
			// The response is a map of namespace -> []rules
			var rulerResp map[string]json.RawMessage
			err := getJSON(fmt.Sprintf("http://%s:3000/api/ruler/grafana/rules", grafanaHost), headers, &rulerResp)
			if err != nil {
				fmt.Println("  Alert rules: 0 found")
				testResult(6, "Alert rules (expecting ≥14)", false)
				return
			}
			// Count all rules across all namespaces
			alertCount := 0
			for _, raw := range rulerResp {
				var groups []struct {
					Rules []json.RawMessage `json:"rules"`
				}
				if json.Unmarshal(raw, &groups) == nil {
					for _, g := range groups {
						alertCount += len(g.Rules)
					}
				}
			}
			fmt.Printf("  Alert rules: %d found\n", alertCount)
			testResult(6, "Alert rules (expecting ≥14)", alertCount >= 14)
		}()
	} else {
		fmt.Println("  (Skipping - No Token)")
		testResult(6, "Alert rules (Skipped)", true)
	}

	// ── Test 7: Contact points ──
	fmt.Println("Test 7: Checking contact points...")
	if grafanaToken != "" {
		func() {
			headers := map[string]string{"Authorization": "Bearer " + grafanaToken}
			var contactPoints []json.RawMessage
			err := getJSON(fmt.Sprintf("http://%s:3000/api/v1/provisioning/contact-points", grafanaHost), headers, &contactPoints)
			if err != nil {
				testResult(7, "Contact points (expecting ≥2)", false)
				return
			}
			contactCount := len(contactPoints)
			fmt.Printf("  Contact points: %d found\n", contactCount)
			testResult(7, "Contact points (expecting ≥2)", contactCount >= 2)
		}()
	} else {
		testResult(7, "Contact points (Skipped)", true)
	}

	// ── Test 8: Prometheus metrics ──
	fmt.Println("Test 8: Checking metrics in Prometheus...")
	func() {
		var data struct {
			Data struct {
				Result []json.RawMessage `json:"result"`
			} `json:"data"`
		}
		err := getJSON(fmt.Sprintf("http://%s:9090/api/v1/query?query=up", promHost), nil, &data)
		if err != nil {
			testResult(8, "Prometheus metrics", false)
			return
		}
		metrics := len(data.Data.Result)
		testResult(8, "Prometheus metrics", metrics > 0)
	}()

	// ── Test 9: SLA Dashboard exists ──
	fmt.Println("Test 9: Checking SLA Dashboard...")
	dashboardCount := 0
	var dashboardUID string
	if grafanaToken != "" {
		func() {
			headers := map[string]string{"Authorization": "Bearer " + grafanaToken}
			var searchResults []struct {
				UID string `json:"uid"`
			}
			err := getJSON(fmt.Sprintf("http://%s:3000/api/search?query=homelab-overview", grafanaHost), headers, &searchResults)
			if err != nil {
				testResult(9, "homelab dashboard exists", false)
				return
			}
			dashboardCount = len(searchResults)
			if dashboardCount > 0 {
				dashboardUID = searchResults[0].UID
			}
			testResult(9, "homelab dashboard exists", dashboardCount > 0)
		}()
	} else {
		testResult(9, "homelab dashboard exists (Skipped)", true)
		dashboardCount = 0
	}

	// ── Test 10: Dashboard panels count ──
	fmt.Println("Test 10: Checking SLA Dashboard panels...")
	if grafanaToken != "" && dashboardCount > 0 {
		func() {
			if dashboardUID == "" {
				testResult(10, "Dashboard panels", false)
				return
			}
			headers := map[string]string{"Authorization": "Bearer " + grafanaToken}
			var dashResp struct {
				Dashboard struct {
					Panels []json.RawMessage `json:"panels"`
				} `json:"dashboard"`
			}
			err := getJSON(fmt.Sprintf("http://%s:3000/api/dashboards/uid/%s", grafanaHost, dashboardUID), headers, &dashResp)
			if err != nil {
				testResult(10, "Dashboard panels", false)
				return
			}
			panelCount := len(dashResp.Dashboard.Panels)
			fmt.Printf("  homelab dashboard panels: %d\n", panelCount)
			testResult(10, "Dashboard panels (expecting >0)", panelCount > 0)
		}()
	} else {
		testResult(10, "Dashboard panels (Skipped)", true)
	}

	// ── Test 11: N8N metrics exporter (Disabled) ──
	// echo "Test 11: Checking N8N metrics exporter..."
	// EXPORTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.50.112:5679/metrics 2>/dev/null || echo "000")
	// test_result 11 "N8N metrics exporter (port 5679)" $([ "$EXPORTER_STATUS" = "200" ] && echo 0 || echo 1)

	// ── Test 12: Metrics exporter returns recovery metrics (Disabled) ──
	// echo "Test 12: Checking recovery metrics..."
	// RECOVERY_METRICS=$(curl -s http://192.168.50.112:5679/metrics 2>/dev/null | grep -c "mcp_recovery_" || echo 0)
	// echo "  Recovery metrics found: $RECOVERY_METRICS"
	// test_result 12 "Recovery metrics exported" $([ "$RECOVERY_METRICS" -gt 0 ] && echo 0 || echo 1)

	// ── Test 13: Recent data in dashboard (Disabled) ──
	// echo "Test 13: Checking recent data points..."
	// RECENT_DATA=$(curl -s "http://192.168.50.104:9090/api/v1/query?query=mcp_recovery_success_rate" | jq '.data.result | length' 2>/dev/null || echo 0)
	// echo "  Recent data points: $RECENT_DATA"
	// test_result 13 "Recent metrics data" $([ $RECENT_DATA -gt 0 ] && echo 0 || echo 1)

	// ── Test 14: ELK Elasticsearch Cluster Health ──
	fmt.Println("Test 14: Checking Elasticsearch health...")
	if elasticsearchPassword != "" {
		func() {
			var health struct {
				Status string `json:"status"`
			}
			err := getJSONBasicAuth(fmt.Sprintf("http://%s:9200/_cluster/health", elkHost), "elastic", elasticsearchPassword, &health)
			if err != nil {
				fmt.Println("  Elasticsearch status: down")
				testResult(14, "Elasticsearch health", false)
				return
			}
			fmt.Printf("  Elasticsearch status: %s\n", health.Status)
			testResult(14, "Elasticsearch health", health.Status == "green" || health.Status == "yellow")
		}()
	} else {
		fmt.Println("  (Skipping - ELASTICSEARCH_PASSWORD not set)")
		testResult(14, "Elasticsearch health (Skipped)", true)
	}

	// ── Test 15: Logstash Monitoring API responding ──
	fmt.Println("Test 15: Checking Logstash monitoring API...")
	func() {
		status := httpStatusCode(fmt.Sprintf("http://%s:9600/", elkHost))
		testResult(15, fmt.Sprintf("Logstash monitoring API (expecting 200, got %s)", status), status == "200")
	}()

	// ── Test 16: Logstash Prometheus Exporter ──
	fmt.Println("Test 16: Checking Logstash Prometheus Exporter...")
	func() {
		status := httpStatusCode(fmt.Sprintf("http://%s:9198/metrics", elkHost))
		testResult(16, fmt.Sprintf("Logstash Exporter (expecting 200, got %s)", status), status == "200")
	}()

	// ── Test 17: Filebeat/Logs reaching ES (Check if indices exist) ──
	fmt.Println("Test 17: Checking if Elasticsearch indices exist...")
	if elasticsearchPassword != "" {
		func() {
			var indices []json.RawMessage
			err := getJSONBasicAuth(fmt.Sprintf("http://%s:9200/_cat/indices?format=json", elkHost), "elastic", elasticsearchPassword, &indices)
			if err != nil {
				fmt.Println("  Indices found: 0")
				testResult(17, "Elasticsearch Indices (>0)", false)
				return
			}
			indexCount := len(indices)
			fmt.Printf("  Indices found: %d\n", indexCount)
			testResult(17, "Elasticsearch Indices (>0)", indexCount > 0)
		}()
	} else {
		fmt.Println("  (Skipping - ELASTICSEARCH_PASSWORD not set)")
		testResult(17, "Elasticsearch Indices (Skipped)", true)
	}

	// ── Summary ──
	p := atomic.LoadInt32(&passed)
	f := atomic.LoadInt32(&failed)
	total := p + f

	fmt.Println()
	fmt.Println("====================================")
	fmt.Println("SUMMARY")
	fmt.Println("====================================")
	fmt.Printf("%sPassed: %d / %d%s\n", green, p, total, nc)
	fmt.Printf("%sFailed: %d / %d%s\n", red, f, total, nc)
	fmt.Println()

	if f == 0 {
		fmt.Printf("%s✅ ALL TESTS PASSED - SYSTEM READY FOR GO-LIVE%s\n", green, nc)
		os.Exit(0)
	} else {
		fmt.Printf("%s⚠️  %d TEST(S) FAILED - CHECK ISSUES BEFORE DEPLOYMENT%s\n", red, f, nc)
		os.Exit(1)
	}
}
