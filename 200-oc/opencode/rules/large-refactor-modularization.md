---
name: large-refactor-modularization
description: 500+ LOC 대규모 코드 모듈화 리팩토링 가이드
globs:
  - '**/*'
alwaysApply: false
---

# Large-Scale Modularization Protocol (500+ LOC)

500줄 이상의 코드를 리팩토링할 때 **반드시** 따라야 할 모듈화 지침.

## 1. 사전 분석 (MANDATORY - 코드 작성 전)

### 1.1 의존성 맵 생성

```bash
# LSP 또는 AST 도구로 의존성 분석
lsp_find_references  # 모든 심볼 참조 파악
ast_grep_search      # 패턴 기반 사용처 검색
```

**필수 파악 항목:**
| 항목 | 확인 방법 |
|------|----------|
| 진입점 (Entry Points) | public 함수/메서드, export |
| 내부 의존성 | 파일 간 import/require |
| 외부 의존성 | third_party, node_modules |
| 순환 참조 | 양방향 의존 여부 |

### 1.2 테스트 커버리지 확인

```bash
# 기존 테스트 존재 여부 확인
grep -r "test\|spec\|_test" --include="*.{ts,js,py,go,java}"
```

**테스트 없으면 → 리팩토링 전 테스트 먼저 작성**

### 1.3 변경 영향 범위 산정

| 영향도 | 기준 | 접근법 |
|--------|------|--------|
| **Low** | 단일 파일, 참조 5개 미만 | 직접 수정 |
| **Medium** | 2-5 파일, 참조 5-20개 | 청크 분할 |
| **High** | 5+ 파일, 참조 20개+ | Oracle 상담 필수 |

---

## 2. 모듈 분할 전략

### 2.1 단일 책임 원칙 (SRP) 적용

**분할 기준:**
- 하나의 모듈 = 하나의 명확한 책임
- 변경 이유가 다르면 분리
- "이 모듈은 ____를 담당한다" 한 문장으로 설명 가능해야 함

### 2.2 분할 패턴

| 패턴 | 적용 상황 | 예시 |
|------|----------|------|
| **Layer Split** | UI/비즈니스/데이터 혼재 | `UserPage.tsx` → `UserView`, `UserService`, `UserRepository` |
| **Feature Split** | 여러 기능이 한 파일에 | `utils.ts` → `string-utils`, `date-utils`, `validation-utils` |
| **Domain Split** | 도메인 경계 불명확 | `handlers.go` → `auth/`, `billing/`, `notification/` |
| **Extract Class** | 거대 클래스 | `GodClass` → 역할별 클래스들 |
| **Extract Function** | 거대 함수 | 100줄+ 함수 → 10-30줄 함수들 |

### 2.3 모듈 크기 가이드라인

| 단위 | 권장 크기 | 최대 허용 |
|------|----------|----------|
| 함수/메서드 | 10-30 LOC | 50 LOC |
| 클래스 | 100-200 LOC | 400 LOC |
| 파일/모듈 | 200-400 LOC | 600 LOC |
| 패키지 | 1000-2000 LOC | 5000 LOC |

---

## 3. 인터페이스 설계

### 3.1 경계 정의

모듈 분할 시 **반드시** 인터페이스 먼저 정의:

```typescript
// BEFORE: 구현부터 시작 ❌
class UserService {
  // 500줄 구현...
}

// AFTER: 인터페이스 먼저 ✅
interface IUserService {
  getUser(id: string): Promise<User>;
  updateUser(id: string, data: UpdateUserDto): Promise<User>;
  deleteUser(id: string): Promise<void>;
}
```

### 3.2 의존성 역전 (DIP)

```
고수준 모듈 → 인터페이스 ← 저수준 모듈

❌ UserController → UserService → UserRepository
✅ UserController → IUserService ← UserServiceImpl
                 → IUserRepository ← PostgresUserRepository
```

### 3.3 순환 의존성 해결

| 문제 | 해결책 |
|------|--------|
| A → B → A | 공통 인터페이스 추출 |
| 이벤트 기반 결합 | Event Bus 도입 |
| 콜백 지옥 | Promise/async 패턴 |

---

## 4. 실행 절차 (단계별)

### 4.1 Phase 1: 준비 (Day 1)

