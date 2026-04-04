# GitLab Runner 테스트 절차

## 사전 준비사항

1. GitLab Runner 등록 토큰 필요
   - GitLab UI 접속: http://gitlab.jclee.me
   - Admin Area > Runners 또는 프로젝트 > Settings > CI/CD > Runners
   - "New runner" 클릭 후 토큰 복사

2. LXC 101 접근 권한 확인
   - SSH: `ssh root@192.168.50.101`

---

## 테스트 단계

### 1. LXC 상태 확인 (Proxmox 호스트에서)

```bash
# LXC 101 상태 확인
pct status 101
pct exec 101 -- systemctl status gitlab-runner 2>&1 || echo "Service not found"
```

**예상 결과:**
- Status: `running`
- Memory: ~83MB / 768MB
- Service: 아직 설치되지 않았을 수 있음 (정상)

---

### 2. GitLab Runner 설치 및 설정

```bash
# LXC 101에 SSH 접속
ssh root@192.168.50.101

# 스크립트 확인
cd /opt/runner/scripts
go build -o /tmp/setup-gitlab-runner setup-gitlab-runner.go

# Runner 설치 (토큰 필요)
export GITLAB_RUNNER_TOKEN="<your-registration-token>"
export GITLAB_URL="http://gitlab.jclee.me"
go run setup-gitlab-runner.go
```

**성공 지표:**
- `[+] GitLab Runner Setup` 메시지 출력
- `[+] GitLab Runner installed to /usr/local/bin/gitlab-runner`
- `[+] Runner registered successfully`
- `[+] GitLab Runner service installed and started`

---

### 3. 서비스 상태 검증

```bash
# systemd 서비스 상태
systemctl status gitlab-runner

# 예상 출력:
# ● gitlab-runner.service - GitLab Runner
#    Loaded: loaded (/etc/systemd/system/gitlab-runner.service; enabled)
#    Active: active (running) since ...

# 러너 목록 확인
gitlab-runner list

# 예상 출력:
# Runtime platform                                    arch=amd64 os=linux pid=...
# Listing configured runners                          ConfigFile=/opt/gitlab-runner/config.toml
# homelab-101                                         Executor=docker Token=... URL=http://gitlab.jclee.me
```

---

### 4. GitLab UI에서 러너 확인

1. GitLab 접속: http://gitlab.jclee.me
2. Admin Area > Runners 또는 프로젝트 > Settings > CI/CD > Runners
3. `homelab-101` 러너가 "online" 상태인지 확인
4. Tags: `homelab,docker,linux,terraform` 확인

---

### 5. 테스트 파이프라인 실행

테스트용 `.gitlab-ci.yml`:

```yaml
test-runner:
  tags:
    - terraform
  image: hashicorp/terraform:1.10.5
  script:
    - echo "Runner test successful!"
    - terraform version
    - docker --version
```

**검증 포인트:**
- Job이 `homelab-101` 러너에서 실행됨
- Terraform 버전 출력: 1.10.5
- Docker 버전 출력

---

### 6. 문제 해결

#### 문제: "No runner available"

```bash
# 러너 로그 확인
journalctl -u gitlab-runner -f

# 등록 재시도
gitlab-runner unregister --name homelab-101 2>/dev/null || true
rm -f /opt/gitlab-runner/config.toml
GITLAB_RUNNER_TOKEN=<token> go run /opt/runner/scripts/setup-gitlab-runner.go
```

#### 문제: "Cannot connect to Docker daemon"

```bash
# Docker 서비스 확인
systemctl status docker
systemctl restart docker
usermod -aG docker gitlab-runner
systemctl restart gitlab-runner
```

#### 문제: 메모리 부족 (OOM)

```bash
# LXC 메모리 확인
free -h

# Terraform locals.tf에서 메모리 증가 필요:
# gitlab-runner = { memory = 1536, swap = 1024, ... }
# 그 후: terraform apply
```

#### 문제: GitLab 연결 실패

```bash
# GitLab 인스턴스 접근 확인
curl -I http://gitlab.jclee.me
ping -c 3 192.168.50.215

# DNS 확인
cat /etc/resolv.conf
```

---

### 7. 정리 (필요시)

```bash
# 러너 등록 해제
gitlab-runner unregister --name homelab-101

# 서비스 중지 및 비활성화
systemctl stop gitlab-runner
systemctl disable gitlab-runner
rm -f /etc/systemd/system/gitlab-runner.service
systemctl daemon-reload

# 설정 삭제
rm -rf /opt/gitlab-runner
```

---

## 검증 체크리스트

- [ ] LXC 101이 running 상태
- [ ] GitLab Runner 바이너리 설치됨 (`/usr/local/bin/gitlab-runner`)
- [ ] Docker 설치 및 실행 중
- [ ] `/opt/gitlab-runner/config.toml` 생성됨
- [ ] systemd 서비스 등록됨 (`gitlab-runner.service`)
- [ ] 서비스가 active (running) 상태
- [ ] GitLab UI에서 러너가 online으로 표시
- [ ] 테스트 파이프라인이 러너에서 실행됨

---

## 참고: 현재 LXC 101 상태

| 항목 | 값 |
|------|-----|
| 상태 | 🟢 Running |
| IP | 192.168.50.101 |
| Memory | 768 MB (현재 83 MB 사용) |
| Uptime | 3일 6시간 |
| Node | pve3 |

**네트워크 연결:** SSH 포트 22 개방됨
