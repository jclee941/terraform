package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

type versionResponse struct {
	Version  string `json:"version"`
	Revision string `json:"revision"`
}

type project struct {
	ID            int    `json:"id"`
	Name          string `json:"name"`
	Path          string `json:"path"`
	SSHURLToRepo  string `json:"ssh_url_to_repo"`
	HTTPURLToRepo string `json:"http_url_to_repo"`
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
	os.Exit(1)
}

func main() {
	baseURL := flag.String("base-url", "http://192.168.50.215:8929", "GitLab base URL")
	projectName := flag.String("project", "", "Project name/path to verify for migration evidence")
	privateToken := flag.String("token", "", "GitLab personal access token (or use GITLAB_MIGRATION_PAT)")
	timeout := flag.Duration("timeout", 10*time.Second, "HTTP request timeout")
	flag.Parse()

	token := strings.TrimSpace(*privateToken)
	if token == "" {
		token = strings.TrimSpace(os.Getenv("GITLAB_MIGRATION_PAT"))
	}

	client := &http.Client{Timeout: *timeout}
	trimmedBase := strings.TrimRight(strings.TrimSpace(*baseURL), "/")
	if trimmedBase == "" {
		fail("base-url cannot be empty")
	}

	if err := checkSignIn(client, trimmedBase); err != nil {
		fail("sign-in endpoint check failed: %v", err)
	}

	version, err := checkVersion(client, trimmedBase, token)
	if err != nil {
		fail("version endpoint check failed: %v", err)
	}

	fmt.Printf("PASS: GitLab reachable at %s\n", trimmedBase)
	fmt.Printf("PASS: GitLab version endpoint responded: %s\n", version)

	if strings.TrimSpace(*projectName) == "" {
		fmt.Println("INFO: project verification skipped (no --project provided)")
		return
	}

	if token == "" {
		fail("project verification requested but token is missing (use --token or GITLAB_MIGRATION_PAT)")
	}

	matchedProject, err := verifyProjectExists(client, trimmedBase, token, strings.TrimSpace(*projectName))
	if err != nil {
		fail("project verification failed: %v", err)
	}

	fmt.Printf("PASS: Migration evidence project found: id=%d name=%q path=%q\n", matchedProject.ID, matchedProject.Name, matchedProject.Path)
	fmt.Printf("PASS: Clone URLs: ssh=%s http=%s\n", matchedProject.SSHURLToRepo, matchedProject.HTTPURLToRepo)
}

func checkSignIn(client *http.Client, baseURL string) error {
	req, err := http.NewRequest(http.MethodGet, baseURL+"/users/sign_in", nil)
	if err != nil {
		return err
	}

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusFound {
		return fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	return nil
}

func checkVersion(client *http.Client, baseURL string, token string) (string, error) {
	req, err := http.NewRequest(http.MethodGet, baseURL+"/api/v4/version", nil)
	if err != nil {
		return "", err
	}
	if token != "" {
		req.Header.Set("PRIVATE-TOKEN", token)
	}

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	var payload versionResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", err
	}

	if payload.Version == "" {
		return "", errors.New("version field empty")
	}

	if payload.Revision == "" {
		return payload.Version, nil
	}

	return fmt.Sprintf("%s (%s)", payload.Version, payload.Revision), nil
}

func verifyProjectExists(client *http.Client, baseURL, token, projectName string) (project, error) {
	endpoint := fmt.Sprintf("%s/api/v4/projects?search=%s", baseURL, url.QueryEscape(projectName))
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return project{}, err
	}
	req.Header.Set("PRIVATE-TOKEN", token)

	resp, err := client.Do(req)
	if err != nil {
		return project{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return project{}, fmt.Errorf("unexpected status %d", resp.StatusCode)
	}

	var projects []project
	if err := json.NewDecoder(resp.Body).Decode(&projects); err != nil {
		return project{}, err
	}

	for _, p := range projects {
		if p.Name == projectName || p.Path == projectName {
			return p, nil
		}
	}

	return project{}, fmt.Errorf("project %q not found in search results", projectName)
}
