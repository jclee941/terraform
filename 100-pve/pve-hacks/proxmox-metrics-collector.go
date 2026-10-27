// proxmox-metrics-collector collects Proxmox node + guest resource metrics as NDJSON.
//
// WHY: the ELK stack (LXC 105) had no hypervisor-level visibility — balloon
// targets, thin-pool fill, per-guest memory and node CPU are only visible on
// the PVE host. This collector fills that gap via the existing host Filebeat.
//
// Pipeline: systemd timer (60s) -> /var/log/proxmox-metrics/metrics.jsonl
// -> host Filebeat (input id: pve-proxmox-metrics) -> Logstash (beats 5044)
// -> Elasticsearch index logs-proxmox-metrics-* (ILM homelab-logs-30d).
//
// Build:  go build -o proxmox-metrics-collector proxmox-metrics-collector.go
// Deploy: binary -> /root/pve-hacks/, units -> /etc/systemd/system/,
//         logrotate -> /etc/logrotate.d/proxmox-metrics, then
//         systemctl daemon-reload && systemctl enable --now proxmox-metrics-collector.timer
// Rollback: systemctl disable --now proxmox-metrics-collector.timer, remove
//         the three installed files, and drop the pve-proxmox-metrics input
//         from /etc/filebeat/filebeat.yml, then systemctl restart filebeat.
//
// Stdlib only. Every probe is failure-tolerant: a failing section is omitted
// from the document instead of crashing the timer run.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	outDir     = "/var/log/proxmox-metrics"
	cmdTimeout = 10 * time.Second
)

func run(name string, args ...string) (string, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), cmdTimeout)
	defer cancel()
	out, err := exec.CommandContext(ctx, name, args...).Output()
	if err != nil {
		return "", false
	}
	return string(out), true
}

func runWithInput(name, input string, args ...string) (string, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), cmdTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdin = strings.NewReader(input)
	out, err := cmd.Output()
	if err != nil {
		return "", false
	}
	return string(out), true
}

func readProcStat() (idle, total uint64, err error) {
	b, err := os.ReadFile("/proc/stat")
	if err != nil {
		return 0, 0, err
	}
	fields := strings.Fields(strings.SplitN(string(b), "\n", 2)[0])[1:]
	var vals []uint64
	for _, f := range fields {
		v, _ := strconv.ParseUint(f, 10, 64)
		vals = append(vals, v)
		total += v
	}
	if len(vals) < 5 {
		return 0, 0, fmt.Errorf("short /proc/stat")
	}
	return vals[3] + vals[4], total, nil
}

func nodeCPU() map[string]any {
	i1, t1, err := readProcStat()
	if err != nil {
		return nil
	}
	time.Sleep(300 * time.Millisecond)
	i2, t2, err := readProcStat()
	if err != nil || t2 <= t1 {
		return nil
	}
	busy := math.Round((1-float64(i2-i1)/float64(t2-t1))*1000) / 10
	return map[string]any{"busy_pct": busy}
}

func nodeMemory() (mem, swap map[string]any) {
	b, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return nil, nil
	}
	info := map[string]uint64{}
	for _, line := range strings.Split(string(b), "\n") {
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			v, _ := strconv.ParseUint(parts[1], 10, 64)
			info[strings.TrimSuffix(parts[0], ":")] = v / 1024 // kB -> MB
		}
	}
	total, avail := info["MemTotal"], info["MemAvailable"]
	if total == 0 {
		return nil, nil
	}
	used := total - avail
	mem = map[string]any{
		"total_mb": total, "used_mb": used, "avail_mb": avail,
		"used_pct": math.Round(float64(used)/float64(total)*1000) / 10,
	}
	swap = map[string]any{
		"total_mb": info["SwapTotal"],
		"used_mb":  info["SwapTotal"] - info["SwapFree"],
	}
	return mem, swap
}

func nodeLoad() map[string]any {
	b, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return nil
	}
	f := strings.Fields(string(b))
	if len(f) < 3 {
		return nil
	}
	l1, _ := strconv.ParseFloat(f[0], 64)
	l5, _ := strconv.ParseFloat(f[1], 64)
	l15, _ := strconv.ParseFloat(f[2], 64)
	return map[string]any{"l1": l1, "l5": l5, "l15": l15, "threads": 8}
}

