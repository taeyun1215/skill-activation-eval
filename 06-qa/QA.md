# 06 — Q&A

> Claude Code 내부 구조와 실험 관련 질문/답변 모음

---

### Q1. Claude Code 내부 로딩 전체 순서는?

#### Phase 1: 세션 초기화 (프로세스 시작 시 1회)

| # | 동작 | 코드 위치 | 실제 코드 | 범위 | 입력 | 출력 |
|---|------|----------|----------|------|------|------|
| 1-1 | 에이전트 디렉토리 조회 | `cli.js:1509 rp6()` 내부 | `readdir(".claude/agents/")` | **전체** (project·user·policy 3곳) | 디렉토리 경로 3개 | `["api-designer.md", "code-analyzer.md", "db-query-helper.md", "migration-planner.md", "performance-optimizer.md", "test-writer.md"]` |
| 1-2 | 에이전트 파일 읽기 | `cli.js:1509 rp6()` 내부 | `readFile(각 .md)` | **전체** (1-1의 모든 파일) | `".claude/agents/db-query-helper.md"` | `"---\ndescription: \"JPA Repository와 QueryDSL 쿼리 작성/수정 전문가...\"\n---\n\n# db-query-helper\n..."` |
| 1-3 | frontmatter 파싱 | `cli.js:307 _J()` | `let K = /^---\s*\n([\s\S]*?)---\s*\n?/; ... return {frontmatter: _, content: w}` | **전체** (1-2의 모든 텍스트) | 파일 전체 텍스트 | `{ frontmatter: { description: "JPA Repository와 QueryDSL 쿼리 작성/수정 전문가..." }, content: "# db-query-helper\n\n## 역할\n..." }` |
| 1-4 | 에이전트 객체 저장 | `cli.js:1509 d94()` | `description → whenToUse` 매핑 | **전체** (1-3의 모든 결과) | 파싱 결과 | `{ agentType: "db-query-helper", whenToUse: "JPA Repository와 QueryDSL 쿼리 작성/수정 전문가...", source: "projectSettings", getSystemPrompt: () => "# db-query-helper\n..." }` |
| 1-5 | 스킬 디렉토리 조회 | `cli.js:1509 rp6()` | `readdir(".claude/skills/")` | **전체** (project·user·policy) | 디렉토리 경로 | `["develop", "entity-skill", "graphql-skill", "grpc-skill", "gradle-skill", "test-skill", "plan-skill", "adr-skill"]` |
| 1-6 | 스킬 파일 존재 확인 | `cli.js:1509 rp6()` 내부 | `readFile(각 SKILL.md)` — try/catch로 존재 확인 | **전체** (1-5의 모든 서브디렉토리) | `".claude/skills/entity-skill/SKILL.md"` | 성공 또는 `ENOENT` |
| 1-7 | 스킬 파일 읽기 | `cli.js:1509 rp6()` 내부 | `readFile(SKILL.md)` | **전체** (1-6에서 존재하는 것만) | 파일 경로 | `"---\ndescription: \"JPA Entity + Repository 작성 가이드\"\nwhen_to_use: \"Entity 생성 시\"\n---\n\n# Entity Skill\n..."` |
| 1-8 | 스킬 frontmatter 파싱 | `cli.js:307 _J()` | 동일 정규식 파서 | **전체** (1-7의 모든 텍스트) | 파일 전체 텍스트 | `{ frontmatter: { description: "JPA Entity + Repository 작성 가이드", when_to_use: "Entity 생성 시" }, content: "# Entity Skill\n..." }` |
| 1-9 | 스킬 객체 저장 | `cli.js:1509 d94()` | command 객체 등록 | **전체** (1-8의 모든 결과) | 파싱 결과 | `{ name: "entity-skill", type: "prompt", description: "JPA Entity + Repository 작성 가이드", whenToUse: "Entity 생성 시", source: "projectSettings" }` |
| 1-10 | CLAUDE.md 읽기 | (별도 로더) | `readFile(".claude/CLAUDE.md")` + `readFile("~/.claude/CLAUDE.md")` | **전체** (프로젝트 + 홈 2곳) | 파일 경로 2개 | `"# Maum App Backend Mono\n\n## Project Overview\n..."` (텍스트 전문) |
| 1-11 | rules 읽기 | (별도 로더) | `readdir(".claude/rules/")` → 각 `readFile()` | **전체** (rules 내 모든 .md) | rules 디렉토리 | `{ "dev.md": "# Development Environment\n...", "domain-context.md": "# Maum Domain Context\n...", "techspec.md": "# Tech Specification\n..." }` |
| 1-12 | MCP 서버 연결 | (MCP 로더) | settings.json → 프로세스 시작 | **전체** (설정된 모든 서버) | `{ "mcpServers": { "server1": {...} } }` | `[{ name: "server1", type: "connected", tools: [...] }]` |

