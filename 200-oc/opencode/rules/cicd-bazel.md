---
name: cicd-bazel
description: Bazel 기반 모노리포 CI/CD 설정 가이드 (GitLab)
globs:
  - '**/.gitlab-ci.yml'
  - '**/Jenkinsfile'
  - '**/.github/workflows/*.yml'
alwaysApply: false
---

# Bazel 모노리포 CI/CD 설정

Google3 스타일 모노리포를 위한 CI/CD 파이프라인 구성.

## 1. GitLab CI/CD 기본 구조

### `.gitlab-ci.yml` (프로젝트 루트)

```yaml
# ============================================
# Bazel Monorepo CI/CD Pipeline
# ============================================

variables:
  BAZEL_VERSION: "9.0.0"
  BAZEL_CACHE: "${CI_PROJECT_DIR}/.bazel-cache"
  # 원격 캐시 (선택사항)
  # BAZEL_REMOTE_CACHE: "grpcs://cache.example.com"

# ============================================
# 캐시 설정
# ============================================
.bazel_cache: &bazel_cache
  cache:
    key: bazel-${CI_COMMIT_REF_SLUG}
    paths:
      - .bazel-cache/
    policy: pull-push

# ============================================
# 기본 이미지 및 설정
# ============================================
default:
  image: gcr.io/bazel-public/bazel:${BAZEL_VERSION}
  before_script:
    - bazel --version
    - echo "build --disk_cache=${BAZEL_CACHE}" >> .bazelrc.ci
    - echo "build --config=ci" >> .bazelrc.ci

# ============================================
# 스테이지 정의
# ============================================
stages:
  - analyze      # 변경 분석
  - build        # 빌드
  - test         # 테스트
  - security     # 보안 스캔
  - deploy       # 배포

# ============================================
# 변경 분석 (영향받는 타겟만 빌드)
# ============================================
analyze:affected:
  stage: analyze
  <<: *bazel_cache
  script:
    - |
      # 변경된 파일에서 영향받는 타겟 추출
      git diff --name-only origin/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-main}...HEAD > changed_files.txt
      
      # Bazel query로 영향받는 타겟 찾기
      bazel query "rdeps(//..., set($(cat changed_files.txt | tr '\n' ' ')))" \
        --output=label > affected_targets.txt || true
      
      echo "Affected targets:"
      cat affected_targets.txt
  artifacts:
    paths:
      - affected_targets.txt
      - changed_files.txt
    expire_in: 1 hour
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

# ============================================
# 빌드 스테이지
# ============================================
build:all:
  stage: build
  <<: *bazel_cache
  script:
    - bazel build //...
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

build:affected:
  stage: build
  <<: *bazel_cache
  needs: ["analyze:affected"]
  script:
    - |
      if [ -s affected_targets.txt ]; then
        # 빌드 타겟만 필터링
        grep -E "^//" affected_targets.txt | \
          grep -v "_test$" | \
          xargs -r bazel build
      else
        echo "No affected build targets"
      fi
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

# ============================================
# 테스트 스테이지
# ============================================
test:all:
  stage: test
  <<: *bazel_cache
  script:
    - bazel test //... --test_output=errors
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

test:affected:
  stage: test
  <<: *bazel_cache
  needs: ["analyze:affected"]
  script:
    - |
      if [ -s affected_targets.txt ]; then
        # 테스트 타겟만 필터링
        grep -E "_test$" affected_targets.txt | \
          xargs -r bazel test --test_output=errors
      else
        echo "No affected test targets"
      fi
  artifacts:
    when: always
    reports:
      junit: bazel-testlogs/**/test.xml
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

# ============================================
# 언어별 빌드/테스트
# ============================================
.lang_template: &lang_template
  <<: *bazel_cache
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - "${LANG_DIR}/**/*"

build:java:
  stage: build
  <<: *lang_template
  variables:
    LANG_DIR: "java"
  script:
    - bazel build //java/...

build:go:
  stage: build
  <<: *lang_template
  variables:
    LANG_DIR: "go"
  script:
    - bazel build //go/...

build:python:
  stage: build
  <<: *lang_template
  variables:
    LANG_DIR: "python"
  script:
    - bazel build //python/...

build:typescript:
  stage: build
  <<: *lang_template
  variables:
    LANG_DIR: "typescript"
  script:
    - bazel build //typescript/...

# ============================================
# 보안 스캔
# ============================================
security:deps:
  stage: security
  script:
    - bazel query "deps(//...)" --output=package > all_deps.txt
    - echo "Checking third_party dependencies..."
    # 의존성 취약점 스캔 (예: Trivy, Snyk 등)
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

security:sast:
  stage: security
  image: semgrep/semgrep
  script:
    - semgrep --config=auto .
  allow_failure: true
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# ============================================
# 배포 스테이지
# ============================================
.deploy_template: &deploy_template
  stage: deploy
  <<: *bazel_cache
  when: manual

deploy:staging:
  <<: *deploy_template
  environment:
    name: staging
  script:
    - bazel run //deploy:staging
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy:production:
  <<: *deploy_template
  environment:
    name: production
  script:
    - bazel run //deploy:production
  rules:
    - if: $CI_COMMIT_TAG
```

## 2. .bazelrc 설정 (CI용)

