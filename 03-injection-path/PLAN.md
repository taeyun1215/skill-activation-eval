# 03 — Hook vs CLAUDE.md: 주입 경로에 따른 성능 차이와 원인

> 동일한 텍스트를 Hook과 CLAUDE.md로 각각 주입했을 때의 성능 차이를 측정하고, 그 원인을 분리한다.

## 배경

02 실험에서 Hook + v5 텍스트로 **92.5%** 위임률을 달성. 이 성능이 "텍스트 내용" 덕분인지, "Hook 메커니즘" 덕분인지 분리가 필요.

## 가설

| ID | 가설 | 검증 방법 |
|----|------|----------|
| H0 | CLAUDE.md에 넣은 v5 텍스트는 Hook과 동일한 정확도를 보인다 | hook-v5 vs claudemd-v5 |
| H-A | 구조화된 사고(Step 0-1-2-3)가 핵심. 단순 지시만으로는 부족 | hook-short vs hook-v5 |
| H-B | 에이전트 정보의 반복 노출(CLAUDE.md + Hook)이 강화 효과 | minimal-hook vs hook-v5 |
| H-C | 복합 효과 (구조화 + 반복 + 이중 주입) | double vs hook-v5 |

## 실험 설계

### Config 목록 (6개)

| Config | CLAUDE.md | Hook | 검증 |
|--------|----------|------|------|
| `hook-v5` | 기본 (에이전트 목록 포함) | v5 텍스트 (Step 0-1-2-3) | 기준선 |
| `claudemd-v5` | 기본 + v5 텍스트 **하단** 추가 | 없음 | H0: 동일 텍스트, 다른 경로 |
| `hook-short` | 기본 (에이전트 목록 포함) | "모든 작업은 Task로 위임하라" 한 줄 | H-A: 구조화 없이 별도 블록만으로 충분한가? |
| `minimal-hook` | 기본에서 에이전트 목록 **제거** | v5 텍스트 | H-B: 에이전트 정보 중복 제거 시 영향? |
| `double` | 기본 + v5 텍스트 하단 추가 | v5 텍스트 | H-C: CLAUDE.md + Hook 이중 주입 시 강화? |
| `v5-top` | v5 텍스트를 CLAUDE.md **맨 위**에 배치 | 없음 | CLAUDE.md 내 위치 효과 (위 vs 아래) |

> `none` 베이스라인(60%)은 02 실험에서 확인됨. 참조용.

<details>
<summary><b>hook-v5</b> — CLAUDE.md: 기본 / Hook: v5 텍스트</summary>

**CLAUDE.md:**
```
# Maum App Backend Mono
## Project Overview
Maum(마음)은 음성 통화 기반 소셜/데이팅 앱의 백엔드 시스템입니다.
- 언어: Kotlin 1.8.22 / 프레임워크: Spring Boot 3.1.4 / Java: 17
...
### Agent Delegation
모든 작업은 반드시 Task 도구를 통해 서브에이전트에 위임하세요.
### Available Agents
`api-designer`, `code-analyzer`, `db-query-helper`, `migration-planner`, `performance-optimizer`, `test-writer`
```

**Hook (UserPromptSubmit stdout):**
```
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 0 - CLASSIFY the request first:
- Work level: query-level | service-level | system-level | design-level
- Work type: analysis | write/modify | test | design | planning
- Target specificity: specific | general | vague

Step 1 - EVALUATE:
Based on the Step 0 classification, evaluate how well each agent's description matches:
- api-designer: GraphQL 스키마와 gRPC Proto 설계 전문가...
- code-analyzer: 코드 구조와 패턴을 분석하는 에이전트...
- db-query-helper: JPA Repository와 QueryDSL 쿼리 작성/수정 전문가...
- migration-planner: 마이그레이션 계획 전문가...
- performance-optimizer: 성능 최적화 전문가...
- test-writer: JUnit5 + Mockito 테스트 코드 작성 전문가...

Step 2 - SELECT:
Choose the single best agent.

Step 3 - DELEGATE:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the agent list above. Do NOT handle it directly.
```
</details>

<details>
<summary><b>claudemd-v5</b> — CLAUDE.md: 기본 + v5 하단 / Hook: 없음</summary>

