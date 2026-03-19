package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	defaultArchonAPI = "http://192.168.50.108:8181/api"
	pollIntervalSec  = 5
	pollTimeoutSec   = 600
)

const (
	red    = "\033[0;31m"
	green  = "\033[0;32m"
	yellow = "\033[1;33m"
	blue   = "\033[0;34m"
	cyan   = "\033[0;36m"
	bold   = "\033[1m"
	nc     = "\033[0m"
)

type Source struct {
	URL                 string
	Tags                []string
	KnowledgeType       string
	MaxDepth            int
	UpdateFrequency     int
	ExtractCodeExamples bool
	Enabled             bool
	IngestMethod        string
}

func usage() {
	fmt.Printf("%ssync-sources.go%s — Sync documentation sources to Archon knowledge base\n\n", bold, nc)
	fmt.Printf("%sUSAGE%s\n", bold, nc)
	fmt.Println("  go run 108-archon/scripts/sync-sources.go [OPTIONS]")
	fmt.Println()
	fmt.Printf("%sOPTIONS%s\n", bold, nc)
	fmt.Println("  --dry-run       Show what would be crawled without executing")
	fmt.Println("  --tag TAG       Only process sources matching this tag")
	fmt.Println("  --force         Re-crawl sources even if they already exist")
	fmt.Println("  -h, --help      Show this help message")
	fmt.Println()
	fmt.Printf("%sENVIRONMENT%s\n", bold, nc)
	fmt.Println("  ARCHON_API      Archon server base URL (default: http://192.168.50.108:8181/api)")
	fmt.Println()
	fmt.Printf("%sEXAMPLES%s\n", bold, nc)
	fmt.Println("  # Dry-run all sources")
	fmt.Println("  go run 108-archon/scripts/sync-sources.go --dry-run")
	fmt.Println()
	fmt.Println("  # Crawl only infra-tagged sources")
	fmt.Println("  go run 108-archon/scripts/sync-sources.go --tag infra")
	fmt.Println()
	fmt.Println("  # Force re-crawl everything")
	fmt.Println("  go run 108-archon/scripts/sync-sources.go --force")
}

func parseArgs(args []string) (bool, string, bool, bool, int) {
	_ = flag.CommandLine

	dryRun := false
	filterTag := ""
	force := false

	for i := 0; i < len(args); i++ {
		a := args[i]
		switch a {
		case "--dry-run":
			dryRun = true
		case "--tag":
			if i+1 >= len(args) {
				fmt.Printf("%sUnknown option: %s%s\n", red, a, nc)
				usage()
				return false, "", false, true, 1
			}
			filterTag = args[i+1]
			i++
		case "--force":
			force = true
		case "-h", "--help":
			usage()
			return false, "", false, true, 0
		default:
			fmt.Printf("%sUnknown option: %s%s\n", red, a, nc)
			usage()
			return false, "", false, true, 1
		}
	}

	return dryRun, filterTag, force, false, 0
}

func parseBool(v string, def bool) bool {
	v = strings.TrimSpace(strings.ToLower(v))
	if v == "" {
		return def
	}
	switch v {
	case "true", "yes", "on", "1":
		return true
	case "false", "no", "off", "0":
		return false
	default:
		return def
	}
}

func parseInt(v string, def int) int {
	v = strings.TrimSpace(v)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}

func unquote(v string) string {
	v = strings.TrimSpace(v)
	if len(v) >= 2 {
		if (v[0] == '"' && v[len(v)-1] == '"') || (v[0] == '\'' && v[len(v)-1] == '\'') {
			return v[1 : len(v)-1]
		}
	}
	return v
}

func parseTagsInline(v string) []string {
	v = strings.TrimSpace(v)
	if v == "" || v == "[]" {
		return []string{}
	}
	if strings.HasPrefix(v, "[") && strings.HasSuffix(v, "]") {
		inner := strings.TrimSpace(v[1 : len(v)-1])
		if inner == "" {
			return []string{}
		}
		parts := strings.Split(inner, ",")
		tags := make([]string, 0, len(parts))
		for _, p := range parts {
			t := unquote(strings.TrimSpace(p))
			if t != "" {
				tags = append(tags, t)
			}
		}
		return tags
	}
	if strings.HasPrefix(v, "-") {
		return []string{unquote(strings.TrimSpace(strings.TrimPrefix(v, "-")))}
	}
	return []string{unquote(v)}
}

