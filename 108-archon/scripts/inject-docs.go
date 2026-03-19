package main

import (
	"encoding/json"
	"encoding/xml"
	"flag"
	"fmt"
	"html"
	"io"
	"math"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

const (
	defaultOllamaURL   = "http://192.168.50.215:11434"
	defaultSupabaseURL = "https://supabase.jclee.me"
	defaultArchonAPI   = "http://192.168.50.108:8181/api"
	embeddingModel     = "nomic-embed-text:latest"
	chunkSize          = 4000
	userAgent          = "OpenCode-RAG-Injector/1.0"
)

var (
	spaceRe        = regexp.MustCompile(`[ \t]+`)
	multiNewlineRe = regexp.MustCompile(`\n{3,}`)
)

type config struct {
	SourceID    string
	OllamaURL   string
	SupabaseURL string
	SupabaseKey string
	DryRun      bool
	SitemapURL  string
	URLPattern  string
	Tags        []string
	Force       bool
}

type sitemapURLSet struct {
	URLs []struct {
		Loc string `xml:"loc"`
	} `xml:"url"`
}

type sitemapIndex struct {
	Sitemaps []struct {
		Loc string `xml:"loc"`
	} `xml:"sitemap"`
}

type textExtractor struct {
	parts      []string
	titleParts []string
	skipDepth  int
	inTitle    bool
}

func usage() {
	fmt.Println("inject-docs.go — Direct inject documentation pages into Archon RAG tables")
	fmt.Println()
	fmt.Println("USAGE")
	fmt.Println("  go run 108-archon/scripts/inject-docs.go [OPTIONS]")
	fmt.Println()
	fmt.Println("OPTIONS")
	fmt.Println("  --source-id     Source ID. If omitted, auto-detected from Archon API")
	fmt.Println("  --ollama-url    Ollama base URL (env OLLAMA_EMBEDDING_URL, default http://192.168.50.215:11434)")
	fmt.Println("  --supabase-url  Supabase base URL (env SUPABASE_URL, default https://supabase.jclee.me)")
	fmt.Println("  --supabase-key  Supabase service key (env SUPABASE_SERVICE_KEY)")
	fmt.Println("  --dry-run       Show what would be injected without inserting")
	fmt.Println("  --sitemap-url   Sitemap URL for URL discovery (e.g. https://opencode.ai/sitemap.xml)")
	fmt.Println("  --url-pattern   Regex filter for discovered URLs")
	fmt.Println("  --tag           Comma-separated tags (default: ai,opencode)")
	fmt.Println("  --force         Delete existing data for source_id before injecting")
}

func parseTags(s string) []string {
	s = strings.TrimSpace(s)
	if s == "" {
		return []string{"ai", "opencode"}
	}
	parts := strings.Split(s, ",")
	tags := make([]string, 0, len(parts))
	for _, p := range parts {
		t := strings.TrimSpace(p)
		if t != "" {
			tags = append(tags, t)
		}
	}
	if len(tags) == 0 {
		return []string{"ai", "opencode"}
	}
	return tags
}

func parseFlags() (config, bool) {
	var cfg config
	var tagsRaw string

	flag.StringVar(&cfg.SourceID, "source-id", "", "Source ID (auto-detect when omitted)")
	flag.StringVar(&cfg.OllamaURL, "ollama-url", "", "Ollama URL")
	flag.StringVar(&cfg.SupabaseURL, "supabase-url", "", "Supabase URL")
	flag.StringVar(&cfg.SupabaseKey, "supabase-key", "", "Supabase service key")
	flag.BoolVar(&cfg.DryRun, "dry-run", false, "Dry-run mode")
	flag.StringVar(&cfg.SitemapURL, "sitemap-url", "", "Sitemap URL")
	flag.StringVar(&cfg.URLPattern, "url-pattern", "", "Regex filter for URLs")
	flag.StringVar(&tagsRaw, "tag", "ai,opencode", "Comma-separated tags")
	flag.BoolVar(&cfg.Force, "force", false, "Delete existing source data before injecting")

	flag.Usage = usage
	flag.Parse()

	cfg.Tags = parseTags(tagsRaw)

	if strings.TrimSpace(cfg.OllamaURL) == "" {
		cfg.OllamaURL = strings.TrimSpace(os.Getenv("OLLAMA_EMBEDDING_URL"))
	}
	if strings.TrimSpace(cfg.OllamaURL) == "" {
		cfg.OllamaURL = defaultOllamaURL
	}

	if strings.TrimSpace(cfg.SupabaseURL) == "" {
		cfg.SupabaseURL = strings.TrimSpace(os.Getenv("SUPABASE_URL"))
	}
	if strings.TrimSpace(cfg.SupabaseURL) == "" {
		cfg.SupabaseURL = defaultSupabaseURL
	}

	if strings.TrimSpace(cfg.SupabaseKey) == "" {
		cfg.SupabaseKey = strings.TrimSpace(os.Getenv("SUPABASE_SERVICE_KEY"))
	}
	if strings.TrimSpace(cfg.SupabaseKey) == "" {
		fmt.Fprintln(os.Stderr, "error: supabase service key is required via --supabase-key or SUPABASE_SERVICE_KEY")
		return cfg, false
	}

	return cfg, true
}

func doRequest(client *http.Client, method, url string, body []byte, headers map[string]string) (int, []byte, error) {
	var reader io.Reader
	if body != nil {
		reader = strings.NewReader(string(body))
	}
	req, err := http.NewRequest(method, url, reader)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp.StatusCode, nil, err
	}
	return resp.StatusCode, respBody, nil
}

