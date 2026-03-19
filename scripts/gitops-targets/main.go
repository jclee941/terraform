package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"
)

type listFlag []string

func (f *listFlag) String() string {
	return strings.Join(*f, ",")
}

func (f *listFlag) Set(value string) error {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return errors.New("empty value is not allowed")
	}
	*f = append(*f, trimmed)
	return nil
}

type targetDefinition struct {
	Name          string
	Dir           string
	ApplyWorkflow string
	Prefixes      []string
	AutoApply     bool
}

type target struct {
	Name          string `json:"name"`
	Dir           string `json:"dir"`
	ApplyWorkflow string `json:"apply_workflow"`
	Reason        string `json:"reason"`
}

type planOutput struct {
	Mode        string   `json:"mode"`
	Selectors   []string `json:"selectors,omitempty"`
	ChangedPath []string `json:"changed_paths,omitempty"`
	AutoApply   []target `json:"auto_apply"`
	ReportOnly  []target `json:"report_only"`
}

var catalog = []targetDefinition{
	{
		Name:          "traefik",
		Dir:           "102-traefik/terraform",
		ApplyWorkflow: "traefik-apply.yml",
		Prefixes:      []string{"102-traefik/"},
		AutoApply:     true,
	},
	{
		Name:          "archon",
		Dir:           "108-archon/terraform",
		ApplyWorkflow: "archon-apply.yml",
		Prefixes:      []string{"108-archon/"},
		AutoApply:     true,
	},
	{
		Name:          "github",
		Dir:           "301-github",
		ApplyWorkflow: "github-apply.yml",
		Prefixes:      []string{"301-github/", "modules/shared/onepassword-secrets/"},
		AutoApply:     true,
	},
	{
		Name:          "proxmox",
		Dir:           "100-pve",
		ApplyWorkflow: "terraform-apply.yml",
		Prefixes:      []string{"100-pve/", "modules/"},
		AutoApply:     false,
	},
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}

func run() error {
	fs := flag.NewFlagSet("gitops-targets", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	mode := fs.String("mode", "dry-run", "Execution mode: dry-run or reconcile")
	var selectors listFlag
	var changedPaths listFlag
	fs.Var(&selectors, "workspace", "Workspace selector (repeatable): traefik, archon, github, proxmox, or exact dir")
	fs.Var(&changedPaths, "changed-path", "Changed path (repeatable)")

	if err := fs.Parse(os.Args[1:]); err != nil {
		return err
	}

	plan, err := buildPlan(*mode, selectors, changedPaths)
	if err != nil {
		return err
	}

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	return encoder.Encode(plan)
}

func buildPlan(mode string, selectors, changedPaths []string) (planOutput, error) {
	if mode != "dry-run" && mode != "reconcile" {
		return planOutput{}, fmt.Errorf("invalid --mode %q: expected dry-run or reconcile", mode)
	}

	plan := planOutput{
		Mode:        mode,
		Selectors:   normalizeList(selectors),
		ChangedPath: normalizeList(changedPaths),
		AutoApply:   []target{},
		ReportOnly:  []target{},
	}

	if len(plan.Selectors) > 0 {
		for _, selector := range plan.Selectors {
			definition, ok := resolveSelector(selector)
			if !ok {
				return planOutput{}, fmt.Errorf("unknown workspace selector %q", selector)
			}
			reason := fmt.Sprintf("selected by workspace override %q", selector)
			appendTarget(&plan, definition, reason)
		}
		return plan, nil
	}

	if len(plan.ChangedPath) == 0 {
		for _, definition := range catalog {
			if !definition.AutoApply {
				continue
			}
			appendTarget(&plan, definition, "included in scheduled reconcile allowlist")
		}
		return plan, nil
	}

	for _, path := range plan.ChangedPath {
		for _, definition := range catalog {
			if !matchesPrefix(path, definition.Prefixes) {
				continue
			}
			reason := fmt.Sprintf("matched changed path %q", path)
			appendTarget(&plan, definition, reason)
		}
	}

	return plan, nil
}

func normalizeList(values []string) []string {
	normalized := make([]string, 0, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		normalized = append(normalized, trimmed)
	}
	return normalized
}

func resolveSelector(selector string) (targetDefinition, bool) {
	normalized := strings.ToLower(strings.TrimSpace(selector))
	for _, definition := range catalog {
		if normalized == definition.Name || normalized == strings.ToLower(definition.Dir) {
			return definition, true
		}
	}
	return targetDefinition{}, false
}

func matchesPrefix(path string, prefixes []string) bool {
	for _, prefix := range prefixes {
		if strings.HasPrefix(path, prefix) {
			return true
		}
	}
	return false
}

func appendTarget(plan *planOutput, definition targetDefinition, reason string) {
	if definition.AutoApply {
		if containsTarget(plan.AutoApply, definition.Name) {
			return
		}
		plan.AutoApply = append(plan.AutoApply, target{
			Name:          definition.Name,
			Dir:           definition.Dir,
			ApplyWorkflow: definition.ApplyWorkflow,
			Reason:        reason,
		})
		return
	}

	if containsTarget(plan.ReportOnly, definition.Name) {
		return
	}
	plan.ReportOnly = append(plan.ReportOnly, target{
		Name:          definition.Name,
		Dir:           definition.Dir,
		ApplyWorkflow: definition.ApplyWorkflow,
		Reason:        reason,
	})
}

func containsTarget(targets []target, name string) bool {
	for _, target := range targets {
		if target.Name == name {
			return true
		}
	}
	return false
}