func formatTagsJSONLike(tags []string) string {
	if len(tags) == 0 {
		return "[]"
	}
	parts := make([]string, 0, len(tags))
	for _, t := range tags {
		parts = append(parts, fmt.Sprintf("\"%s\"", t))
	}
	return "[" + strings.Join(parts, ", ") + "]"
}

func parseSourcesFile(path string, filterTag string) ([]Source, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	sources := []Source{}
	var current *Source
	inSources := false

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		if idx := strings.Index(trimmed, "#"); idx >= 0 {
			if idx == 0 {
				trimmed = ""
			} else {
				trimmed = strings.TrimSpace(trimmed[:idx])
			}
		}
		if trimmed == "" {
			continue
		}

		if trimmed == "sources:" {
			inSources = true
			continue
		}
		if !inSources {
			continue
		}

		if strings.HasPrefix(trimmed, "- ") {
			if current != nil {
				sources = append(sources, *current)
			}
			current = &Source{
				KnowledgeType:       "documentation",
				MaxDepth:            2,
				UpdateFrequency:     7,
				ExtractCodeExamples: true,
				Enabled:             true,
				IngestMethod:        "crawl",
			}

			rest := strings.TrimSpace(strings.TrimPrefix(trimmed, "- "))
			if strings.HasPrefix(rest, "url:") {
				current.URL = unquote(strings.TrimSpace(strings.TrimPrefix(rest, "url:")))
			}
			continue
		}

		if current == nil {
			continue
		}

		if !strings.Contains(trimmed, ":") {
			continue
		}

		parts := strings.SplitN(trimmed, ":", 2)
		key := strings.TrimSpace(parts[0])
		val := ""
		if len(parts) > 1 {
			val = strings.TrimSpace(parts[1])
		}

		switch key {
		case "url":
			current.URL = unquote(val)
		case "tags":
			current.Tags = parseTagsInline(val)
		case "knowledge_type":
			if v := unquote(val); v != "" {
				current.KnowledgeType = v
			}
		case "max_depth":
			current.MaxDepth = parseInt(val, 2)
		case "update_frequency":
			current.UpdateFrequency = parseInt(val, 7)
		case "extract_code_examples":
			current.ExtractCodeExamples = parseBool(val, true)
		case "enabled":
			current.Enabled = parseBool(val, true)
		case "ingest_method":
			if v := unquote(val); v != "" {
				current.IngestMethod = v
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	if current != nil {
		sources = append(sources, *current)
	}

	filtered := make([]Source, 0, len(sources))
	for _, s := range sources {
		if !s.Enabled {
			continue
		}
		if s.IngestMethod == "inject" {
			fmt.Printf("%s  ⊘ Skipping inject source: %s (use inject-docs.go)%s\n", yellow, s.URL, nc)
			continue
		}
		if filterTag != "" {
			found := false
			for _, t := range s.Tags {
				if t == filterTag {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}
		if s.URL == "" {
			continue
		}
		filtered = append(filtered, s)
	}

	return filtered, nil
}

func getSourcesPath() string {
	if override := os.Getenv("SOURCES_FILE"); strings.TrimSpace(override) != "" {
		return override
	}
	cwd, err := os.Getwd()
	if err != nil {
		return "108-archon/sources.yml"
	}
	return filepath.Join(cwd, "108-archon", "sources.yml")
}

func doGet(client *http.Client, url string) (int, []byte, error) {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return 0, nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp.StatusCode, nil, err
	}
	return resp.StatusCode, body, nil
}

func doPostJSON(client *http.Client, url string, payload []byte) (int, []byte, error) {
	req, err := http.NewRequest(http.MethodPost, url, strings.NewReader(string(payload)))
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp.StatusCode, nil, err
	}
	return resp.StatusCode, body, nil
}

func sourceExists(existing []byte, url string) bool {
	type sourceItem struct {
		Metadata struct {
			OriginalURL string `json:"original_url"`
		} `json:"metadata"`
	}
	type wrapped struct {
		Sources []sourceItem `json:"sources"`
	}

	var w wrapped
	if err := json.Unmarshal(existing, &w); err == nil {
		for _, s := range w.Sources {
			if s.Metadata.OriginalURL == url {
				return true
			}
		}
		return false
	}

	var arr []sourceItem
	if err := json.Unmarshal(existing, &arr); err == nil {
		for _, s := range arr {
			if s.Metadata.OriginalURL == url {
				return true
			}
		}
	}
	return false
}

func extractProgressID(body []byte) string {
	var m map[string]interface{}
	if err := json.Unmarshal(body, &m); err != nil {
		return ""
	}
	if v, ok := m["progressId"]; ok {
		return strings.TrimSpace(fmt.Sprintf("%v", v))
	}
	if v, ok := m["progress_id"]; ok {
		return strings.TrimSpace(fmt.Sprintf("%v", v))
	}
	if v, ok := m["id"]; ok {
		return strings.TrimSpace(fmt.Sprintf("%v", v))
	}
	return ""
}

func pollProgress(client *http.Client, archonAPI string, progressID string) int {
	elapsed := 0
	for elapsed < pollTimeoutSec {
		statusCode, body, err := doGet(client, archonAPI+"/crawl-progress/"+progressID)
		if err != nil || statusCode == 0 {
			body = []byte("{}")
		}

		status := "unknown"
		progress := "..."

		var m map[string]interface{}
		if err := json.Unmarshal(body, &m); err == nil {
			if v, ok := m["status"]; ok {
				status = strings.TrimSpace(fmt.Sprintf("%v", v))
				if status == "" {
					status = "unknown"
				}
			}

			total := 0
			processed := 0
			if v, ok := m["totalPages"]; ok {
				total = parseInt(fmt.Sprintf("%v", v), 0)
			}
			if v, ok := m["processedPages"]; ok {
				processed = parseInt(fmt.Sprintf("%v", v), 0)
			}
			if total > 0 {
				progress = fmt.Sprintf("%d/%d", processed, total)
			}
		}

		switch status {
		case "completed", "complete":
			fmt.Printf("  %s✓ Completed%s (pages: %s)\n", green, nc, progress)
			return 0
		case "failed", "error":
			fmt.Printf("  %s✗ Failed%s\n", red, nc)
			fmt.Printf("  %s  Response: %s%s\n", red, strings.TrimSpace(string(body)), nc)
			return 1
		default:
			fmt.Printf("  %s⟳ %s%s (pages: %s, %ds elapsed)\r", cyan, status, nc, progress, elapsed)
		}

		time.Sleep(time.Duration(pollIntervalSec) * time.Second)
		elapsed += pollIntervalSec
	}

	fmt.Printf("\n  %s⚠ Timeout after %ds — crawl may still be running%s\n", yellow, pollTimeoutSec, nc)
	return 2
}

func run() int {
	dryRun, filterTag, force, done, code := parseArgs(os.Args[1:])
	if done {
		return code
	}

	archonAPI := os.Getenv("ARCHON_API")
	if strings.TrimSpace(archonAPI) == "" {
		archonAPI = defaultArchonAPI
	}
	sourcesFile := getSourcesPath()

	if _, err := os.Stat(sourcesFile); err != nil {
		fmt.Printf("%sError: sources file not found: %s%s\n", red, sourcesFile, nc)
		return 1
	}

	fmt.Printf("%s%s═══════════════════════════════════════════════════%s\n", bold, blue, nc)
	fmt.Printf("%s%s  Archon Knowledge Base — Source Sync%s\n", bold, blue, nc)
	fmt.Printf("%s%s═══════════════════════════════════════════════════%s\n", bold, blue, nc)
	fmt.Printf("%sAPI:%s     %s\n", cyan, nc, archonAPI)
	fmt.Printf("%sSources:%s %s\n", cyan, nc, sourcesFile)
	if filterTag != "" {
		fmt.Printf("%sFilter:%s  tag=%s\n", cyan, nc, filterTag)
	}
	if dryRun {
		fmt.Printf("%sMode:    DRY RUN%s\n", yellow, nc)
	}
	if force {
		fmt.Printf("%sMode:    FORCE (re-crawl existing)%s\n", yellow, nc)
	}
	fmt.Println()

	client := &http.Client{Timeout: 30 * time.Second}

	statusCode, existingBody, err := doGet(client, archonAPI+"/rag/sources")
	if err != nil || statusCode != http.StatusOK {
		fmt.Printf("%sError: Archon API is not reachable at %s%s\n", red, archonAPI, nc)
		return 1
	}

	sources, err := parseSourcesFile(sourcesFile, filterTag)
	if err != nil {
		fmt.Printf("%sError: failed to parse sources file: %v%s\n", red, err, nc)
		return 1
	}

	sourceCount := len(sources)
	if sourceCount == 0 {
		fmt.Printf("%sNo sources to process.%s\n", yellow, nc)
		return 0
	}

	fmt.Printf("%sFound %d source(s) to process%s\n", bold, sourceCount, nc)
	fmt.Println()

	crawled := 0
	skipped := 0
	failed := 0

	for idx, s := range sources {
		tagsDisplay := formatTagsJSONLike(s.Tags)
		fmt.Printf("%s[%d/%d] %s%s\n", bold, idx+1, sourceCount, s.URL, nc)
		fmt.Printf("  type=%s  tags=%s  depth=%d  ingest=%s\n", s.KnowledgeType, tagsDisplay, s.MaxDepth, s.IngestMethod)

		already := sourceExists(existingBody, s.URL)
		if already && !force {
			fmt.Printf("  %s⊘ Skipped (already exists, use --force to re-crawl)%s\n", yellow, nc)
			skipped++
			fmt.Println()
			continue
		}

		if dryRun {
			fmt.Printf("  %s⊙ Would crawl%s\n", cyan, nc)
			fmt.Println()
			continue
		}

		payload := map[string]interface{}{
			"url":                   s.URL,
			"knowledge_type":        s.KnowledgeType,
			"tags":                  s.Tags,
			"max_depth":             s.MaxDepth,
			"update_frequency":      s.UpdateFrequency,
			"extract_code_examples": true,
		}
		payloadBytes, err := json.Marshal(payload)
		if err != nil {
			fmt.Printf("  %s✗ Failed to start crawl%s\n", red, nc)
			fmt.Printf("  %s  Response: %v%s\n", red, err, nc)
			failed++
			fmt.Println()
			continue
		}

		_, respBody, err := doPostJSON(client, archonAPI+"/knowledge-items/crawl", payloadBytes)
		if err != nil {
			fmt.Printf("  %s✗ Failed to start crawl%s\n", red, nc)
			fmt.Printf("  %s  Response: %v%s\n", red, err, nc)
			failed++
			fmt.Println()
			continue
		}

		progressID := extractProgressID(respBody)
		if progressID == "" || progressID == "None" {
			fmt.Printf("  %s✗ Failed to start crawl%s\n", red, nc)
			fmt.Printf("  %s  Response: %s%s\n", red, strings.TrimSpace(string(respBody)), nc)
			failed++
			fmt.Println()
			continue
		}

		fmt.Printf("  %sStarted crawl: %s%s\n", cyan, progressID, nc)

		result := pollProgress(client, archonAPI, progressID)
		if result == 0 {
			crawled++
		} else {
			failed++
		}
		fmt.Println()
	}

	fmt.Printf("%s%s═══════════════════════════════════════════════════%s\n", bold, blue, nc)
	fmt.Printf("%s%s  Sync complete%s\n", bold, blue, nc)
	fmt.Printf("%s%s═══════════════════════════════════════════════════%s\n", bold, blue, nc)
	fmt.Printf("Crawled: %s%d%s  Skipped: %s%d%s  Failed: %s%d%s\n", green, crawled, nc, yellow, skipped, nc, red, failed, nc)
	fmt.Printf("Run %sgo run 108-archon/scripts/sync-sources.go --dry-run%s to preview.\n", cyan, nc)
	fmt.Printf("Verify via: %scurl -s %s/rag/sources | python3 -m json.tool%s\n", cyan, archonAPI, nc)

	return 0
}

func main() {
	os.Exit(run())
}
