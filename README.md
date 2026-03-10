# claude-code-best-practices

Claude Code의 스킬/에이전트 시스템이 실제로 의도대로 동작하는지 실험적으로 검증하는 프로젝트.

`.claude/skills/`와 `.claude/agents/`를 정의해도 모델이 이를 올바르게 활용하는 보장은 없다.
어떤 설정 조합이 가장 높은 정확도를 만드는지 단계별로 확인한다.

## 실험 파이프라인

각 실험은 이전 실험의 결과 위에 쌓인다.

```
01 메인 세션에서 스킬을 호출하는가?        → forced-eval 훅으로 100%
   ↓
02 올바른 서브에이전트를 선택하는가?        → description 교차참조 + 훅 강제 평가로 92.5%
   ↓
03 Hook vs CLAUDE.md, 왜 차이가 나는가?    → 면책 조항이 근본 원인 (mitmproxy 검증)
```

## 실험 결과

| # | 실험 | 질문 | 최종 정확도 |
|---|------|------|-----------|
| 01 | [Hook Activation](01-hook-activation/) | 어떤 훅이 스킬 호출을 가장 잘 유도하는가? | **100%** |
| 02 | [Subagent Selection](02-subagent-selection/) | 어떤 설정이 올바른 서브에이전트 선택을 유도하는가? | **92.5%** |
| 03 | [Injection Path](03-injection-path/) | Hook과 CLAUDE.md의 성능 차이는 왜 발생하는가? | Hook **92.5%** vs CLAUDE.md **77.5%** |
| 06 | [QA](06-qa/) | Claude Code 내부 구조는 어떻게 되어 있는가? | — |

### 02 정확도 추이 (5개 버전 반복 실험)

```
v1 위임 지시 강도       50%  ████████████████████
v2 CLAUDE.md 설명       62%  █████████████████████████
v3 description 교차참조  72%  █████████████████████████████
v4 훅 강제 평가          82%  █████████████████████████████████
v5 Step 0 요청 분류      92%  █████████████████████████████████████
```

### 03 주입 경로별 성능 비교

```
hook-v5          92.5%  █████████████████████████████████████
minimal-hook     87.5%  ███████████████████████████████████
double           85.0%  ██████████████████████████████████
v5-top           85.0%  ██████████████████████████████████
claudemd-v5      77.5%  ███████████████████████████████
hook-short       67.5%  ███████████████████████████
none             60.0%  ████████████████████████
```

## 채택된 전략 (01~03)

| 계층 | 전략 | 설정 위치 |
|------|------|----------|
| 메인 세션 스킬 호출 | forced-eval 훅으로 Skill() 호출 강제 | `.claude/settings.json` |
| 서브에이전트 선택 | description 교차참조 + Step 0 분류 + 강제 평가 훅 | `.claude/agents/*.md` + 훅 |
| 주입 경로 | **Hook > CLAUDE.md** — 면책 조항 회피로 +15%p | `UserPromptSubmit` 훅 |

## 핵심 발견

1. **description 프론트매터가 핵심 변수** — CLAUDE.md보다 에이전트 `.md`의 description이 선택에 더 큰 영향
2. **"사고 강제" > "정답 알려주기"** — 외부 LLM이 정답을 추천해도 무시함. 스스로 채점하게 해야 효과적
3. **"분류 먼저, 평가 나중"** — 키워드 편향("느려" → performance-optimizer)을 사전 분류로 극복
4. **훅은 메인 세션에서만 동작** — 서브에이전트에는 전파되지 않음. 프롬프트로 전달해야 함
5. **CLAUDE.md 면책 조항이 성능 저하 원인** — Claude Code는 CLAUDE.md에 `"may or may not be relevant"` 면책 조항을 자동 추가하여 지시가 약화됨. Hook에는 붙지 않음 ([#22309](https://github.com/anthropics/claude-code/issues/22309))
6. **구조화된 사고가 ~17.5%p 기여** — Step 0-1-2-3 강제 평가가 가장 큰 성능 향상 요인
7. **이중 주입은 역효과** — 같은 텍스트를 CLAUDE.md + Hook 양쪽에 넣으면 오히려 성능 저하

## 프로젝트 구조

```
claude-code-best-practices/
├── 01-hook-activation/         ← 메인 세션 스킬 호출 (완료)
├── 02-subagent-selection/      ← 서브에이전트 선택 v1~v5 (완료)
│   ├── PLAN.md                 ← 상세 실험 설계 및 내러티브
│   ├── hooks/                  ← UserPromptSubmit 훅 스크립트
│   ├── runv{1,2,4,5}.sh        ← 실행 스크립트
│   └── results/                ← CSV + 로그
├── 03-injection-path/          ← Hook vs CLAUDE.md 주입 경로 비교 (완료)
│   ├── PLAN.md                 ← 6개 config 통합 결과 + 원인 분석
│   ├── api-capture-interactive.json ← mitmproxy API 캡처 원본
│   ├── run.sh                  ← 실험 스크립트
│   └── results/                ← 6 config × 2 round CSV
├── 06-qa/                      ← Claude Code 내부 구조 Q&A
│   └── QA.md                   ← Phase 1-4 로딩, 면책 조항, mitmproxy 검증
└── .claude/
    ├── agents/                 ← 테스트용 에이전트 6개
    ├── skills/                 ← 테스트용 스킬 9개
    └── hooks/                  ← forced-eval 훅
```
