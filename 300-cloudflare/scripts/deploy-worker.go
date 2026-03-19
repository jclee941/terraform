// deploy-worker.go — Guard stub: manual deployment is disabled.
// Deploy via CI/CD: push to master branch triggers worker-deploy.yml.
//
// Usage: go run 300-cloudflare/scripts/deploy-worker.go
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "ERROR: Manual deployment is disabled.")
	fmt.Fprintln(os.Stderr, "Deploy via CI/CD:")
	fmt.Fprintln(os.Stderr, "  1. Push changes to master branch")
	fmt.Fprintln(os.Stderr, "  2. worker-deploy.yml runs automatically")
	fmt.Fprintln(os.Stderr, "  See: https://github.com/qws941/terraform/actions/workflows/worker-deploy.yml")
	os.Exit(1)
}