```bash
# .bazelrc

# ============================================
# 공통 설정
# ============================================
common --enable_platform_specific_config

# ============================================
# 빌드 설정
# ============================================
build --jobs=auto
build --verbose_failures
build --show_timestamps

# 재현 가능한 빌드
build --incompatible_strict_action_env
build --action_env=PATH
build --action_env=HOME

# ============================================
# 테스트 설정
# ============================================
test --test_output=errors
test --test_summary=terse
test --test_verbose_timeout_warnings

# ============================================
# CI 전용 설정
# ============================================
build:ci --disk_cache=.bazel-cache
build:ci --repository_cache=.bazel-cache/repos
build:ci --color=no
build:ci --curses=no
build:ci --show_progress_rate_limit=10
build:ci --loading_phase_threads=1

# CI에서 샌드박스 비활성화 (속도)
build:ci --spawn_strategy=local
build:ci --strategy=Genrule=local

# ============================================
# 원격 캐시 (선택)
# ============================================
# build:ci --remote_cache=grpcs://cache.example.com
# build:ci --remote_timeout=3600

# ============================================
# 릴리스 빌드
# ============================================
build:release --compilation_mode=opt
build:release --strip=always
build:release --define=release=true

# ============================================
# 언어별 설정
# ============================================
build --java_language_version=17
build --java_runtime_version=remotejdk_17

# Go
build --@io_bazel_rules_go//go/config:static=true

# TypeScript
build --@aspect_rules_ts//ts:skipLibCheck=always
```

## 3. 변경 영향 분석 스크립트

### `tools/ci/affected.sh`

```bash
#!/bin/bash
# 변경된 파일에서 영향받는 Bazel 타겟 분석

set -euo pipefail

BASE_BRANCH="${1:-main}"
CHANGED_FILES=$(git diff --name-only origin/${BASE_BRANCH}...HEAD)

if [ -z "$CHANGED_FILES" ]; then
    echo "No changes detected"
    exit 0
fi

echo "=== Changed Files ==="
echo "$CHANGED_FILES"
echo ""

# BUILD 파일이 변경된 경우 해당 패키지 전체
BUILD_CHANGES=$(echo "$CHANGED_FILES" | grep -E "BUILD(.bazel)?$" || true)
if [ -n "$BUILD_CHANGES" ]; then
    echo "=== BUILD file changes detected ==="
    for f in $BUILD_CHANGES; do
        dir=$(dirname "$f")
        echo "  //${dir}/..."
    done
fi

# 소스 파일 변경에 따른 영향 타겟
echo ""
echo "=== Affected Targets ==="
bazel query "rdeps(//..., set($CHANGED_FILES))" \
    --output=label \
    --keep_going 2>/dev/null || true

# 테스트 타겟만 추출
echo ""
echo "=== Affected Tests ==="
bazel query "kind(test, rdeps(//..., set($CHANGED_FILES)))" \
    --output=label \
    --keep_going 2>/dev/null || true
```

## 4. 필수 CI/CD 규칙

### 머지 요구사항

| 체크 | 설명 |
|------|------|
| ✅ 빌드 성공 | `bazel build` 통과 |
| ✅ 테스트 통과 | 영향받는 테스트 전부 통과 |
| ✅ OWNERS 승인 | 변경된 디렉토리의 OWNERS 최소 1명 |
| ✅ 린트 통과 | buildifier, 언어별 린터 |
| ✅ 보안 스캔 | third_party 변경 시 필수 |

### 금지 사항

- ❌ 테스트 없이 머지
- ❌ 빌드 실패 상태 머지
- ❌ OWNERS 승인 없이 머지
- ❌ `--notest` 또는 `--test_filter` 남용

## 5. 캐시 전략

### 로컬 캐시
```yaml
cache:
  key: bazel-${CI_COMMIT_REF_SLUG}
  paths:
    - .bazel-cache/
```

### 원격 캐시 (권장 - 대규모)
```yaml
variables:
  BAZEL_REMOTE_CACHE: "grpcs://cache.example.com"
  
script:
  - bazel build //... --remote_cache=${BAZEL_REMOTE_CACHE}
```

### 캐시 키 전략
| 상황 | 캐시 키 |
|------|---------|
| 브랜치별 | `bazel-${CI_COMMIT_REF_SLUG}` |
| 주간 리프레시 | `bazel-week-${CI_PIPELINE_CREATED_AT:0:10}` |
| 전역 공유 | `bazel-global` |

## 6. 배포 타겟 예시

### `deploy/BUILD.bazel`

```python
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")

# 스테이징 배포
sh_binary(
    name = "staging",
    srcs = ["deploy.sh"],
    args = ["--env=staging"],
    data = [
        "//go/api:api_binary",
        "//typescript/web:bundle",
    ],
)

# 프로덕션 배포
sh_binary(
    name = "production",
    srcs = ["deploy.sh"],
    args = ["--env=production"],
    data = [
        "//go/api:api_binary",
        "//typescript/web:bundle",
    ],
)
```

## 7. 트러블슈팅

| 문제 | 원인 | 해결 |
|------|------|------|
| 캐시 미스 | 캐시 키 변경 | 키 전략 확인 |
| OOM | 병렬 작업 과다 | `--jobs=N` 조정 |
| 타임아웃 | 대규모 빌드 | 영향 분석으로 범위 축소 |
| 테스트 flaky | 비결정적 테스트 | `--runs_per_test=3` |

## 8. 체크리스트

### CI/CD 설정 시

- [ ] `.gitlab-ci.yml` 생성
- [ ] `.bazelrc` CI 설정 추가
- [ ] 캐시 전략 결정 (로컬 vs 원격)
- [ ] 영향 분석 스크립트 설정
- [ ] 머지 규칙 설정 (GitLab MR 설정)
- [ ] OWNERS 승인 연동
- [ ] 보안 스캔 추가
- [ ] 배포 타겟 정의
