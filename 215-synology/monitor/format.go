package main

import (
	"fmt"
	"strings"
	"time"
)

var korea = time.FixedZone("KST", 9*60*60)

func formatEvent(event alertEvent, runbookURL string) string {
	started := event.StartedAt.In(korea).Format("01-02 15:04 KST")
	occurred := event.OccurredAt.In(korea).Format("01-02 15:04 KST")
	duration := formatDuration(event.Duration)

	var lines []string
	switch event.Kind {
	case eventFiring:
		condition := event.Issue.Condition
		if event.Confirmations > 0 {
			condition += fmt.Sprintf(" · %d회 연속", event.Confirmations)
		}
		lines = []string{
			fmt.Sprintf("🚨 장애 발생 · %s · %s", event.Issue.Severity, event.Issue.Target),
			event.Issue.Summary,
			"조건: " + condition,
			fmt.Sprintf("시작: %s · 지속: %s", started, duration),
			"조치: " + event.Issue.Action,
		}
	case eventResolved:
		lines = []string{
			fmt.Sprintf("✅ 복구 완료 · %s · %s", event.Issue.Severity, event.Issue.Target),
			event.Issue.Summary,
			"해소: 정상 범위 복귀",
			fmt.Sprintf("지속: %s · 종료: %s", duration, occurred),
			"후속: 원인과 재발 여부를 확인",
		}
	}
	if runbookURL != "" {
		lines = append(lines, "런북: "+runbookURL)
	}
	return strings.Join(lines, "\n")
}

func formatDuration(duration time.Duration) string {
	if duration < time.Minute {
		return "1분 미만"
	}
	minutes := int(duration.Round(time.Minute) / time.Minute)
	if minutes < 60 {
		return fmt.Sprintf("%d분", minutes)
	}
	return fmt.Sprintf("%d시간 %d분", minutes/60, minutes%60)
}
