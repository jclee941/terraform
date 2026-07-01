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
	passed  int32
	failed  int32
	skipped int32
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

func testSkipped(testNum int, testName string) {
	fmt.Printf("%s⚠️  Test %d SKIPPED%s: %s\n", yellow, testNum, nc, testName)
	atomic.AddInt32(&skipped, 1)
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

func httpStatusOK(status string) bool {
	return status == "200"
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
	kibanaHost := envOrDefault("KIBANA_HOST", "192.168.50.105")
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
		s := atomic.LoadInt32(&skipped)
		fmt.Println()
		fmt.Println("====================================")
		fmt.Printf("INTERRUPTED (signal: %v)\n", sig)
		fmt.Printf("Completed: %d tests before interruption\n", p+f+s)
		fmt.Println("====================================")
		os.Exit(1)
	}()

	fmt.Println("🔍 PRODUCTION VERIFICATION SUITE v2")
	fmt.Println("====================================")
	fmt.Println()

	if elasticsearchPassword == "" {
		fmt.Printf("%s⚠️  WARNING: ELASTICSEARCH_PASSWORD not set. Skipping authenticated ES tests.%s\n", yellow, nc)
		fmt.Println()
	}

	fmt.Println("Test 1: Checking Kibana HTTP...")
	func() {
		status := httpStatusCode(fmt.Sprintf("http://%s:5601/api/status", kibanaHost))
		testResult(1, fmt.Sprintf("Kibana HTTP (expecting 200, got %s)", status), httpStatusOK(status))
	}()

	// ── Test 3: Load test (100 requests) ──
	fmt.Println("Test 3: Running Kibana load test (100 requests)...")
	func() {
		successCount := 0
		url := fmt.Sprintf("http://%s:5601/api/status", kibanaHost)
		for i := 0; i < 100; i++ {
			if httpStatusOK(httpStatusCode(url)) {
				successCount++
			}
		}
		fmt.Printf("  Load test: %d/100 successful\n", successCount)
		testResult(3, "Load test success rate", successCount >= 95)
	}()

	// ── Test 4: PostgreSQL connection ──
	fmt.Println("Test 4: Checking PostgreSQL connection...")
	func() {
		_, err := exec.LookPath("psql")
		if err != nil {
			fmt.Println("  (Skipping - psql client not installed)")
			testSkipped(4, "PostgreSQL connection")
			return
		}
		cmd := exec.Command("psql", "-h", psqlHost, "-U", "postgres", "-d", "postgres", "-c", "SELECT 1")
		out, err := cmd.CombinedOutput()
		rowFound := strings.Contains(string(out), "1 row")
		testResult(4, "PostgreSQL connection", err == nil && rowFound)
	}()

	// ── Test 5: Alert rules count ──
	fmt.Println("Test 5: Checking alert rules...")
	fmt.Println("  (Skipping - alerting runtime not configured in current inventory)")
	testSkipped(5, "Alert rules")

	// ── Test 6: Contact points ──
	fmt.Println("Test 6: Checking contact points...")
	testSkipped(6, "Contact points")

	fmt.Println("Test 7: Checking Logstash exporter metrics...")
	func() {
		status := httpStatusCode(fmt.Sprintf("http://%s:9198/metrics", elkHost))
		testResult(7, fmt.Sprintf("Logstash exporter metrics (expecting 200, got %s)", status), status == "200")
	}()

	// ── Test 8: SLA Dashboard exists ──
	fmt.Println("Test 8: Checking SLA Dashboard...")
	dashboardCount := 0
	var dashboardUID string
	testSkipped(8, "homelab dashboard exists")
	dashboardCount = 0

	// ── Test 9: Dashboard panels count ──
	fmt.Println("Test 9: Checking SLA Dashboard panels...")
	if dashboardCount > 0 {
		func() {
			if dashboardUID == "" {
				testResult(9, "Dashboard panels", false)
				return
			}
			var dashResp struct {
				Dashboard struct {
					Panels []json.RawMessage `json:"panels"`
				} `json:"dashboard"`
			}
			err := getJSON(fmt.Sprintf("http://%s:5601/api/saved_objects/dashboard/%s", kibanaHost, dashboardUID), nil, &dashResp)
			if err != nil {
				testResult(9, "Dashboard panels", false)
				return
			}
			panelCount := len(dashResp.Dashboard.Panels)
			fmt.Printf("  homelab dashboard panels: %d\n", panelCount)
			testResult(9, "Dashboard panels (expecting >0)", panelCount > 0)
		}()
	} else {
		testSkipped(9, "Dashboard panels")
	}

	// ── Test 10: ELK Elasticsearch Cluster Health ──
	fmt.Println("Test 10: Checking Elasticsearch health...")
	if elasticsearchPassword != "" {
		func() {
			var health struct {
				Status string `json:"status"`
			}
			err := getJSONBasicAuth(fmt.Sprintf("http://%s:9200/_cluster/health", elkHost), "elastic", elasticsearchPassword, &health)
			if err != nil {
				fmt.Println("  Elasticsearch status: down")
				testResult(10, "Elasticsearch health", false)
				return
			}
			fmt.Printf("  Elasticsearch status: %s\n", health.Status)
			testResult(10, "Elasticsearch health", health.Status == "green" || health.Status == "yellow")
		}()
	} else {
		fmt.Println("  (Skipping - ELASTICSEARCH_PASSWORD not set)")
		testSkipped(10, "Elasticsearch health")
	}

	// ── Test 11: Logstash Monitoring API responding ──
	fmt.Println("Test 11: Checking Logstash monitoring API...")
	func() {
		status := httpStatusCode(fmt.Sprintf("http://%s:9600/", elkHost))
		testResult(11, fmt.Sprintf("Logstash monitoring API (expecting 200, got %s)", status), status == "200")
	}()

	fmt.Println("Test 12: Checking Logstash metrics exporter...")
	func() {
		status := httpStatusCode(fmt.Sprintf("http://%s:9198/metrics", elkHost))
		testResult(12, fmt.Sprintf("Logstash Exporter (expecting 200, got %s)", status), status == "200")
	}()

	// ── Test 13: Filebeat/Logs reaching ES (Check if indices exist) ──
	fmt.Println("Test 13: Checking if Elasticsearch indices exist...")
	if elasticsearchPassword != "" {
		func() {
			var indices []json.RawMessage
			err := getJSONBasicAuth(fmt.Sprintf("http://%s:9200/_cat/indices?format=json", elkHost), "elastic", elasticsearchPassword, &indices)
			if err != nil {
				fmt.Println("  Indices found: 0")
				testResult(13, "Elasticsearch Indices (>0)", false)
				return
			}
			indexCount := len(indices)
			fmt.Printf("  Indices found: %d\n", indexCount)
			testResult(13, "Elasticsearch Indices (>0)", indexCount > 0)
		}()
	} else {
		fmt.Println("  (Skipping - ELASTICSEARCH_PASSWORD not set)")
		testSkipped(13, "Elasticsearch Indices")
	}

	// ── Summary ──
	p := atomic.LoadInt32(&passed)
	f := atomic.LoadInt32(&failed)
	s := atomic.LoadInt32(&skipped)
	total := p + f + s

	fmt.Println()
	fmt.Println("====================================")
	fmt.Println("SUMMARY")
	fmt.Println("====================================")
	fmt.Printf("%sPassed: %d / %d%s\n", green, p, total, nc)
	fmt.Printf("%sFailed: %d / %d%s\n", red, f, total, nc)
	fmt.Printf("%sSkipped: %d / %d%s\n", yellow, s, total, nc)
	fmt.Println()

	if f == 0 && s == 0 {
		fmt.Printf("%s✅ ALL TESTS PASSED - SYSTEM READY FOR GO-LIVE%s\n", green, nc)
		os.Exit(0)
	}
	if f == 0 {
		fmt.Printf("%s⚠️  VERIFICATION INCOMPLETE - SKIPPED TESTS REQUIRE FOLLOW-UP%s\n", yellow, nc)
		os.Exit(1)
	}
	fmt.Printf("%s⚠️  %d TEST(S) FAILED - CHECK ISSUES BEFORE DEPLOYMENT%s\n", red, f, nc)
	os.Exit(1)
}