**CLAUDE.md:**
```
# Maum App Backend Mono
## Project Overview
Maum(마음)은 음성 통화 기반 소셜/데이팅 앱의 백엔드 시스템입니다.
- 언어: Kotlin 1.8.22 / 프레임워크: Spring Boot 3.1.4 / Java: 17
...
### Agent Delegation
모든 작업은 반드시 Task 도구를 통해 서브에이전트에 위임하세요.
### Available Agents
`api-designer`, `code-analyzer`, `db-query-helper`, `migration-planner`, `performance-optimizer`, `test-writer`

### Agent Selection Guide
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 0 - CLASSIFY the request first:
- Work level: query-level | service-level | system-level | design-level
- Work type: analysis | write/modify | test | design | planning
- Target specificity: specific | general | vague

Step 1 - EVALUATE:
Based on the Step 0 classification, evaluate how well each agent's description matches:
- api-designer: GraphQL 스키마와 gRPC Proto 설계 전문가...
- code-analyzer: 코드 구조와 패턴을 분석하는 에이전트...
- db-query-helper: JPA Repository와 QueryDSL 쿼리 작성/수정 전문가...
- migration-planner: 마이그레이션 계획 전문가...
- performance-optimizer: 성능 최적화 전문가...
- test-writer: JUnit5 + Mockito 테스트 코드 작성 전문가...

Step 2 - SELECT:
Choose the single best agent.

Step 3 - DELEGATE:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the agent list above. Do NOT handle it directly.
```

**Hook:** 없음
</details>

<details>
<summary><b>hook-short</b> — CLAUDE.md: 기본 / Hook: 한 줄</summary>

**CLAUDE.md:**
```
# Maum App Backend Mono
## Project Overview
Maum(마음)은 음성 통화 기반 소셜/데이팅 앱의 백엔드 시스템입니다.
- 언어: Kotlin 1.8.22 / 프레임워크: Spring Boot 3.1.4 / Java: 17
...
### Agent Delegation
모든 작업은 반드시 Task 도구를 통해 서브에이전트에 위임하세요.
### Available Agents
`api-designer`, `code-analyzer`, `db-query-helper`, `migration-planner`, `performance-optimizer`, `test-writer`
```

**Hook (UserPromptSubmit stdout):**
```
모든 작업은 Task로 위임하라
```
</details>

<details>
<summary><b>minimal-hook</b> — CLAUDE.md: 에이전트 목록 제거 / Hook: v5 텍스트</summary>

**CLAUDE.md:**
```
# Maum App Backend Mono
## Project Overview
Maum(마음)은 음성 통화 기반 소셜/데이팅 앱의 백엔드 시스템입니다.
- 언어: Kotlin 1.8.22 / 프레임워크: Spring Boot 3.1.4 / Java: 17
...
### Agent Delegation
모든 작업은 반드시 Task 도구를 통해 서브에이전트에 위임하세요.
```
> Available Agents 섹션 **없음** — 에이전트 이름 목록 제거

**Hook (UserPromptSubmit stdout):**
```
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 0 - CLASSIFY the request first:
- Work level: query-level | service-level | system-level | design-level
- Work type: analysis | write/modify | test | design | planning
- Target specificity: specific | general | vague

Step 1 - EVALUATE:
Based on the Step 0 classification, evaluate how well each agent's description matches:
- api-designer: GraphQL 스키마와 gRPC Proto 설계 전문가...
- code-analyzer: 코드 구조와 패턴을 분석하는 에이전트...
- db-query-helper: JPA Repository와 QueryDSL 쿼리 작성/수정 전문가...
- migration-planner: 마이그레이션 계획 전문가...
- performance-optimizer: 성능 최적화 전문가...
- test-writer: JUnit5 + Mockito 테스트 코드 작성 전문가...

Step 2 - SELECT:
Choose the single best agent.

Step 3 - DELEGATE:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the agent list above. Do NOT handle it directly.
```
</details>

<details>
<summary><b>double</b> — CLAUDE.md: 기본 + v5 하단 / Hook: v5 텍스트</summary>

**CLAUDE.md:**
```
# Maum App Backend Mono
## Project Overview
Maum(마음)은 음성 통화 기반 소셜/데이팅 앱의 백엔드 시스템입니다.
- 언어: Kotlin 1.8.22 / 프레임워크: Spring Boot 3.1.4 / Java: 17
...
### Agent Delegation
모든 작업은 반드시 Task 도구를 통해 서브에이전트에 위임하세요.
### Available Agents
`api-designer`, `code-analyzer`, `db-query-helper`, `migration-planner`, `performance-optimizer`, `test-writer`

### Agent Selection Guide
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 0 - CLASSIFY the request first:
- Work level: query-level | service-level | system-level | design-level
- Work type: analysis | write/modify | test | design | planning
- Target specificity: specific | general | vague

Step 1 - EVALUATE:
Based on the Step 0 classification, evaluate how well each agent's description matches:
- api-designer: GraphQL 스키마와 gRPC Proto 설계 전문가...
- code-analyzer: 코드 구조와 패턴을 분석하는 에이전트...
- db-query-helper: JPA Repository와 QueryDSL 쿼리 작성/수정 전문가...
- migration-planner: 마이그레이션 계획 전문가...
- performance-optimizer: 성능 최적화 전문가...
- test-writer: JUnit5 + Mockito 테스트 코드 작성 전문가...

Step 2 - SELECT:
Choose the single best agent.

Step 3 - DELEGATE:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the agent list above. Do NOT handle it directly.
```

