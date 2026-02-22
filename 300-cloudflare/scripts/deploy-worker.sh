#!/usr/bin/env bash
# Manual worker deployment is disabled.
# Deploy via CI/CD: push to master branch triggers worker-deploy.yml
set -euo pipefail
echo "ERROR: Manual deployment is disabled." >&2
echo "Deploy via CI/CD:" >&2
echo "  1. Push changes to master branch" >&2
echo "  2. worker-deploy.yml runs automatically" >&2
echo "  See: https://github.com/qws941/terraform/actions/workflows/worker-deploy.yml" >&2
exit 1