func nodeSwapCounters() map[string]any {
	b, err := os.ReadFile("/proc/vmstat")
	if err != nil {
		return nil
	}
	out := map[string]any{}
	for _, line := range strings.Split(string(b), "\n") {
		f := strings.Fields(line)
		if len(f) == 2 && (f[0] == "pswpin" || f[0] == "pswpout") {
			v, _ := strconv.ParseInt(f[1], 10, 64)
			out[f[0]] = v
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

type lvsReport struct {
	Report []struct {
		LV []struct {
			VG   string `json:"vg_name"`
			LV   string `json:"lv_name"`
			Data string `json:"data_percent"`
			Meta string `json:"metadata_percent"`
		} `json:"lv"`
	} `json:"report"`
}

func thinPools() []map[string]any {
	out, ok := run("lvs", "--reportformat", "json", "--units", "m", "--nosuffix",
		"-o", "vg_name,lv_name,data_percent,metadata_percent")
	if !ok {
		return nil
	}
	var rep lvsReport
	if json.Unmarshal([]byte(out), &rep) != nil {
		return nil
	}
	var pools []map[string]any
	for _, r := range rep.Report {
		for _, lv := range r.LV {
			if lv.LV != "data" {
				continue
			}
			d, _ := strconv.ParseFloat(lv.Data, 64)
			m, _ := strconv.ParseFloat(lv.Meta, 64)
			pools = append(pools, map[string]any{
				"vg": lv.VG,
				"data_pct": math.Round(d*100) / 100,
				"meta_pct": math.Round(m*100) / 100,
			})
		}
	}
	return pools
}

func pvesh(path string) map[string]any {
	out, ok := run("pvesh", "get", path, "--output-format", "json")
	if !ok {
		return nil
	}
	var m map[string]any
	if json.Unmarshal([]byte(out), &m) != nil {
		return nil
	}
	return m
}

func mb(v any) int64 {
	f, _ := v.(float64)
	return int64(math.Round(f / 1048576))
}

func qemuGuests(node string) []map[string]any {
	out, ok := run("qm", "list")
	if !ok {
		return nil
	}
	var guests []map[string]any
	for i, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if i == 0 {
			continue
		}
		f := strings.Fields(line)
		if len(f) < 3 {
			continue
		}
		vmid, name, status := f[0], f[1], f[2]
		g := map[string]any{"vmid": vmid, "name": name, "gtype": "qemu", "status": status}
		if status == "running" {
			if st := pvesh(fmt.Sprintf("/nodes/%s/qemu/%s/status/current", node, vmid)); st != nil {
				g["cpus"] = st["cpus"]
				mem := map[string]any{"used_mb": mb(st["mem"]), "max_mb": mb(st["maxmem"])}
				if mon, ok := runWithInput("qm", "info balloon\n", "monitor", vmid); ok {
					for _, tok := range strings.Fields(mon) {
						if v, ok := strings.CutPrefix(tok, "actual="); ok {
							if n, err := strconv.ParseInt(v, 10, 64); err == nil {
								mem["balloon_mb"] = n
							}
						}
					}
				}
				g["mem"] = mem
			}
		}
		guests = append(guests, g)
	}
	return guests
}

func lxcGuests(node string) []map[string]any {
	out, ok := run("pct", "list")
	if !ok {
		return nil
	}
	var guests []map[string]any
	for i, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if i == 0 {
			continue
		}
		f := strings.Fields(line)
		if len(f) < 3 {
			continue
		}
		vmid, status, name := f[0], f[1], f[len(f)-1]
		g := map[string]any{"vmid": vmid, "name": name, "gtype": "lxc", "status": status}
		if status == "running" {
			if st := pvesh(fmt.Sprintf("/nodes/%s/lxc/%s/status/current", node, vmid)); st != nil {
				g["cpus"] = st["cpus"]
				g["mem"] = map[string]any{
					"used_mb": mb(st["mem"]), "max_mb": mb(st["maxmem"]),
					"swap_mb": mb(st["swap"]), "swap_max_mb": mb(st["maxswap"]),
				}
			}
		}
		guests = append(guests, g)
	}
	return guests
}

func main() {
	node, err := os.Hostname()
	if err != nil {
		node = "pve"
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		fmt.Fprintln(os.Stderr, "mkdir:", err)
		os.Exit(1)
	}
	ts := time.Now().UTC().Format(time.RFC3339Nano)

	var docs []map[string]any
	nodeDoc := map[string]any{"@timestamp": ts, "kind": "node", "node": node}
	if v := nodeCPU(); v != nil {
		nodeDoc["cpu"] = v
	}
	if v := nodeLoad(); v != nil {
		nodeDoc["load"] = v
	}
	if v := nodeSwapCounters(); v != nil {
		nodeDoc["swap_counters"] = v
	}
	if v := thinPools(); len(v) > 0 {
		nodeDoc["thinpool"] = v
	}
	if mem, swap := nodeMemory(); mem != nil {
		nodeDoc["mem"] = mem
		nodeDoc["swap"] = swap
	}
	if mem, swap := nodeMemory(); mem != nil {
		nodeDoc["mem"] = mem
		nodeDoc["swap"] = swap
	}
	docs = append(docs, nodeDoc)

	for _, g := range append(qemuGuests(node), lxcGuests(node)...) {
		g["@timestamp"] = ts
		g["kind"] = "guest"
		g["node"] = node
		docs = append(docs, g)
	}

	f, err := os.OpenFile(filepath.Join(outDir, "metrics.jsonl"),
		os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		fmt.Fprintln(os.Stderr, "open:", err)
		os.Exit(1)
	}
	defer f.Close()
	enc := json.NewEncoder(f)
	for _, d := range docs {
		if err := enc.Encode(d); err != nil {
			fmt.Fprintln(os.Stderr, "encode:", err)
			os.Exit(1)
		}
	}
}