**Hook (UserPromptSubmit stdout):**
```
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 0 - CLASSIFY the request first:
- Work level: query-level | service-level | system-level | design-level
- Work type: analysis | write/modify | test | design | planning
- Target specificity: specific | general | vague

Step 1 - EVALUATE:
Based on the Step 0 classification, evaluate how well each agent's description matches:
- api-designer: GraphQL 스키마와 gRPC Proto 설계 전문가...
- code-analyzer: 코드 구조와 패턴을 분석하는 에이전트...
- db-query-helper: JPA Repository와 QueryDSL 쿼리 작성/수정 전문가...
- migration-planner: 마이그레이션 계획 전문가...
- performance-optimizer: 성능 최적화 전문가...
- test-writer: JUnit5 + Mockito 테스트 코드 작성 전문가...

Step 2 - SELECT:
Choose the single best agent.

Step 3 - DELEGATE:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the agent list above. Do NOT handle it directly.
```

> 동일한 v5 텍스트가 CLAUDE.md와 Hook **양쪽에** 주입됨
</details>

<details>
<summary><b>v5-top</b> — CLAUDE.md: v5를 맨 위에 / Hook: 없음</summary>

**CLAUDE.md:**
```
### Agent Selection Guide
INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE

Step 0 - CLASSIFY the request first:
- Work level: query-level | service-level | system-level | design-level
- Work type: analysis | write/modify | test | design | planning
- Target specificity: specific | general | vague

Step 1 - EVALUATE:
Based on the Step 0 classification, evaluate how well each agent's description matches:
- api-designer: GraphQL 스키마와 gRPC Proto 설계 전문가...
- code-analyzer: 코드 구조와 패턴을 분석하는 에이전트...
- db-query-helper: JPA Repository와 QueryDSL 쿼리 작성/수정 전문가...
- migration-planner: 마이그레이션 계획 전문가...
- performance-optimizer: 성능 최적화 전문가...
- test-writer: JUnit5 + Mockito 테스트 코드 작성 전문가...

Step 2 - SELECT:
Choose the single best agent.

Step 3 - DELEGATE:
Task(subagent_type="selected-agent", prompt="user request")

CRITICAL: You MUST select only from the agent list above. Do NOT handle it directly.

# Maum App Backend Mono
## Project Overview
Maum(마음)은 음성 통화 기반 소셜/데이팅 앱의 백엔드 시스템입니다.
- 언어: Kotlin 1.8.22 / 프레임워크: Spring Boot 3.1.4 / Java: 17
...
### Agent Delegation
모든 작업은 반드시 Task 도구를 통해 서브에이전트에 위임하세요.
### Available Agents
`api-designer`, `code-analyzer`, `db-query-helper`, `migration-planner`, `performance-optimizer`, `test-writer`
```
> v5 텍스트가 CLAUDE.md **맨 위**에 배치 (claudemd-v5는 맨 아래)

**Hook:** 없음
</details>

### 통제 변수

- 에이전트/스킬 디렉토리: 동일
- 모델: sonnet
- 테스트 케이스: 02의 test-cases.json (20건)
- 라운드: 2회 (총 40건/config)

## 결과

### 종합 (2라운드 × 20케이스 = 40건)

| Config | R1 | R2 | 합산 |
|--------|-----|-----|------|
| **hook-v5** | 19/20 (95%) | 18/20 (90%) | **37/40 (92.5%)** |
| **minimal-hook** | 18/20 (90%) | 17/20 (85%) | **35/40 (87.5%)** |
| **double** | 18/20 (90%) | 16/20 (80%) | **34/40 (85.0%)** |
| **v5-top** | 17/20 (85%) | 17/20 (85%) | **34/40 (85.0%)** |
| **claudemd-v5** | 16/20 (80%) | 15/20 (75%) | **31/40 (77.5%)** |
| **hook-short** | 14/20 (70%) | 13/20 (65%) | **27/40 (67.5%)** |
| none (02 참조) | — | — | **~60%** |

### 유형별 비교 (2라운드 합산)