func (te *textExtractor) appendText(s string) {
	if te.skipDepth == 0 {
		te.parts = append(te.parts, s)
	}
	if te.inTitle {
		te.titleParts = append(te.titleParts, s)
	}
}

func lowerTagName(raw string) string {
	raw = strings.TrimSpace(raw)
	raw = strings.TrimPrefix(raw, "/")
	raw = strings.TrimSuffix(raw, "/")
	if raw == "" {
		return ""
	}
	for i, r := range raw {
		if r == ' ' || r == '\t' || r == '\n' || r == '\r' {
			return strings.ToLower(raw[:i])
		}
	}
	return strings.ToLower(raw)
}

func parseHTMLText(content string) (string, string) {
	skipTags := map[string]bool{
		"script":   true,
		"style":    true,
		"nav":      true,
		"header":   true,
		"footer":   true,
		"noscript": true,
		"svg":      true,
	}
	breakTags := map[string]bool{
		"p":   true,
		"div": true,
		"h1":  true,
		"h2":  true,
		"h3":  true,
		"h4":  true,
		"h5":  true,
		"h6":  true,
		"li":  true,
		"br":  true,
		"tr":  true,
	}

	te := &textExtractor{}
	i := 0
	for i < len(content) {
		lt := strings.Index(content[i:], "<")
		if lt < 0 {
			text := html.UnescapeString(content[i:])
			te.appendText(text)
			break
		}
		lt += i
		if lt > i {
			text := html.UnescapeString(content[i:lt])
			te.appendText(text)
		}
		gt := strings.Index(content[lt:], ">")
		if gt < 0 {
			break
		}
		gt += lt
		tagBody := strings.TrimSpace(content[lt+1 : gt])
		if tagBody == "" {
			i = gt + 1
			continue
		}
		lowerBody := strings.ToLower(tagBody)
		if strings.HasPrefix(lowerBody, "!--") {
			i = gt + 1
			continue
		}
		isEnd := strings.HasPrefix(lowerBody, "/")
		name := lowerTagName(lowerBody)

		if name == "title" {
			if isEnd {
				te.inTitle = false
			} else {
				te.inTitle = true
			}
		}

		if skipTags[name] {
			if isEnd {
				if te.skipDepth > 0 {
					te.skipDepth--
				}
			} else {
				te.skipDepth++
			}
		}

		if (isEnd && breakTags[name]) || (!isEnd && name == "br") {
			te.parts = append(te.parts, "\n")
		}
		i = gt + 1
	}

	raw := strings.Join(te.parts, "")
	raw = spaceRe.ReplaceAllString(raw, " ")
	raw = multiNewlineRe.ReplaceAllString(raw, "\n\n")
	raw = strings.TrimSpace(raw)

	title := strings.TrimSpace(html.UnescapeString(strings.Join(te.titleParts, "")))
	return title, raw
}

