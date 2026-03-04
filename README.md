# skill-activation-eval

Claude Code 스킬 시스템의 활성화/전달 전략을 실험으로 검증하는 프로젝트.

## 실험 목록

| # | 디렉토리 | 질문 | 최종 정확도 |
|---|---------|------|-----------|
| 01 | `01-hook-activation` | 어떤 훅이 메인 세션에서 스킬을 가장 잘 활성화하는가? | **forced-eval 100%** |
| 02 | `02-subagent-selection` | 어떤 설정이 올바른 서브에이전트 선택을 유도하는가? | **87%** (v5) |
| 03 | `03-skill-delivery` | 서브에이전트에 스킬을 어떻게 전달해야 하는가? | **direct-embed 100%** |
| 04 | `04-agent-delivery` | (계획 중) | — |

## 핵심 발견

```
01 메인 세션 스킬 호출     → forced-eval 훅으로 100% 활성화
02 서브에이전트 선택       → description 교차참조 + 훅 강제 평가로 87%
03 서브에이전트 스킬 전달   → <skill-guide>{SKILL.md}</skill-guide> 프롬프트 포함으로 100%
```

### 02 실험 정확도 추이

| 버전 | 핵심 변경 | 정확도 |
|------|----------|--------|
| v1 | 위임 지시 강도 | 50% |
| v2 | CLAUDE.md에 에이전트 설명 추가 | 62% |
| v3 | 에이전트 .md description 교차참조 | 72% |
| v4 | UserPromptSubmit 훅으로 강제 평가 | 82% |
| v5 | Step 0 요청 분류 추가 | **87%** |

## 채택된 전략

```
메인 세션:     forced-eval 훅 → Skill() 호출 → 100% 활성화
에이전트 선택:  description 교차참조 + Step 0 분류 + 강제 평가 훅 → 87%
스킬 전달:     <skill-guide>{SKILL.md}</skill-guide> 프롬프트 포함 → 100%
```

## 프로젝트 구조

```
skill-activation-eval/
├── PLAN.md                    ← 전체 실험 계획 및 내러티브
├── 01-hook-activation/        ← 메인 세션 스킬 활성화
├── 02-subagent-selection/     ← 서브에이전트 선택 (v1~v5)
│   ├── PLAN.md                ← 02 상세 실험 설계
│   ├── hooks/                 ← 훅 스크립트
│   ├── runv{1,2,4,5}.sh       ← 실행 스크립트
│   └── results/v{1~5}-final/  ← 결과 + summary.md
├── 03-skill-delivery/         ← 스킬 전달 방식
└── 04-agent-delivery/         ← (계획 중)
```