- [ ] 현재 코드 스냅샷 (git stash 또는 브랜치)
- [ ] 의존성 맵 문서화
- [ ] 테스트 커버리지 확인/보강
- [ ] 모듈 분할 계획 작성

### 4.2 Phase 2: 인터페이스 추출 (Day 2)

- [ ] 공개 API 인터페이스 정의
- [ ] 타입/DTO 분리
- [ ] 기존 코드에서 인터페이스 참조로 변경
- [ ] **테스트 통과 확인**

### 4.3 Phase 3: 구현 분리 (Day 3-N)

**한 번에 하나의 모듈만 분리:**

```
1. 새 파일 생성
2. 코드 이동 (복사 아님!)
3. import 경로 수정
4. 테스트 실행
5. 커밋
6. 다음 모듈로
```

### 4.4 Phase 4: 정리 (Final)

- [ ] 사용하지 않는 코드 제거
- [ ] 순환 참조 제거 확인
- [ ] 전체 테스트 통과
- [ ] 린터/타입체크 통과
- [ ] 문서 업데이트

---

## 5. 검증 체크리스트

### 5.1 기능 보존

| 검증 항목 | 방법 |
|----------|------|
| 기존 테스트 통과 | `bazel test //...` 또는 해당 테스트 명령 |
| API 호환성 | 공개 인터페이스 변경 없음 확인 |
| 런타임 동작 | E2E/통합 테스트 |

### 5.2 품질 개선

| 메트릭 | Before | After | 목표 |
|--------|--------|-------|------|
| 파일당 LOC | ? | ? | < 400 |
| 함수당 LOC | ? | ? | < 50 |
| 순환복잡도 | ? | ? | < 10 |
| 의존성 깊이 | ? | ? | < 5 |

### 5.3 필수 통과 조건

```bash
# 모든 항목 통과해야 리팩토링 완료
✅ lsp_diagnostics: 에러 0
✅ 테스트: 100% 통과
✅ 빌드: 성공
✅ 린터: 경고만 허용 (에러 0)
```

---

## 6. Anti-Patterns (절대 금지)

| 금지 사항 | 이유 |
|----------|------|
| ❌ 테스트 없이 리팩토링 | 회귀 버그 감지 불가 |
| ❌ 빅뱅 리팩토링 | 롤백 불가, 디버깅 지옥 |
| ❌ 리팩토링 + 기능 추가 동시 | 변경 원인 추적 불가 |
| ❌ 인터페이스 없이 분리 | 강결합 유지됨 |
| ❌ 커밋 없이 계속 진행 | 복구 지점 없음 |

---

## 7. 에이전트 활용

### 7.1 대규모 리팩토링 시 필수 상담

| 상황 | 에이전트 |
|------|----------|
| 아키텍처 결정 | `oracle` |
| 코드베이스 패턴 파악 | `explore` (background) |
| 외부 라이브러리 best practice | `librarian` (background) |
| UI 컴포넌트 분리 | `visual-engineering` category |

### 7.2 위임 예시

```typescript
// 복잡한 모듈 분할 계획 검토
delegate_task(
  subagent_type="oracle",
  prompt="Review my modularization plan for UserService (500 LOC → 5 modules). [계획 상세]"
)

// 기존 패턴 파악
delegate_task(
  subagent_type="explore",
  run_in_background=true,
  prompt="Find module organization patterns in this codebase. How are services structured?"
)
```

---

## 8. 커밋 전략

### 8.1 Atomic Commits

```
feat(user): extract UserRepository interface
refactor(user): move user queries to UserRepository
refactor(user): update UserService to use IUserRepository
test(user): add UserRepository unit tests
```

### 8.2 브랜치 전략

```
main
└── refactor/user-service-modularization
    ├── refactor/extract-user-repository
    ├── refactor/extract-user-validator
    └── refactor/cleanup-user-service
```

---

## Quick Reference

```
500+ LOC 리팩토링 체크리스트:

□ 1. 테스트 있는가? → 없으면 먼저 작성
□ 2. 의존성 맵 그렸는가?
□ 3. 분할 계획 세웠는가?
□ 4. 인터페이스 먼저 정의했는가?
□ 5. 한 번에 하나씩 분리하는가?
□ 6. 매 단계 테스트 돌리는가?
□ 7. 매 단계 커밋하는가?
□ 8. 순환 참조 없는가?
□ 9. 모든 검증 통과했는가?
```