func chunkText(text string, maxChunk int) []string {
	if len(text) <= maxChunk {
		return []string{text}
	}

	paras := strings.Split(text, "\n\n")
	chunks := make([]string, 0)
	current := ""
	for _, para := range paras {
		if len(current)+len(para)+2 > maxChunk && strings.TrimSpace(current) != "" {
			chunks = append(chunks, strings.TrimSpace(current))
			current = para
		} else {
			if current == "" {
				current = para
			} else {
				current = current + "\n\n" + para
			}
		}
	}
	if strings.TrimSpace(current) != "" {
		chunks = append(chunks, strings.TrimSpace(current))
	}

	out := make([]string, 0, len(chunks))
	for _, chunk := range chunks {
		if len(chunk) <= maxChunk {
			out = append(out, chunk)
			continue
		}
		sentences := splitSentences(chunk)
		sub := ""
		for _, s := range sentences {
			if len(sub)+len(s)+1 > maxChunk && strings.TrimSpace(sub) != "" {
				out = append(out, strings.TrimSpace(sub))
				sub = s
			} else {
				if sub == "" {
					sub = s
				} else {
					sub = sub + " " + s
				}
			}
		}
		if strings.TrimSpace(sub) != "" {
			out = append(out, strings.TrimSpace(sub))
		}
	}
	return out
}

func splitSentences(s string) []string {
	parts := make([]string, 0)
	start := 0
	i := 0
	for i < len(s) {
		ch := s[i]
		if ch == '.' || ch == '!' || ch == '?' {
			j := i + 1
			hasSpace := false
			for j < len(s) && (s[j] == ' ' || s[j] == '\n' || s[j] == '\t' || s[j] == '\r') {
				hasSpace = true
				j++
			}
			if hasSpace {
				part := strings.TrimSpace(s[start : i+1])
				if part != "" {
					parts = append(parts, part)
				}
				start = j
				i = j
				continue
			}
		}
		i++
	}
	if start < len(s) {
		last := strings.TrimSpace(s[start:])
		if last != "" {
			parts = append(parts, last)
		}
	}
	if len(parts) == 0 {
		return []string{strings.TrimSpace(s)}
	}
	return parts
}

func normalizeEmbedding(v []float64) []float64 {
	sum := 0.0
	for _, x := range v {
		sum += x * x
	}
	norm := math.Sqrt(sum)
	if norm == 0 {
		return v
	}
	out := make([]float64, len(v))
	for i, x := range v {
		out[i] = x / norm
	}
	return out
}

