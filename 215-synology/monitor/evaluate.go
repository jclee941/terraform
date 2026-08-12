package main

import (
	"fmt"
	"strings"
)

func evaluateResources(resources []resource, limits thresholds) evaluation {
	result := evaluation{
		Issues:   make(map[string]issue),
		Observed: make(map[string]struct{}),
	}
	for _, current := range resources {
		if current.Template == 1 {
			continue
		}
		target, expectedStatus, statusSummary, statusAction, monitored := resourceIdentity(current)
		if !monitored {
			continue
		}

		statusKey := "status/" + current.ID
		result.Observed[statusKey] = struct{}{}
		if current.Status != expectedStatus {
			result.Issues[statusKey] = issue{
				Key:       statusKey,
				Severity:  "SEV-1",
				Target:    target,
				Summary:   statusSummary,
				Condition: fmt.Sprintf("status=%s, expected=%s", current.Status, expectedStatus),
				Action:    statusAction,
			}
		}

		if current.Type == "node" || current.Type == "qemu" || current.Type == "lxc" {
			addPressure(&result, "cpu", current, target, current.CPU*100, limits.CPUPercent)
			if current.MaxMem > 0 {
				addPressure(&result, "memory", current, target, current.Mem/current.MaxMem*100, limits.MemoryPercent)
			}
		}
		if current.MaxDisk > 0 {
			addPressure(&result, "disk", current, target, current.Disk/current.MaxDisk*100, limits.DiskPercent)
		}
	}
	return result
}

func resourceIdentity(current resource) (target, expectedStatus, summary, action string, monitored bool) {
	name := strings.TrimSpace(current.Name)
	if name != "" {
		name = " " + name
	}
	switch current.Type {
	case "node":
		return "PVE/Node/" + current.Node, "online", "Proxmox 노드 응답 불가", "노드 전원과 관리 네트워크를 확인", true
	case "qemu":
		return "PVE/VM/" + strings.TrimPrefix(current.ID, "qemu/") + name, "running", "가상 머신 중지", "VM 상태와 최근 작업을 확인", true
	case "lxc":
		return "PVE/LXC/" + strings.TrimPrefix(current.ID, "lxc/") + name, "running", "컨테이너 중지", "LXC 상태와 최근 작업을 확인", true
	case "storage":
		storageName := current.Storage
		if storageName == "" {
			parts := strings.Split(current.ID, "/")
			storageName = parts[len(parts)-1]
		}
		return "PVE/Storage/" + storageName, "available", "스토리지 사용 불가", "스토리지 연결과 백엔드 상태를 확인", true
	case "network":
		return "PVE/Network/" + strings.TrimPrefix(current.ID, "network/"), "ok", "SDN 네트워크 이상", "SDN zone과 브리지 상태를 확인", true
	default:
		return "", "", "", "", false
	}
}

func addPressure(result *evaluation, metric string, current resource, target string, actual, limit float64) {
	key := "pressure/" + metric + "/" + current.ID
	result.Observed[key] = struct{}{}
	if actual < limit {
		return
	}

	summary := map[string]string{
		"cpu":    "CPU 사용률 임계치 초과",
		"memory": "메모리 사용률 임계치 초과",
		"disk":   "디스크 사용률 임계치 초과",
	}[metric]
	result.Issues[key] = issue{
		Key:       key,
		Severity:  "SEV-2",
		Target:    target,
		Summary:   summary,
		Condition: fmt.Sprintf("%s %.1f%% >= %.1f%%", metric, actual, limit),
		Action:    "사용량 추세와 상위 소비 프로세스를 확인",
	}
}