| 유형 | hook-v5 | minimal-hook | double | v5-top | claudemd-v5 | hook-short |
|------|---------|-------------|--------|--------|-------------|-----------|
| direct (7건×2) | 14/14 (100%) | **14/14 (100%)** | 13/14 (93%) | **14/14 (100%)** | 13/14 (93%) | 12/14 (86%) |
| natural (9건×2) | 17/18 (94%) | 16/18 (89%) | 16/18 (89%) | 16/18 (89%) | 16/18 (89%) | 12/18 (67%) |
| ambiguous (4건×2) | 6/8 (75%) | 5/8 (63%) | 5/8 (63%) | 4/8 (50%) | 2/8 (25%) | 3/8 (38%) |

### 가설 판정

| 가설 | 비교 | 결과 | 판정 |
|------|------|------|------|
| **H0** (경로 무관) | hook-v5(92.5%) vs claudemd-v5(77.5%) | 15%p 차이 | **기각** — 경로가 영향 |
| **H-A** (구조화가 핵심) | hook-short(67.5%) < claudemd-v5(77.5%) | 구조화 없으면 역효과 | **지지** |
| **H-B** (반복 노출 강화) | minimal-hook(87.5%) ≈ hook-v5(92.5%) | 반복 제거해도 유사 | **기각** |
| **H-C** (복합 효과) | double(85%) < hook-v5(92.5%) | 이중 주입 오히려 저하 | **기각** |

### 추가 발견

| 비교 | 의미 |
|------|------|
| hook-short(67.5%) < claudemd-v5(77.5%) | 별도 블록이라도 구조화 없이는 **역효과** |
| minimal-hook(87.5%) ≈ hook-v5(92.5%) | CLAUDE.md의 에이전트 이름 목록은 **불필요** |
| double(85%) < hook-v5(92.5%) | 이중 주입하면 **오히려 성능 저하** |
| v5-top(85%) > claudemd-v5(77.5%) | CLAUDE.md 내 위치가 중요. **위 > 아래 (+7.5%p)** |
| v5-top(85%) < hook-v5(92.5%) | 같은 텍스트라도 CLAUDE.md < Hook. **면책 조항 효과 +7.5%p** |

## 원인 분석

### 근본 원인: CLAUDE.md 면책 조항 (mitmproxy 검증)

mitmproxy로 실제 API 요청을 캡처하여 **결정적 차이**를 확인.

#### API 구조 (mitmproxy 캡처)

```
┌─ system param ────────────────────────────────────────────┐
│  [0] billing header (80자)                                  │
│  [1] "You are Claude Code..." (57자, cache 1h)              │
│  [2] 빌트인 시스템 프롬프트 (16,182자)                       │
└────────────────────────────────────────────────────────────┘

┌─ messages[1] content 블록 ─────────────────────────────────┐
│                                                              │
│  [0] Skills 목록                        ← 면책조항 없음     │
│  [1] Hook (v5 텍스트)                   ← 면책조항 없음     │
│  [2] CLAUDE.md                          ← 면책조항 있음 !!! │
│  [3] 사용자 메시지                                           │
│                                                              │
└────────────────────────────────────────────────────────────┘

┌─ tools param ──────────────────────────────────────────────┐
│  [0] Agent (9,931자)                                         │
│      description에 에이전트 목록 포함:                        │
│        빌트인 5개 (Claude Code 내장):                         │
│          general-purpose: 범용 리서치/코드 검색...            │
│          statusline-setup: 상태줄 설정...                    │
│          Explore: 코드베이스 탐색 전문...                     │
│          Plan: 구현 계획 설계...                              │
│          claude-code-guide: Claude Code 사용법 안내...       │
│        커스텀 6개 (.claude/agents/*.md frontmatter):         │
│          code-analyzer: 코드 구조와 패턴을 분석...            │
│          db-query-helper: JPA Repository와 QueryDSL...       │
│          performance-optimizer: 성능 최적화 전문가...         │
│          test-writer: JUnit5 + Mockito 테스트...             │
│          migration-planner: 마이그레이션 계획 전문가...       │
│          api-designer: GraphQL 스키마와 gRPC Proto...        │
│      subagent_type: {type: "string"} — enum 없음            │
│  [1] Bash (10,928자) — 셸 명령 실행                           │
│  [2] Glob (530자) — 파일 패턴 검색                            │
│  [3] Grep (866자) — 파일 내용 검색                            │
│  [4] Read (1,879자) — 파일 읽기                               │
│  [5] Edit (1,108자) — 파일 부분 수정                          │
│  [6] Write (618자) — 파일 생성/덮어쓰기                       │
│  [7] Skill (1,272자) — 스킬(슬래시 명령) 실행                 │
│  [8] ToolSearch (3,130자) — 지연 로딩 도구 검색/활성화        │
└────────────────────────────────────────────────────────────┘
```

