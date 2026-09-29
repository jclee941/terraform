package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

type monitor struct {
	config  config
	client  *http.Client
	machine *stateMachine
	logger  *slog.Logger
	dryRun  bool
}

func main() {
	once := flag.Bool("once", false, "run one monitoring cycle and exit")
	dryRun := flag.Bool("dry-run", false, "print notifications instead of sending them")
	testNotification := flag.Bool("test-notification", false, "send one Telegram route test and exit")
	flag.Parse()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	settings, err := loadConfig()
	if err != nil {
		logger.Error("monitor.config", "error", err)
		os.Exit(2)
	}
	state, err := loadState(settings.StatePath)
	if err != nil {
		logger.Error("monitor.state.load", "error", err)
		os.Exit(1)
	}
	service := monitor{
		config: settings, client: newHTTPClient(settings.Insecure),
		machine: newStateMachine(settings.FailureThreshold, state), logger: logger, dryRun: *dryRun,
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if *testNotification {
		if err := service.sendRouteTest(ctx); err != nil {
			logger.Error("monitor.notification.test", "error", err)
			os.Exit(1)
		}
		logger.Info("monitor.notification.test", "status", "sent")
		return
	}
	if *once {
		if err := service.runCycle(ctx, time.Now()); err != nil {
			logger.Error("monitor.cycle", "error", err)
			os.Exit(1)
		}
		return
	}

	if err := service.run(ctx); err != nil {
		logger.Error("monitor.run", "error", err)
		os.Exit(1)
	}
}

func (service monitor) run(ctx context.Context) error {
	if err := service.runCycle(ctx, time.Now()); err != nil {
		service.logger.Error("monitor.cycle", "error", err)
	}
	ticker := time.NewTicker(service.config.Interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return nil
		case now := <-ticker.C:
			if err := service.runCycle(ctx, now); err != nil {
				service.logger.Error("monitor.cycle", "error", err)
			}
		}
	}
}

func (service monitor) runCycle(ctx context.Context, now time.Time) error {
	resources, fetchErr := fetchResources(ctx, service.client, service.config.ProxmoxEndpoint, service.config.ProxmoxToken)
	current := evaluation{Issues: make(map[string]issue), Observed: map[string]struct{}{"api/control-plane": {}}}
	if fetchErr != nil {
		current.Issues["api/control-plane"] = issue{
			Key: "api/control-plane", Severity: "SEV-1", Target: "PVE/API",
			Summary: "Proxmox API 응답 불가", Condition: fetchErr.Error(),
			Action: "노드 전원, 관리 네트워크, API 인증을 확인",
		}
		service.logger.Warn("monitor.proxmox.fetch", "error", fetchErr)
	} else {
		current = evaluateResources(resources, service.config.Limits)
		current.Observed["api/control-plane"] = struct{}{}
	}

	var sendErrors []error
	for _, event := range service.machine.evaluate(now, current) {
		message := formatEvent(event, service.config.RunbookURL)
		if service.dryRun {
			fmt.Println(message)
			service.machine.markSent(event)
			continue
		}
		if err := sendTelegram(ctx, service.client, service.config.TelegramAPIBase, service.config.TelegramToken, service.config.TelegramChatID, message); err != nil {
			sendErrors = append(sendErrors, err)
			continue
		}
		service.machine.markSent(event)
		service.logger.Info("monitor.notification", "kind", event.Kind, "target", event.Issue.Target)
	}
	if err := saveState(service.config.StatePath, now, service.machine.state); err != nil {
		sendErrors = append(sendErrors, err)
	}
	return errors.Join(sendErrors...)
}

func (service monitor) sendRouteTest(ctx context.Context) error {
	resources, err := fetchResources(ctx, service.client, service.config.ProxmoxEndpoint, service.config.ProxmoxToken)
	if err != nil {
		return err
	}
	message := fmt.Sprintf(
		"ℹ️ 모니터링 테스트 · PVE/전체\n상태: Telegram 알림 경로 정상\n대상: %d개 Proxmox 리소스 확인\n시각: %s",
		len(resources), time.Now().In(korea).Format("01-02 15:04 KST"),
	)
	if service.dryRun {
		fmt.Println(message)
		return nil
	}
	return sendTelegram(ctx, service.client, service.config.TelegramAPIBase, service.config.TelegramToken, service.config.TelegramChatID, message)
}