#### Phase 2: 매 턴 컨텍스트 조립 (사용자 메시지마다 반복)

| # | 동작 | 코드 위치 | 실제 코드 | 범위 | 입력 | 출력 (시스템 프롬프트에 주입되는 텍스트) |
|---|------|----------|----------|------|------|------|
| 2-1 | 시스템 프롬프트 기본 생성 | `cli.js:2113` 부근 | 빌트인 텍스트 조립 | — | 고정 텍스트 + 설정값 | `"You are Claude Code, Anthropic's official CLI..."` (수천 줄) |
| 2-2 | **에이전트 목록 주입** | Agent 도구 description | ``z.map((J) => `- ${J.agentType}: ${J.whenToUse} (Tools: ${j2Y(J)})`).join('\n')`` | **전체** (1-4의 모든 에이전트) | 에이전트 객체 배열 | Agent 도구의 `description` 필드에 포함: `"Available agent types and the tools they have access to:\n- code-analyzer: 코드 구조와 패턴을 분석하는 에이전트... (Tools: Read, Grep, Glob)\n..."` (9,931자) |
| 2-3 | CLAUDE.md 주입 | attachment 변환 | system-reminder 래핑 + **면책 조항 자동 추가** | **전체** | 1-10의 텍스트 | `"<system-reminder>\nAs you answer the user's questions, you can use the following context:\n# claudeMd\nCodebase and user instructions are shown below. Be sure to adhere to these instructions. IMPORTANT: These instructions OVERRIDE any default behavior...\n\n      IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context unless it is highly relevant to your task.\n</system-reminder>"` |
| 2-4 | rules 주입 | attachment 변환 | system-reminder 래핑 | **전체** | 1-11의 텍스트들 | `"<system-reminder>\nContents of .claude/rules/dev.md:\n# Development Environment\n..."` (각 파일별) |
| 2-5 | **스킬 목록 주입** | `cli.js:1590` `Ev8()` + `ls9()`, `cli.js:6531` | ``Ev8(A) = A.whenToUse ? `${A.description} - ${A.whenToUse}` : A.description`` → ``ls9(A) = `- ${A.name}: ${Ev8(A)}` `` | **전체** (토큰 예산 내) | 1-9의 모든 스킬 객체 | `"<system-reminder>\nThe following skills are available for use with the Skill tool:\n\n- entity-skill: JPA Entity + Repository 작성 가이드 - Entity 생성 시\n- graphql-skill: GraphQL 스키마 및 리졸버 작성 가이드\n..."` |
| 2-6 | Hook 실행 (있으면) | hook runner | UserPromptSubmit → stdout 캡처 | — | `{"prompt":"쿼리가 느려요","cwd":"/path"}` (stdin) | `"INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE\nStep 0 - CLASSIFY...\nStep 1 - EVALUATE...\n- api-designer: GraphQL...\n- db-query-helper: JPA...\n..."` (stdout) |
| 2-7 | **도구 스키마 생성** | Agent 도구 생성 | `subagent_type: {type: "string"}` — enum 없음 | — | 에이전트 객체 배열 | Agent 도구 스키마: `subagent_type`은 자유 문자열. 에이전트 목록은 description에만 포함 (2-2 참조). `tools[0]`에 Agent(9,931자), 나머지 Bash·Glob·Grep·Read·Edit·Write·Skill·ToolSearch |
| 2-8 | 기타 attachment | 각종 핸들러 | 날짜·파일변경·태스크 등 | 해당분만 | 각종 상태값 | `"<system-reminder>\nThe date has changed..."` 등 |

