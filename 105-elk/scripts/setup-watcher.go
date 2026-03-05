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
	if len(os.Args) != 4 {
		fmt.Fprintf(os.Stderr, "Usage: %s <ES_HOST> <WEBHOOK_URL> <WEBHOOK_SECRET>\n", os.Args[0])
		os.Exit(1)
	}

	esHost := os.Args[1]
	webhookURL := os.Args[2]
	webhookSecret := os.Args[3]

	fmt.Println("Registering ELK error alert watcher...")
	fmt.Printf("  ES_HOST:     %s\n", esHost)
	fmt.Printf("  WEBHOOK_URL: %s\n", webhookURL)

	// Build the watcher JSON - Mustache templates must be literal strings
	watcherBody := `{
  "trigger": {
    "schedule": {
      "interval": "5m"
    }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["logs-*"],
        "body": {
          "size": 0,
          "query": {
            "bool": {
              "filter": [
                { "range": { "@timestamp": { "gte": "now-5m" } } },
                { "terms": { "tier": [1, 2] } }
              ]
            }
          },
          "aggs": {
            "by_service": {
              "terms": { "field": "service.keyword", "size": 20 },
              "aggs": {
                "by_classification": {
                  "terms": { "field": "error_classification.keyword", "size": 10 },
                  "aggs": {
                    "severity": {
                      "terms": { "field": "error_severity.keyword", "size": 1 }
                    },
                    "tier": {
                      "min": { "field": "tier" }
                    },
                    "latest_message": {
                      "top_hits": {
                        "size": 1,
                        "_source": ["message", "@timestamp"],
                        "sort": [{ "@timestamp": "desc" }]
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  "condition": {
    "compare": {
      "ctx.payload.hits.total": { "gt": 0 }
    }
  },
  "throttle_period": "1h",
  "actions": {
    "create_github_issue": {
      "throttle_period": "1h",
      "webhook": {
        "method": "POST",
        "url": "` + webhookURL + `",
        "headers": {
          "Content-Type": "application/json",
          "Authorization": "Bearer ` + webhookSecret + `"
        },
        "body": "{\"watch_id\": \"{{ctx.watch_id}}\", \"payload\": {{#toJson}}ctx.payload{{/toJson}}}"
      }
    }
  }
}`

	url := esHost + "/_watcher/watch/elk-error-alerts"
	req, err := http.NewRequest("PUT", url, strings.NewReader(watcherBody))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating request: %v\n", err)
		os.Exit(1)
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error sending request: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading response: %v\n", err)
		os.Exit(1)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		fmt.Fprintf(os.Stderr, "HTTP Error: %d %s\n", resp.StatusCode, string(body))
		os.Exit(1)
	}

	// Pretty print response for debugging (optional, suppress if needed)
	var prettyJSON bytes.Buffer
	if err := json.Indent(&prettyJSON, body, "", "  "); err == nil {
		fmt.Println(string(prettyJSON.Bytes()))
	}

	fmt.Println("")
	fmt.Println("Watcher registered successfully.")
	fmt.Println("")
	fmt.Println("Verify:")
	fmt.Printf("  curl -s '%s/_watcher/watch/elk-error-alerts' | jq '.status'\n", esHost)
	fmt.Println("")
	fmt.Println("Test (manual trigger):")
	fmt.Printf("  curl -s -X POST '%s/_watcher/watch/elk-error-alerts/_execute' | jq '.result'\n", esHost)
	fmt.Println("")
	fmt.Println("Delete:")
	fmt.Printf("  curl -s -X DELETE '%s/_watcher/watch/elk-error-alerts'\n", esHost)
}