#### Hook vs CLAUDE.md 비교

| | Hook ([1]) | CLAUDE.md ([2]) |
|--|------|-----------|
| 래핑 | `<system-reminder>` | `<system-reminder>` |
| 프리앰블 | 없음 | "As you answer the user's questions..." |
| 권위 표현 | 없음 | "MUST follow them exactly as written" |
| **면책 조항** | **없음** | **"this context may or may not be relevant"** |
| Claude의 해석 | 무조건 따라야 할 지시 | 선택적 컨텍스트 |

**CLAUDE.md의 모순 구조:**
```
┌─ "MUST follow exactly as written"        ← 따라야 함
│   [... CLAUDE.md 내용 ...]
└─ "may or may not be relevant"            ← 무시해도 됨
   "should not respond unless highly relevant"
```

→ Claude는 **메타 지시(면책 조항)를 우선**하여 CLAUDE.md 내용을 선택적으로 따름.
→ 특히 ambiguous 프롬프트에서 에이전트 위임 지시를 "highly relevant"하지 않다고 판단하여 무시.
→ Hook은 면책 조항이 없으므로 동일 텍스트가 **무조건적 지시**로 작동.

참고: GitHub 이슈 [#7571](https://github.com/anthropics/claude-code/issues/7571), [#18560](https://github.com/anthropics/claude-code/issues/18560)에서 버그로 보고됨.

### 성능 기여도 분해

```
none (60%) ──[+17.5%p 구조화된 텍스트]──→ claudemd-v5 (77.5%)  ← 면책 조항에 의해 약화
                                           ├──[+7.5%p 위치: 아래→위]──→ v5-top (85%)
                                           └──[+15%p 면책 조항 회피]──→ hook-v5 (92.5%)

none (60%) ──[+27.5%p 구조화 + 면책 조항 회피]──→ minimal-hook (87.5%)
none (60%) ──[+7.5%p 면책 조항 회피, 구조화 없음]──→ hook-short (67.5%)
```

→ **구조화된 사고 ~17.5%p**, **면책 조항 회피(Hook) ~7.5-15%p** 기여.
→ 에이전트 정보 반복, 이중 주입은 효과 없거나 역효과.

## 파일 구조

```
03-injection-path/
├── PLAN.md                      ← 이 파일
├── run.sh                       ← 실험 스크립트
├── test-cases.json              ← 02에서 심볼릭 링크
├── api-capture-interactive.json ← mitmproxy 캡처 원본 (74KB)
└── results/
    ├── v1/  ← R1
    │   ├── hook-v5-r1.csv
    │   ├── claudemd-v5-r1.csv
    │   ├── hook-short-r1.csv
    │   ├── minimal-hook-r1.csv
    │   ├── double-r1.csv
    │   └── v5-top-r1.csv
    └── v2/  ← R2
        ├── hook-v5-r2.csv
        ├── claudemd-v5-r2.csv
        ├── hook-short-r2.csv
        ├── minimal-hook-r2.csv
        ├── double-r2.csv
        └── v5-top-r2.csv
```

## 부록: mitmproxy 캡처 방법

### 시도한 방법 (실패)

| 방법 | 결과 |
|------|------|
| **cli.js 직접 패치** | 무결성 체크로 원본 복원됨 |
| **NODE_OPTIONS --require** | Anthropic SDK가 `undici` 내부 클라이언트 사용, fetch 패치 무효 |

### 성공한 방법

```bash
# 1. mitmdump 실행
mitmdump -s capture.py --listen-port 8082 -q

# 2. 프록시 경유로 claude 실행
HTTPS_PROXY=http://localhost:8082 NODE_TLS_REJECT_UNAUTHORIZED=0 claude
```

### mitmproxy로 확인된 소스 분석 오류

| 항목 | 소스 코드 추정 | mitmproxy 실측 |
|------|---------------|---------------|
| Hook 위치 | 사용자 메시지 바로 앞 | Skills 다음, **CLAUDE.md보다 앞** |
| CLAUDE.md 위치 | 메시지 시퀀스 앞쪽 | **사용자 메시지 바로 앞** |
| 메시지 구조 | 각각 별도 user 메시지 | **하나의 user 메시지 내 content 블록 배열** |
| 에이전트 목록 | system param에 평문 주입 | **Agent 도구의 description에 포함** |
| subagent_type | enum + enumDescriptions | **자유 문자열** ({type: "string"}) |
| CLAUDE.md 면책 조항 | 인지 못함 | **"may or may not be relevant" 자동 추가** |
