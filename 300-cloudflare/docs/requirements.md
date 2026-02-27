# 요구사항정의서 (Requirements Specification)

**프로젝트**: Cloudflare Secrets Management Hub & Synology Proxy Worker
**저장소**: [qws941/cloudflare](https://github.com/qws941/cloudflare)
**최종 수정**: 2026-02-12
**버전**: v1.0

---

## 1. 프로젝트 개요

`~/dev/` 하위 12개 이상의 사이드 프로젝트에서 사용하는 50여 개의 시크릿을 중앙에서 관리하고,
Synology NAS FileStation API를 Cloudflare Worker로 프록시하여 외부 접근을 제공하는 통합 플랫폼.

### 1.1 핵심 구성요소

| 모듈 | 기술 스택 | 역할 |
|------|-----------|------|
| **Terraform** | HCL (CF ~5.0, GitHub ~6.0, Vault ~4.0) | 인프라 프로비저닝 (시크릿, 터널, Access, R2, DNS) |
| **Worker** | TypeScript, Hono 4.x, Vitest | Synology FileStation 프록시 + R2 캐시 |
| **Scripts** | Bash | 시크릿 수집, 감사, 동기화, 바인딩 생성 |
| **Docker** | cloudflared | Synology NAS 터널 커넥터 |
| **CI** | GitHub Actions | lint + typecheck + test + terraform validate |
| **Inventory** | YAML | 시크릿 메타데이터 레지스트리 (SSoT) |

### 1.2 시크릿 분류 (42개, 11개 카테고리)

| 카테고리 | 시크릿 수 | 주요 항목 |
|----------|-----------|-----------|
| infrastructure | 8 | CF API, Proxmox, Vault token/addr |
| security | 2 | FortiAnalyzer |
| monitoring | 1 | ELK |
| messaging | 2 | Slack webhook/token |
| database | 2 | PostgreSQL |
| app_security | 5 | Flask, JWT, HMAC, encryption key |
| threat_intel | 4 | Regtech, Secudium, CF threat ingest |
| storage | 3 | MinIO |
| ai | 3 | Anthropic, OpenAI, Gemini |
| media | 4 | ElevenLabs, Replicate, Runway, Suno |
| external | 1 | FAS API |

---

## 2. 기능 요구사항 (Functional Requirements)

### FR-01: 시크릿 중앙 관리

| ID | 요구사항 | 우선순위 | 상태 | 관련 이슈 |
|----|----------|----------|------|-----------|
| FR-01-01 | `inventory/secrets.yaml`을 SSoT로 시크릿 메타데이터 관리 | P0 | 완료 | - |
| FR-01-02 | Terraform으로 YAML → 3개 타겟 스토어 프로비저닝 | P0 | 완료 | - |
| FR-01-03 | GitHub Actions Secrets 자동 동기화 (9개 저장소) | P0 | 완료 | - |
| FR-01-04 | HashiCorp Vault KV v2 시크릿 동기화 | P0 | 완료 | - |
| FR-01-05 | CF Secrets Store 동기화 (`enable_cf_store_sync` 플래그) | P1 | 미완료 | [#15] |
| FR-01-06 | 시크릿 수집 스크립트 (`collect.sh`) — 12개 프로젝트 스캔 | P0 | 완료 | - |
| FR-01-07 | 드리프트 감사 스크립트 (`audit.sh`) | P0 | 완료 | - |
| FR-01-08 | 시크릿 동기화 스크립트 (`sync.sh`) | P0 | 완료 | - |
| FR-01-09 | 시크릿 자동 로테이션 (rotate_days 기반) | P1 | 미완료 | [#16] |

### FR-02: Synology 프록시 Worker

| ID | 요구사항 | 우선순위 | 상태 | 관련 이슈 |
|----|----------|----------|------|-----------|
| FR-02-01 | FileStation API 인증 (SID 세션, 50분 캐시) | P0 | 완료 | - |
| FR-02-02 | 파일 목록 조회 API (`GET /api/files`) | P0 | 완료 | - |
| FR-02-03 | 파일 다운로드 API (`GET /api/files/download`) | P0 | 완료 | - |
| FR-02-04 | R2 캐시 레이어 (7일 TTL, APAC) | P0 | 완료 | - |
| FR-02-05 | 에러 핸들링 미들웨어 | P0 | 완료 | - |
| FR-02-06 | Worker 시크릿 설정 및 배포 | P0 | 미완료 | [#6] |
| FR-02-07 | E2E 검증 (목록, 다운로드, R2 캐시 히트) | P0 | 미완료 | [#5] |
| FR-02-08 | API 엔드포인트 Rate Limiting | P1 | 미완료 | [#10] |
| FR-02-09 | 구조화된 로깅 및 에러 모니터링 | P1 | 미완료 | [#11] |
| FR-02-10 | Synology Sharing API 파일 공유 | P2 | 미완료 | [#12] |
| FR-02-11 | R2 캐시 기반 썸네일 생성 | P2 | 미완료 | [#13] |

### FR-03: 네트워크 & 접근 제어

| ID | 요구사항 | 우선순위 | 상태 | 관련 이슈 |
|----|----------|----------|------|-----------|
| FR-03-01 | Zero Trust 터널 생성 (Terraform) | P0 | 완료 | - |
| FR-03-02 | cloudflared Docker 컨테이너 배포 (Synology NAS) | P0 | 미완료 | [#4] |
| FR-03-03 | CF Access 이메일 정책 (`synology.jclee.win`) | P0 | 완료 | - |
| FR-03-04 | 터널 연결 및 Synology API 도달성 검증 | P0 | 미완료 | [#3] |
| FR-03-05 | DNS 레코드 관리 (Terraform) | P0 | 완료 | - |

### FR-04: 사용자 인터페이스

| ID | 요구사항 | 우선순위 | 상태 | 관련 이슈 |
|----|----------|----------|------|-----------|
| FR-04-01 | Web UI: 파일 브라우저 프론트엔드 (CF Pages) | P2 | 미완료 | [#14] |

---

## 3. 비기능 요구사항 (Non-Functional Requirements)

### NFR-01: 보안

| ID | 요구사항 | 우선순위 | 상태 | 관련 이슈 |
|----|----------|----------|------|-----------|
| NFR-01-01 | 시크릿 값은 코드/Git에 절대 커밋하지 않음 | P0 | 완료 | - |
| NFR-01-02 | `.tfvars`, `.env`, `data/` 출력 파일 gitignore 처리 | P0 | 완료 | - |
| NFR-01-03 | Terraform 상태 파일에 민감 정보 포함 — Remote Backend 사용 | P1 | 미완료 | [#17] |
| NFR-01-04 | `collect.sh` 출력에 `DO NOT COMMIT` 헤더 포함 | P0 | 완료 | - |
| NFR-01-05 | Worker API Rate Limiting으로 남용 방지 | P1 | 미완료 | [#10] |

### NFR-02: CI/CD

| ID | 요구사항 | 우선순위 | 상태 | 관련 이슈 |
|----|----------|----------|------|-----------|
| NFR-02-01 | Worker CI: lint (Prettier) + typecheck (tsc) + test (Vitest) | P0 | 완료 | - |
| NFR-02-02 | Terraform CI: fmt check + validate | P0 | 완료 | - |
| NFR-02-03 | master 브랜치 push 트리거, CD 없음 (수동 apply/deploy) | P0 | 완료 | - |

### NFR-03: 운영

| ID | 요구사항 | 우선순위 | 상태 | 관련 이슈 |
|----|----------|----------|------|-----------|
| NFR-03-01 | R2 버킷 `synology-cache` APAC 리전, 7일 TTL | P0 | 완료 | - |
| NFR-03-02 | SID 세션 캐시 50분 만료 | P0 | 완료 | - |
| NFR-03-03 | 구조화된 로깅 및 에러 모니터링 | P1 | 미완료 | [#11] |

### NFR-04: 문서화

| ID | 요구사항 | 우선순위 | 상태 | 관련 이슈 |
|----|----------|----------|------|-----------|
| NFR-04-01 | 프로젝트 README (한국어) | P0 | 완료 | - |
| NFR-04-02 | AGENTS.md 계층 구조 (루트, Worker, Terraform) | P0 | 완료 | - |
| NFR-04-03 | 온보딩 및 운영 가이드 문서화 | P2 | 미완료 | [#18] |

---

## 4. 마일스톤 계획

### M1: Infrastructure Foundation (인프라 기반)

> 핵심 인프라 배포 및 기본 동작 검증

| 이슈 | 제목 | 라벨 |
|------|------|------|
| #3 | Verify tunnel connectivity and Synology API reachability | docker |
| #4 | Deploy cloudflared Docker container on Synology NAS | docker |
| #5 | E2E verification: file list, download, R2 cache hit | worker |
| #6 | Configure Worker secrets and deploy synology-proxy | worker |

**완료 기준**: 터널 연결 성공, Worker 배포 완료, E2E 검증 통과

---

### M2: Security & Observability (보안 강화 및 관측성)

> 프로덕션 운영을 위한 보안 및 모니터링 강화

| 이슈 | 제목 | 라벨 |
|------|------|------|
| #10 | Add rate limiting to Worker API endpoints | worker, security |
| #11 | Add structured logging and error monitoring | worker, security |
| #15 | Enable CF Secrets Store sync | terraform, security |
| #16 | Implement secret rotation automation | terraform, security |
| #17 | Migrate Terraform state to remote backend | terraform, security |

**완료 기준**: Rate limiting 적용, 로그 수집 시작, 시크릿 로테이션 자동화

---

### M3: Feature Expansion (기능 확장)

> 사용자 기능 확장 — 파일 공유 및 미디어 처리

| 이슈 | 제목 | 라벨 |
|------|------|------|
| #12 | File sharing via Synology Sharing API | worker, feature |
| #13 | Thumbnail generation via R2 cache | worker, feature |

**완료 기준**: 파일 공유 URL 생성 가능, 이미지 썸네일 자동 생성

---

### M4: Platform & Documentation (플랫폼 및 문서화)

> 사용자 인터페이스 구축 및 프로젝트 문서 정비

| 이슈 | 제목 | 라벨 |
|------|------|------|
| #14 | Web UI: file browser frontend (Pages) | feature |
| #18 | Onboarding and operations guide documentation | documentation |

**완료 기준**: 파일 브라우저 UI 배포, 운영 가이드 문서 완성

---

## 5. 이슈 추적 매트릭스 (Traceability Matrix)

| 이슈 | 제목 | 요구사항 ID | 마일스톤 |
|------|------|-------------|----------|
| #3 | Verify tunnel connectivity | FR-03-04 | M1 |
| #4 | Deploy cloudflared Docker | FR-03-02 | M1 |
| #5 | E2E verification | FR-02-07 | M1 |
| #6 | Configure & deploy Worker | FR-02-06 | M1 |
| #10 | Rate limiting | FR-02-08, NFR-01-05 | M2 |
| #11 | Structured logging | FR-02-09, NFR-03-03 | M2 |
| #12 | File sharing API | FR-02-10 | M3 |
| #13 | Thumbnail generation | FR-02-11 | M3 |
| #14 | Web UI file browser | FR-04-01 | M4 |
| #15 | CF Secrets Store sync | FR-01-05 | M2 |
| #16 | Secret rotation automation | FR-01-09 | M2 |
| #17 | Remote Terraform backend | NFR-01-03 | M2 |
| #18 | Onboarding & ops guide | NFR-04-03 | M4 |

---

## 6. 용어 정의

| 용어 | 설명 |
|------|------|
| SSoT | Single Source of Truth — 단일 진실 공급원 |
| CF | Cloudflare |
| SID | Session ID — Synology FileStation 인증 토큰 |
| R2 | Cloudflare R2 Object Storage |
| KV | Key-Value (HashiCorp Vault KV v2) |
| Zero Trust | Cloudflare Zero Trust 네트워크 접근 제어 |
| TTL | Time To Live — 캐시 만료 시간 |
| E2E | End-to-End (통합 테스트) |