**Phase 2 조립 후 Claude가 보는 최종 형태:**

```
┌─ API system param (3개 블록) ──────────────────────────────────┐
│                                                                 │
│  [0] {type:"text",                                              │
│       text:"x-anthropic-billing-header: cc_version=2.1.71..."}  │
│       (80자, billing header)                                    │
│                                                                 │
│  [1] {type:"text",                                              │
│       text:"You are Claude Code, Anthropic's official CLI...",  │
│       cache_control: {type:"ephemeral", ttl:"1h"}}              │
│       (57자, 정체성)                                             │
│                                                                 │
│  [2] {type:"text",                                              │
│       text:"You are an interactive agent that helps users...    │
│       ... (빌트인 텍스트 16,182자) ...                          │
│       ... git status, 환경 정보 포함                            │
│       에이전트 목록은 여기에 없음 ← (소스 분석과 다름!)         │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─ API messages[0] (deferred tools) ─────────────────────────────┐
│  {role:"user", content:"<available-deferred-tools>              │
│  AskUserQuestion\nTaskCreate\nWebFetch\n...                     │
│  </available-deferred-tools>"} (2,038자)                        │
└─────────────────────────────────────────────────────────────────┘

┌─ API messages[1] (content 블록, user role) ────────────────────┐
│                                                                 │
│  [0] Skills 목록                               ← 면책조항 없음 │
│  "<system-reminder>                                             │
│  The following skills are available for use with the Skill tool:│
│  - entity-skill: JPA Entity + Repository 작성 가이드            │
│  - graphql-skill: GraphQL 스키마 및 리졸버 작성 가이드          │
│  ...</system-reminder>"                                         │
│                                                                 │
│  [1] UserPromptSubmit hook (v5 텍스트)         ← 면책조항 없음 │
│  "<system-reminder>                                             │
│  UserPromptSubmit hook success: INSTRUCTION: MANDATORY SKILL    │
│  ACTIVATION SEQUENCE                                            │
│  Step 1 - EVALUATE ... Step 2 - ACTIVATE ... Step 3 - IMPLEMENT│
│  INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE                │
│  Step 0 - CLASSIFY ... Step 1 - EVALUATE ... Step 2 - SELECT   │
│  Step 3 - DELEGATE: Task(subagent_type=..., prompt=...)         │
│  </system-reminder>"                                            │
│                                                                 │
│  [2] CLAUDE.md                                 ← 면책조항 있음!│
│  "<system-reminder>                                             │
│  As you answer the user's questions, you can use the following  │
│  context:                                                       │
│  # claudeMd                                                     │
│  Codebase and user instructions are shown below. Be sure to    │
│  adhere to these instructions. IMPORTANT: These instructions    │
│  OVERRIDE any default behavior and you MUST follow them exactly │
│  as written.                                                    │
│  Contents of .../CLAUDE.md (project instructions):              │
│  (CLAUDE.md 원본 내용)                                          │
│                                                                 │
│      IMPORTANT: this context may or may not be relevant to      │
│      your tasks. You should not respond to this context unless  │
│      it is highly relevant to your task.  ← !!! 면책 조항 !!!  │
│  </system-reminder>"                                            │
│                                                                 │
│  [3] "hello" — 실제 사용자 메시지                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─ API tools param (9개 도구) ───────────────────────────────────┐
│                                                                 │
│  [0] Agent (desc 9,931자) ← 에이전트 목록이 여기에 포함! [2-2] │
│      description에 에이전트 목록 포함:                          │
│        빌트인 5개 (Claude Code 내장):                           │
│          general-purpose: 범용 리서치/코드 검색...              │
│          statusline-setup: 상태줄 설정...                      │
│          Explore: 코드베이스 탐색 전문...                       │
│          Plan: 구현 계획 설계...                                │
│          claude-code-guide: Claude Code 사용법 안내...          │
│        커스텀 6개 (.claude/agents/*.md frontmatter):            │
│          code-analyzer: 코드 구조와 패턴을 분석...              │
│          db-query-helper: JPA Repository와 QueryDSL...          │
│          performance-optimizer: 성능 최적화 전문가...           │
│          test-writer: JUnit5 + Mockito 테스트...               │
│          migration-planner: 마이그레이션 계획 전문가...         │
│          api-designer: GraphQL 스키마와 gRPC Proto...           │
│      subagent_type: {type: "string"} ← enum 없음!              │
│                                                                 │
│  [1] Bash (10,928자) — 셸 명령 실행                             │
│  [2] Glob (530자) — 파일 패턴 검색                              │
│  [3] Grep (866자) — 파일 내용 검색                              │
│  [4] Read (1,879자) — 파일 읽기                                 │
│  [5] Edit (1,108자) — 파일 부분 수정                            │
│  [6] Write (618자) — 파일 생성/덮어쓰기                         │
│  [7] Skill (1,272자) — 스킬(슬래시 명령) 실행                   │
│  [8] ToolSearch (3,130자) — 지연 로딩 도구 검색/활성화          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

> **mitmproxy 검증 결과** (v2.1.71, 대화형 + `-p` 모드 모두 동일):
> - 에이전트 목록은 **Agent 도구의 description 필드(tools param)**에 포함
> - CLAUDE.md와 Hook은 동일한 API 위치(messages[1]의 content 블록)에 동일한 `<system-reminder>` 형태로 주입되지만, **CLAUDE.md만 면책 조항이 추가**됨

#### Phase 3: 메인 에이전트 응답 (Phase 2 컨텍스트로 Claude 실행)

| # | 동작 | 코드 위치 | 실제 코드 | 범위 | 입력 | 출력 |
|---|------|----------|----------|------|------|------|
| 3-1 | API 호출 | `cli.js` 메인 루프 `gS()` | `await client.beta.messages.create({ system, messages, tools })` | — | `system`: 빌트인 텍스트 (2-1), `messages`: deferred tools + [SessionStart hooks, 스킬 목록(2-5), Hook(2-6), CLAUDE.md(2-3, 면책조항 포함) + 사용자 메시지], `tools`: Agent(에이전트 목록 포함, 2-2) + Bash·Glob·Grep·Read·Edit·Write·Skill·ToolSearch (2-7) | Claude 응답: `{ content: [...], stop_reason: "tool_use" }` |
| 3-2 | 도구 실행 | `cli.js executeTool()` → `Si6()` → `qqz()` | `tool.call(input)` — `qqz()`에서 도구 이름으로 핸들러 디스패치 | — | `{ type: "tool_use", name: "Read", input: { file_path: "/path/to/file" } }` | 도구 실행 결과: `{ type: "tool_result", content: "파일 내용..." }` |
| 3-3 | 반복 판정 | `cli.js` 메인 루프 | `if (response.stop_reason === "tool_use") { messages.push(response, toolResults); goto 3-1 }` | — | 3-1 응답의 `stop_reason` | `"tool_use"` → 도구 결과를 메시지에 추가 후 3-1로 재귀 / `"end_turn"` → 3-4로 |
| 3-4 | 종료 | `cli.js` 메인 루프 | `if (response.stop_reason === "end_turn") break` | — | `stop_reason === "end_turn"` | 최종 응답 텍스트를 사용자에게 출력 |

> Phase 3는 **도구 호출 루프**. Claude가 도구를 호출하면 실행 후 다시 API를 호출하는 사이클이 `end_turn`까지 반복된다. Skill(), Read(), Edit(), Task() 등 모든 도구 호출이 이 루프 안에서 일어난다. Task() 호출 시 Phase 4가 시작된다.

**Phase 3 도구 호출 루프 예시 (Hook 있을 때, "User 엔티티에 새 필드 추가해줘"):**

```
┌─ 3-1: API 호출 (1회차) ───────────────────────────────────────┐
│  system: [빌트인 텍스트] (2-1)                                  │
│  messages: [                                                     │
│    {role:"user", content:"<available-deferred-tools>..."},       │
│    {role:"user", content:[                                       │
│      {text:"<system-reminder>                         ← [2-5]   │
│        skills 목록                                               │
│      </system-reminder>"},                                       │
│      {text:"<system-reminder>                    ← [2-6] Hook   │
│        UserPromptSubmit hook success:                            │
│        INSTRUCTION: MANDATORY SKILL ACTIVATION SEQUENCE          │
│        Step 1 - EVALUATE ... Step 2 - ACTIVATE ...              │
│        INSTRUCTION: MANDATORY AGENT SELECTION SEQUENCE           │
│        Step 0 - CLASSIFY ... Step 1 - EVALUATE ...              │
│        Step 2 - SELECT ... Step 3 - DELEGATE: Task(...)         │
│      </system-reminder>"},                                       │
│      {text:"<system-reminder>              ← [2-3] + [2-8]     │
│        CLAUDE.md 내용 + currentDate                              │
│      </system-reminder>"},                                       │
│      {text:"User 엔티티에 새 필드 추가해줘"}    ← 사용자 메시지 │
│    ]}                                                            │
│  ]                                                               │
│  tools: Agent(에이전트 목록 포함) + 기타 도구 (2-7)             │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ Claude 응답 (1회차) ─────────────────────────────────────────┐
│  (Hook 지시에 따라 스킬 평가)                                   │
│  "entity-skill: YES - Entity 추가 작업"                         │
│  "test-skill: NO - 아직 테스트 단계 아님"                       │
│                                                                 │
│  → 도구 호출: Skill("entity-skill")                             │
│  stop_reason: "tool_use"                                        │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ 3-2: 도구 실행 ──────────────────────────────────────────────┐
│  Skill("entity-skill") 실행                                     │
│  → SKILL.md 내용이 메인 컨텍스트에 로드됨                       │
│  결과: "# Entity Skill\n## JPA Entity 작성 가이드\n..."         │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ 3-3: 반복 (stop_reason === "tool_use") ──────────────────────┐
│  messages에 Claude 응답 + 도구 결과 추가 → 3-1로               │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ 3-1: API 호출 (2회차) ───────────────────────────────────────┐
│  messages: [                                                     │
│    ... 1회차와 동일한 메시지들 (Hook, CLAUDE.md, 사용자) ...     │
│    {role:"assistant", tool_use: Skill("entity-skill")},         │
│    {role:"user", tool_result: "# Entity Skill\n## 가이드..."}   │
│  ]                          ← 매 턴마다 전체 대화 히스토리 전송  │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ Claude 응답 (2회차) ─────────────────────────────────────────┐
│  (Hook 지시에 따라 에이전트 선택)                                │
│  "Step 0: query-level, write/modify, general"                   │
│  "Step 1: db-query-helper: 4/5, test-writer: 2/5, ..."         │
│  "Step 2: db-query-helper 선택"                                 │
│                                                                 │
│  → 도구 호출: Task("db-query-helper",                           │
│      prompt="User 엔티티에 새 필드 추가해줘")                   │
│  stop_reason: "tool_use"                                        │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ 3-2: 도구 실행 ──────────────────────────────────────────────┐
│  Task("db-query-helper") 실행 → Phase 4 시작                   │
│  (서브에이전트 생성 → 작업 수행 → 결과 반환)                    │
│  결과: "User 엔티티에 phoneNumber 필드를 추가했습니다..."       │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ 3-3: 반복 (stop_reason === "tool_use") ──────────────────────┐
│  messages에 Claude 응답 + Task 결과 추가 → 3-1로               │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ 3-1: API 호출 (3회차) ───────────────────────────────────────┐
│  messages: [                                                     │
│    ... 1회차 메시지들 ...                                        │
│    {role:"assistant", tool_use: Skill("entity-skill")},         │
│    {role:"user", tool_result: "# Entity Skill\n..."},           │
│    {role:"assistant", tool_use: Task("db-query-helper",...)},   │
│    {role:"user", tool_result: "phoneNumber 필드 추가 완료..."}  │
│  ]                                     ← 대화 전체가 계속 누적  │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ Claude 응답 (3회차) ─────────────────────────────────────────┐
│  "User 엔티티에 phoneNumber 필드를 추가 완료했습니다."          │
│  stop_reason: "end_turn"                                        │
└────────────────────────────────────────────────────────────────┘
        ↓
┌─ 3-4: 종료 ──────────────────────────────────────────────────┐
│  최종 응답을 사용자에게 출력                                     │
└────────────────────────────────────────────────────────────────┘
```

> 이 예시에서 API는 총 3번 호출된다. ①Skill 호출 ②Task 위임 ③최종 응답. Hook이 없으면 ①을 건너뛰고 ②에서도 Task() 대신 직접 처리할 수 있다.
>
> **메시지 누적**: Claude API는 무상태(stateless)이므로, 매 API 호출마다 **전체 대화 히스토리**를 다시 전송한다. 1회차에 5개 메시지였다면, 2회차에는 5 + Claude응답 + 도구결과 = 7개, 3회차에는 9개로 계속 늘어난다. Hook 텍스트는 1회차 메시지에 포함되어 있으므로 **모든 API 호출에서 모델이 볼 수 있다.** 대화가 길어져 컨텍스트 한계에 도달하면 `/compact`로 이전 메시지를 요약한다.

#### Phase 4: 서브에이전트 실행 (Phase 3에서 Task 도구 호출 시)

| # | 동작 | 코드 위치 | 실제 코드 | 범위 | 입력 | 출력 |
|---|------|----------|----------|------|------|------|
| 4-1 | 에이전트 정의 조회 | `Task.call()` 내부 | `v = activeAgents.find(a => a.agentType === q)` | **특정 1개** | Task input: `{ subagent_type: "db-query-helper", prompt: "N+1 쿼리 수정해줘" }` | 해당 에이전트 객체 `v` |
| 4-2 | 서브에이전트 시스템 프롬프트 | `Task.call()` 내부 | `W6 = v.getSystemPrompt({toolUseContext: j})` → `Ti6([W6], h, E6)` | **특정 1개** | 에이전트 객체의 `getSystemPrompt()` (frontmatter 제외 본문) | `x = "# db-query-helper\n\n## 역할\nJPA Repository와 QueryDSL..."` |
| 4-3 | 서브에이전트 메시지 조립 | `Task.call()` 내부 | `g = [t1({content: A})]` + `customSystemPrompt: jK(x)` | **전체 + 특정** | `A` = Task prompt, `x` = 4-2 시스템 프롬프트 | 시스템 프롬프트: `jK(x)`, 첫 메시지: `t1({content: "N+1 쿼리 수정해줘"})` |
| 4-4 | 서브에이전트 실행 | 독립 대화 루프 | 서브에이전트가 Phase 2와 동일한 attachment 조립을 거침 (skill_listing 포함, Hook 미포함) | — | 4-3 전체 | 서브에이전트 응답 |

**서브에이전트의 매 턴에서도 Phase 2 attachment가 조립됨:**
- `skill_listing` → `H=!q.agentId` 조건 **바깥** → **포함** ✅
- Skill 도구 → `wT6` 제외 목록에 없음 → **사용 가능** ✅
- Task 도구 → `wT6` 제외 목록에 있음 (`Iq`) → **사용 불가** ❌ (재위임 차단)
- Hook → 서브에이전트에 **전파 안됨** ❌
- 에이전트 목록 (Agent 도구 description) → 서브에이전트에 **Agent 도구 자체가 제외**되므로 포함 안됨

---

### Q2. 서브에이전트 호출의 기본 동작은?

서브에이전트 호출은 항상 Phase 3(메인 에이전트 응답)에서 일어난다.

```
Phase 2-2: 에이전트 목록이 Agent 도구의 description에 포함 (tools param)
Phase 2-6: (Hook 있으면) "Step 0→1→2→3으로 평가하고 Task()로 위임하라" 텍스트 주입 (messages param)
    ↓
Phase 3-1: Claude가 위 정보를 모두 읽음
Phase 3-2: Claude가 자율 판단으로 Agent() 도구 호출 (Hook이 있으면 강제됨)
    ↓
Phase 4-1: Agent() 실행 → 서브에이전트 생성
```

Hook이 없으면 Claude가 Agent 도구 description의 에이전트 목록만 보고 Agent()를 호출할지 **자율 판단**한다. `subagent_type`은 자유 문자열이므로 enum 제약도 없다.
- Hook 없을 때 위임률: **60%** (02 실험 v1 none)
- Hook 있을 때 위임률: **87%** (02 실험 v5)

**mitmproxy 검증 결과:**
```
# Agent 도구의 description에 에이전트 목록 포함 (tools[0], 9,931자)
"Available agent types and the tools they have access to:
- code-analyzer: 코드 구조와 패턴을 분석하는 에이전트... (Tools: Read, Grep, Glob)
- db-query-helper: JPA Repository와 QueryDSL... (Tools: Read, Grep, Glob)
..."

# subagent_type은 자유 문자열 (enum 없음)
"subagent_type": {"description": "The type of specialized agent to use for this task", "type": "string"}
```

### Q3. 스킬이 서브에이전트에 자동으로 전달되나?

**된다.** 소스 코드 검증 결과:

1. **스킬 목록 (`skill_listing`)**: `H=!q.agentId` 조건 **바깥**에 있어서 서브에이전트에도 포함됨
2. **Skill 도구**: 제외 목록(`wT6`, `QR8`)에 `xj`(Skill)가 없어서 서브에이전트도 사용 가능

Phase 4-3에서 서브에이전트 컨텍스트 조립 시 포함되는 것:

| 포함 | 설명 | 미포함 | 설명 |
|------|------|--------|------|
| 에이전트 .md 본문 (Phase 4-2) | 선택된 에이전트의 마크다운 본문 (frontmatter 제외) | Hook stdout (Phase 2-6) | Hook은 서브에이전트에 전파 안됨 |
| CLAUDE.md (Phase 1-10) | 프로젝트 설정 문서 | 에이전트 목록 (Phase 2-2) | Task()를 못 쓰니 불필요 |
| rules/*.md (Phase 1-11) | 프로젝트 규칙 문서들 | Task() 도구 | `wT6` 제외 목록에 포함 → 재위임 차단 |
| Task prompt | 메인이 `Task(prompt="N+1 쿼리 수정해줘")`로 넘긴 문자열 | | |
| **스킬 목록 (`skill_listing`)** ✅ | Phase 2-5와 동일한 스킬 이름+설명 목록 (예: `- entity-skill: JPA Entity 작성 가이드`) | | |
| **Skill() 도구** ✅ | 서브에이전트가 직접 `Skill("entity-skill")` 호출 가능 → 스킬 내용이 서브에이전트 컨텍스트에 로드됨 | | |

서브에이전트도 스킬 목록을 보고 Skill() 호출이 가능하다. 다만 Task()는 `wT6` 제외 목록에 있어서 서브에이전트가 다시 다른 에이전트에 재위임하는 것은 차단된다.

**소스 근거:**
```js
// cli.js — 도구 제외 목록
wT6 = new Set([dU, xM, KT6, Iq, YH, UU])  // Iq=Task 제외, xj=Skill 없음
QR8 = new Set([...wT6])                     // 비빌트인도 동일

// cli.js — attachment 조립
H = !q.agentId  // 서브에이전트면 false
// skill_listing은 H 조건 바깥 → 항상 포함
f2("skill_listing", () => m6Y(O))  // 조건 없이 실행
// IDE 전용만 H로 게이팅
D = H ? [f2("ide_selection",...), ...] : []
```

---

### Q4. Skill() 호출 후 Task() 위임하면 스킬 내용이 전달되나?

**메인에서 Skill()로 로드한 내용은 서브에이전트에 안 넘어간다.** 하지만 Q3에서 확인한 대로, 서브에이전트도 스킬 목록과 Skill 도구를 갖고 있으므로 **서브에이전트가 스스로 Skill()을 호출할 수 있다.**

두 가지 경로:

```
경로 A (메인에서 Skill → Task): 스킬 내용 소실
  메인: Skill("entity-skill") → 메인 컨텍스트에 로드
  메인: Task("db-query-helper") → 서브에이전트 생성
  → 메인의 Skill() 내용은 서브에이전트에 안 넘어감

경로 B (서브에이전트가 직접 Skill 호출): 정상
  메인: Task("db-query-helper", prompt="Entity 추가해줘")
  서브: 스킬 목록 보고 Skill("entity-skill") 직접 호출
  → 서브에이전트 컨텍스트에 스킬 내용 로드됨 ✅
```

CLAUDE.md의 Read → Task prompt 포함 패턴은 경로 B가 불확실할 때의 수동 보장 방법:
```
Read(".claude/skills/entity-skill/SKILL.md")
Task(prompt="<skill-guide>{읽은 내용}</skill-guide>\n유저 요청")
```

---

### Q5. Hook stdout은 어떤 형태로 주입되나?

1. Hook 프로세스 실행 → stdout 캡처
2. `jyq()`: JSON이 아니면 `{ plainText }`, JSON이면 structured output
3. `hook_success` 케이스: `t1({ content: "...", isMeta: true })`
4. `isMeta: true` → `<system-reminder>` 태그로 래핑
5. Phase 2 attachment로 시스템 프롬프트에 주입

```
<system-reminder>
UserPromptSubmit hook success: INSTRUCTION: MANDATORY...
</system-reminder>
```

Hook은 CLAUDE.md와 같은 `<system-reminder>` 형태로 주입되지만, **CLAUDE.md에만 면책 조항이 추가**되고 Hook에는 붙지 않는다. 이것이 동일 텍스트라도 Hook > CLAUDE.md인 근본 원인 (03-injection-path 실험 및 mitmproxy 검증으로 확인).

---

### Q6. Hook의 스킬 파트와 에이전트 파트가 동시에 있으면?

둘 다 해당되는 요청("User 엔티티에 새 필드 추가해줘")에서:

```
① 메인: Skill 평가 → Skill("entity-skill") → 메인 컨텍스트에 가이드 로드
② 메인: Agent 선택 → Task("db-query-helper") → 서브에이전트 생성
③ 서브에이전트: 스킬 목록은 보이지만, ①에서 로드한 내용은 안 넘어감
   → 서브에이전트가 스스로 Skill("entity-skill")을 호출하면 OK
   → 하지만 hook이 서브에이전트에는 전파 안 되므로 강제할 수 없음
```

**결과**: 메인에서 Skill()한 건 낭비되고, 서브에이전트가 알아서 Skill()을 호출할지는 자율 판단에 의존한다. Hook stdout이 서브에이전트에 전파되지 않으므로 스킬 사용을 강제할 방법이 없다.

01 실험(스킬만)과 02 실험(에이전트만)은 따로 테스트해서 이 상호작용 문제가 드러나지 않았음.

#### Phase별 흐름 표

| 순서 | Phase | 동작 | 컨텍스트 위치 | 결과 |
|------|-------|------|-------------|------|
| 1 | 2-6 | Hook stdout 주입 | 메인 시스템 프롬프트 (`<system-reminder>`) | 스킬 평가 + 에이전트 선택 **강제** |
| 2 | 3-1 | 메인 에이전트 API 호출 | Phase 2 전체 (Hook 포함) | Hook 지시에 따라 스킬 평가 시작 |
| 3 | 3-2 | Skill("entity-skill") 실행 | 메인 도구 호출 루프 | 스킬 내용이 **메인 컨텍스트**에 로드 |
| 4 | 3-3 | 반복 → 에이전트 선택 | 메인 도구 호출 루프 | Hook 지시에 따라 Task() 호출 결정 |
| 5 | 3-2 | Task("db-query-helper") 실행 | 메인 도구 호출 루프 | Phase 4 시작 → 서브에이전트 생성 |
| 6 | 4-3 | 서브에이전트 컨텍스트 조립 | 서브에이전트 시스템 프롬프트 | ③의 스킬 내용 **미포함**, skill_listing만 포함 |
| 7 | 4-4 | 서브에이전트 실행 | 서브에이전트 독립 루프 | Hook 없음 → Skill() 호출은 **자율 판단** |

| 구분 | 메인 에이전트 | 서브에이전트 |
|------|-------------|-------------|
| Hook 강제 | ✅ Phase 2-6에서 주입 | ❌ 전파 안됨 |
| 스킬 목록 | ✅ Phase 2-5 | ✅ Phase 4-4에서 재조립 |
| Skill 도구 | ✅ 사용 가능 | ✅ 사용 가능 |
| Skill() 내용 전달 | 메인 컨텍스트에만 | ❌ 메인에서 로드한 건 안 넘어감 |
| Skill() 호출 방식 | Hook이 **강제** | **자율 판단** (스킬 목록 보고 알아서) |

---

*새 질문은 아래에 추가*