func getEmbedding(client *http.Client, ollamaURL, text string) ([]float64, error) {
	payload := map[string]interface{}{
		"model":  embeddingModel,
		"prompt": text,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	status, respBody, err := doRequest(client, http.MethodPost, strings.TrimRight(ollamaURL, "/")+"/api/embeddings", body, map[string]string{
		"Content-Type": "application/json",
	})
	if err != nil {
		return nil, err
	}
	if status < 200 || status >= 300 {
		return nil, fmt.Errorf("ollama embeddings failed (%d): %s", status, strings.TrimSpace(string(respBody)))
	}

	var resp struct {
		Embedding []float64 `json:"embedding"`
	}
	if err := json.Unmarshal(respBody, &resp); err != nil {
		return nil, err
	}
	if len(resp.Embedding) == 0 {
		return nil, fmt.Errorf("ollama returned empty embedding")
	}
	return normalizeEmbedding(resp.Embedding), nil
}

func supabaseHeaders(apiKey string, includePrefer bool) map[string]string {
	h := map[string]string{
		"Content-Type":  "application/json",
		"apikey":        apiKey,
		"Authorization": "Bearer " + apiKey,
	}
	if includePrefer {
		h["Prefer"] = "return=representation"
	}
	return h
}

func encodeEq(v string) string {
	r := strings.NewReplacer(
		"%", "%25",
		" ", "%20",
		"\"", "%22",
		"#", "%23",
		"&", "%26",
		"+", "%2B",
		",", "%2C",
		"/", "%2F",
		":", "%3A",
		";", "%3B",
		"=", "%3D",
		"?", "%3F",
		"@", "%40",
	)
	return r.Replace(v)
}

func deleteExistingBySource(client *http.Client, supabaseURL, apiKey, sourceID string) error {
	base := strings.TrimRight(supabaseURL, "/") + "/rest/v1"
	q := "?source_id=eq." + encodeEq(sourceID)

	status, body, err := doRequest(client, http.MethodDelete, base+"/archon_crawled_pages"+q, nil, supabaseHeaders(apiKey, false))
	if err != nil {
		return err
	}
	if status < 200 || status >= 300 {
		return fmt.Errorf("failed deleting archon_crawled_pages (%d): %s", status, strings.TrimSpace(string(body)))
	}

	status, body, err = doRequest(client, http.MethodDelete, base+"/archon_page_metadata"+q, nil, supabaseHeaders(apiKey, false))
	if err != nil {
		return err
	}
	if status < 200 || status >= 300 {
		return fmt.Errorf("failed deleting archon_page_metadata (%d): %s", status, strings.TrimSpace(string(body)))
	}
	return nil
}

func insertPageMetadata(client *http.Client, cfg config, pageURL, title, fullContent string, chunkCount int) (string, error) {
	wordCount := len(strings.Fields(fullContent))
	charCount := len(fullContent)
	row := map[string]interface{}{
		"source_id":     cfg.SourceID,
		"url":           pageURL,
		"full_content":  fullContent,
		"section_title": title,
		"section_order": 0,
		"word_count":    wordCount,
		"char_count":    charCount,
		"chunk_count":   chunkCount,
		"metadata": map[string]interface{}{
			"tags":           cfg.Tags,
			"page_type":      "documentation",
			"crawl_type":     "direct_injection",
			"knowledge_type": "documentation",
		},
	}
	payload, err := json.Marshal(row)
	if err != nil {
		return "", err
	}
	url := strings.TrimRight(cfg.SupabaseURL, "/") + "/rest/v1/archon_page_metadata"
	status, body, err := doRequest(client, http.MethodPost, url, payload, supabaseHeaders(cfg.SupabaseKey, true))
	if err != nil {
		return "", err
	}
	if status < 200 || status >= 300 {
		return "", fmt.Errorf("insert metadata failed (%d): %s", status, strings.TrimSpace(string(body)))
	}

	var rows []map[string]interface{}
	if err := json.Unmarshal(body, &rows); err != nil {
		return "", fmt.Errorf("metadata response parse failed: %w", err)
	}
	if len(rows) == 0 {
		return "", fmt.Errorf("metadata insert returned no rows")
	}
	id := strings.TrimSpace(fmt.Sprintf("%v", rows[0]["id"]))
	if id == "" || id == "<nil>" {
		return "", fmt.Errorf("metadata insert returned empty id")
	}
	return id, nil
}

func insertChunk(client *http.Client, cfg config, pageURL, content, title, pageID string, chunkNumber int, embedding []float64) error {
	wordCount := len(strings.Fields(content))
	charCount := len(content)
	embeddingJSON, err := json.Marshal(embedding)
	if err != nil {
		return err
	}

	row := map[string]interface{}{
		"source_id": cfg.SourceID,
		"url":       pageURL,
		"content":   content,
		"metadata": map[string]interface{}{
			"url":            pageURL,
			"tags":           cfg.Tags,
			"title":          title,
			"page_id":        pageID,
			"source_id":      cfg.SourceID,
			"char_count":     charCount,
			"chunk_size":     chunkSize,
			"word_count":     wordCount,
			"chunk_index":    chunkNumber,
			"knowledge_type": "documentation",
		},
		"embedding_768":       string(embeddingJSON),
		"embedding_dimension": 768,
		"embedding_model":     embeddingModel,
		"page_id":             pageID,
		"chunk_number":        chunkNumber,
	}
	payload, err := json.Marshal(row)
	if err != nil {
		return err
	}

	url := strings.TrimRight(cfg.SupabaseURL, "/") + "/rest/v1/archon_crawled_pages"
	status, body, err := doRequest(client, http.MethodPost, url, payload, supabaseHeaders(cfg.SupabaseKey, false))
	if err != nil {
		return err
	}
	if status < 200 || status >= 300 {
		return fmt.Errorf("insert chunk failed (%d): %s", status, strings.TrimSpace(string(body)))
	}
	return nil
}

func fetchURL(client *http.Client, url string) ([]byte, error) {
	status, body, err := doRequest(client, http.MethodGet, url, nil, map[string]string{})
	if err != nil {
		return nil, err
	}
	if status < 200 || status >= 300 {
		return nil, fmt.Errorf("GET failed (%d): %s", status, strings.TrimSpace(string(body)))
	}
	return body, nil
}

func discoverURLsFromSitemap(client *http.Client, sitemapURL string) ([]string, error) {
	body, err := fetchURL(client, sitemapURL)
	if err != nil {
		return nil, err
	}

	var urlset sitemapURLSet
	if err := xml.Unmarshal(body, &urlset); err == nil && len(urlset.URLs) > 0 {
		urls := make([]string, 0, len(urlset.URLs))
		for _, u := range urlset.URLs {
			loc := strings.TrimSpace(u.Loc)
			if loc != "" {
				urls = append(urls, loc)
			}
		}
		return urls, nil
	}

	var idx sitemapIndex
	if err := xml.Unmarshal(body, &idx); err == nil && len(idx.Sitemaps) > 0 {
		all := make([]string, 0)
		for _, sm := range idx.Sitemaps {
			loc := strings.TrimSpace(sm.Loc)
			if loc == "" {
				continue
			}
			child, childErr := discoverURLsFromSitemap(client, loc)
			if childErr != nil {
				return nil, childErr
			}
			all = append(all, child...)
		}
		return all, nil
	}

	return nil, fmt.Errorf("unsupported sitemap xml format at %s", sitemapURL)
}

func dedupeURLs(urls []string) []string {
	seen := make(map[string]bool, len(urls))
	out := make([]string, 0, len(urls))
	for _, u := range urls {
		t := strings.TrimSpace(u)
		if t == "" || seen[t] {
			continue
		}
		seen[t] = true
		out = append(out, t)
	}
	return out
}

func readURLsFromStdin() ([]string, error) {
	info, err := os.Stdin.Stat()
	if err != nil {
		return nil, err
	}
	if (info.Mode() & os.ModeCharDevice) != 0 {
		return []string{}, nil
	}

	data, err := io.ReadAll(os.Stdin)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(string(data), "\n")
	urls := make([]string, 0, len(lines))
	for _, line := range lines {
		t := strings.TrimSpace(line)
		if t == "" {
			continue
		}
		urls = append(urls, t)
	}
	return dedupeURLs(urls), nil
}

func applyURLPattern(urls []string, pattern string) ([]string, error) {
	pattern = strings.TrimSpace(pattern)
	if pattern == "" {
		return urls, nil
	}
	re, err := regexp.Compile(pattern)
	if err != nil {
		return nil, err
	}
	filtered := make([]string, 0, len(urls))
	for _, u := range urls {
		if re.MatchString(u) {
			filtered = append(filtered, u)
		}
	}
	return filtered, nil
}

func inferTitle(url string) string {
	u := strings.TrimRight(url, "/")
	if u == "" {
		return "Untitled Page"
	}
	parts := strings.Split(u, "/")
	if len(parts) == 0 {
		return "Untitled Page"
	}
	last := strings.TrimSpace(parts[len(parts)-1])
	if last == "" {
		return "Untitled Page"
	}
	return last
}

func detectSourceID(client *http.Client, sitemapURL string, candidateURLs []string) (string, error) {
	archonAPI := strings.TrimSpace(os.Getenv("ARCHON_API"))
	if archonAPI == "" {
		archonAPI = defaultArchonAPI
	}
	endpoint := strings.TrimRight(archonAPI, "/") + "/rag/sources"
	status, body, err := doRequest(client, http.MethodGet, endpoint, nil, map[string]string{})
	if err != nil {
		return "", err
	}
	if status < 200 || status >= 300 {
		return "", fmt.Errorf("source auto-detect failed (%d): %s", status, strings.TrimSpace(string(body)))
	}

	searchBase := sitemapURL
	if len(candidateURLs) > 0 {
		searchBase = candidateURLs[0]
	}

	var decoded interface{}
	if err := json.Unmarshal(body, &decoded); err != nil {
		return "", err
	}

	items := make([]map[string]interface{}, 0)
	switch v := decoded.(type) {
	case []interface{}:
		for _, it := range v {
			if m, ok := it.(map[string]interface{}); ok {
				items = append(items, m)
			}
		}
	case map[string]interface{}:
		if arr, ok := v["sources"].([]interface{}); ok {
			for _, it := range arr {
				if m, ok := it.(map[string]interface{}); ok {
					items = append(items, m)
				}
			}
		}
	}

	if len(items) == 0 {
		return "", fmt.Errorf("no sources returned by archon api")
	}

	bestID := ""
	bestLen := -1
	for _, item := range items {
		id := extractID(item)
		if id == "" {
			continue
		}
		candidates := sourceURLCandidates(item)
		for _, c := range candidates {
			if c == "" {
				continue
			}
			if strings.HasPrefix(searchBase, c) && len(c) > bestLen {
				bestLen = len(c)
				bestID = id
			}
		}
	}

	if bestID != "" {
		return bestID, nil
	}
	return "", fmt.Errorf("unable to auto-detect source-id from %s", searchBase)
}

func extractID(item map[string]interface{}) string {
	keys := []string{"source_id", "id", "sourceId"}
	for _, k := range keys {
		if v, ok := item[k]; ok {
			s := strings.TrimSpace(fmt.Sprintf("%v", v))
			if s != "" && s != "<nil>" {
				return s
			}
		}
	}
	if nested, ok := item["source"].(map[string]interface{}); ok {
		for _, k := range keys {
			if v, ok := nested[k]; ok {
				s := strings.TrimSpace(fmt.Sprintf("%v", v))
				if s != "" && s != "<nil>" {
					return s
				}
			}
		}
	}
	return ""
}

func sourceURLCandidates(item map[string]interface{}) []string {
	out := make([]string, 0)
	keys := []string{"url", "source_url", "original_url"}
	for _, k := range keys {
		if v, ok := item[k]; ok {
			s := strings.TrimSpace(fmt.Sprintf("%v", v))
			if s != "" && s != "<nil>" {
				out = append(out, s)
			}
		}
	}
	if md, ok := item["metadata"].(map[string]interface{}); ok {
		for _, k := range keys {
			if v, ok := md[k]; ok {
				s := strings.TrimSpace(fmt.Sprintf("%v", v))
				if s != "" && s != "<nil>" {
					out = append(out, s)
				}
			}
		}
	}
	return out
}

func run() int {
	cfg, ok := parseFlags()
	if !ok {
		return 1
	}

	client := &http.Client{Timeout: 60 * time.Second}

	stdinURLs, err := readURLsFromStdin()
	if err != nil {
		fmt.Fprintf(os.Stderr, "error reading stdin URLs: %v\n", err)
		return 1
	}

	urls := make([]string, 0)
	if len(stdinURLs) > 0 {
		urls = stdinURLs
	} else {
		if strings.TrimSpace(cfg.SitemapURL) == "" {
			fmt.Fprintln(os.Stderr, "error: provide --sitemap-url or pipe URLs via stdin")
			return 1
		}
		urls, err = discoverURLsFromSitemap(client, cfg.SitemapURL)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error discovering sitemap URLs: %v\n", err)
			return 1
		}
	}

	urls = dedupeURLs(urls)
	urls, err = applyURLPattern(urls, cfg.URLPattern)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error compiling --url-pattern: %v\n", err)
		return 1
	}
	if len(urls) == 0 {
		fmt.Fprintln(os.Stderr, "error: no URLs to process after discovery/filter")
		return 1
	}

	if strings.TrimSpace(cfg.SourceID) == "" {
		autoID, detectErr := detectSourceID(client, cfg.SitemapURL, urls)
		if detectErr != nil {
			fmt.Fprintf(os.Stderr, "error auto-detecting source-id: %v\n", detectErr)
			return 1
		}
		cfg.SourceID = autoID
	}

	fmt.Println("=== Archon RAG Direct Injection ===")
	fmt.Printf("Source ID: %s\n", cfg.SourceID)
	fmt.Printf("Supabase: %s\n", cfg.SupabaseURL)
	fmt.Printf("Ollama: %s\n", cfg.OllamaURL)
	if cfg.SitemapURL != "" {
		fmt.Printf("Sitemap: %s\n", cfg.SitemapURL)
	}
	fmt.Printf("URLs: %d\n", len(urls))
	fmt.Printf("Tags: %s\n", strings.Join(cfg.Tags, ","))
	if cfg.DryRun {
		fmt.Println("Mode: DRY RUN")
	}
	if cfg.Force {
		fmt.Println("Mode: FORCE")
	}
	fmt.Println()

	if cfg.Force {
		if cfg.DryRun {
			fmt.Printf("[force] would delete existing rows for source_id=%s\n\n", cfg.SourceID)
		} else {
			if err := deleteExistingBySource(client, cfg.SupabaseURL, cfg.SupabaseKey, cfg.SourceID); err != nil {
				fmt.Fprintf(os.Stderr, "error deleting existing source rows: %v\n", err)
				return 1
			}
			fmt.Printf("[force] deleted existing rows for source_id=%s\n\n", cfg.SourceID)
		}
	}

	totalChunks := 0
	totalErrors := 0
	processedPages := 0

	for i, pageURL := range urls {
		slug := inferTitle(pageURL)
		fmt.Printf("[%d/%d] %s... ", i+1, len(urls), slug)

		htmlBytes, fetchErr := fetchURL(client, pageURL)
		if fetchErr != nil {
			fmt.Printf("FETCH ERROR: %v\n", fetchErr)
			totalErrors++
			continue
		}

		title, text := parseHTMLText(string(htmlBytes))
		if strings.TrimSpace(title) == "" {
			title = inferTitle(pageURL)
		}
		if len(text) < 50 {
			fmt.Printf("SKIP (too short: %d chars)\n", len(text))
			continue
		}

		chunks := chunkText(text, chunkSize)
		fmt.Printf("%d chars, %d chunks", len(text), len(chunks))

		if cfg.DryRun {
			fmt.Printf(" -> DRY RUN\n")
			processedPages++
			totalChunks += len(chunks)
			continue
		}

		pageID, metaErr := insertPageMetadata(client, cfg, pageURL, title, text, len(chunks))
		if metaErr != nil {
			fmt.Printf(" -> META FAILED: %v\n", metaErr)
			totalErrors++
			continue
		}

		pageErrors := 0
		for ci, chunk := range chunks {
			embedding, embErr := getEmbedding(client, cfg.OllamaURL, chunk)
			if embErr != nil {
				fmt.Printf("\n  CHUNK %d EMBED ERROR: %v", ci, embErr)
				pageErrors++
				continue
			}
			if len(embedding) != 768 {
				fmt.Printf("\n  CHUNK %d EMBED DIM WARNING: got %d", ci, len(embedding))
			}
			if err := insertChunk(client, cfg, pageURL, chunk, title, pageID, ci, embedding); err != nil {
				fmt.Printf("\n  CHUNK %d INSERT ERROR: %v", ci, err)
				pageErrors++
			}
		}

		processedPages++
		totalChunks += len(chunks)
		totalErrors += pageErrors
		if pageErrors == 0 {
			fmt.Printf(" -> OK\n")
		} else {
			fmt.Printf(" -> %d ERRORS\n", pageErrors)
		}

		time.Sleep(500 * time.Millisecond)
	}

	fmt.Println()
	fmt.Println("=== DONE ===")
	fmt.Printf("Pages processed: %d\n", processedPages)
	fmt.Printf("Total chunks: %d\n", totalChunks)
	fmt.Printf("Total errors: %d\n", totalErrors)

	if totalErrors > 0 {
		return 1
	}
	return 0
}

func main() {
	os.Exit(run())
}
