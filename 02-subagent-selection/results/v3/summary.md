# v3 — 디스크립션 교차참조

> 에이전트 .md의 description에 교차참조("X는 Y를 사용하세요")를 추가하면 정확도가 올라가는가?

## 배경

v2에서 CLAUDE.md에 에이전트 설명을 아무리 써도 62%가 한계였다. 그런데 핵심 발견이 있었다: Claude Code가 `Task(subagent_type=...)` 도구를 생성할 때, CLAUDE.md가 아니라 **에이전트 .md 파일의 `description` 프론트매터**를 내부적으로 참조한다.

그러면 CLAUDE.md를 고치는 게 아니라, 에이전트 .md 파일 자체를 개선하면 어떨까? 특히 v1~v2에서 반복적으로 발생한 에이전트 간 혼동(예: "느려" → perf-opt로 가야 하는데 db-query-helper가 맞음)을 방지하는 **교차참조**를 description에 추가한다.

예: `db-query-helper.md`의 description → "JPA Repository와 QueryDSL 쿼리 작성 전문가. **쿼리 성능이 느린 경우에도 이 에이전트를 사용하세요.** performance-optimizer는 서비스 레벨 성능 최적화용입니다."

## 설정

| 항목 | 값 |
|------|-----|
| 독립변수 | v2와 동일 4 configs |
| 변경 | 에이전트 description에 교차참조 추가 |
| 고정 | Agent Delegation = must |
| 테스트 | 16건 × 4 configs × 2R |
| 모델 | sonnet, max-turns 8 |

## 전체 정확도 (R1+R2 평균)

| Config | R1 | R2 | 평균 |
|--------|-----|-----|------|
| name-only | 75% | 69% | **72%** |
| one-liner | 56% | 69% | 62% |
| detailed | 69% | 75% | **72%** |
| read-file | 69% | 69% | 69% |

## v2 대비 변화

| Config | v2 정확도 | v3 R1+R2 | 변화 |
|--------|----------|----------|------|
| name-only | 56% | **72%** | **+16%** |
| one-liner | 50% | 62% | +12% |
| detailed | 62% | **72%** | +10% |
| read-file | 56% | 69% | +13% |

> 모든 config에서 상승. name-only와 detailed가 72%로 공동 1등.

## R1 케이스별 상세

| ID | Type | Expected | name-only | one-liner | detailed | read-file |
|----|------|----------|-----------|-----------|----------|-----------|
| D01 | direct | api-des | ✓ | ✓ | ✓ | ✓ |
| D02 | direct | code-ana | ✓ | ✓ | ✓ | ✓ |
| D03 | direct | db-query | **✓** | ✗(code-ana) | ✗(code-ana) | **✓** |
| D04 | direct | test-wr | ✓ | ✓ | ✓ | ✓ |
| D05 | direct | perf-opt | ✓ | ✓ | ✓ | ✓ |
| D06 | direct | mig-plan | ✓ | ✓ | ✓ | ✓ |
| N01 | natural | api-des | ✓ | ✓ | ✓ | ✓ |
| N02 | natural | code-ana | ✓ | ✓ | ✓ | ✗(-) |
| N03 | natural | db-query | **✓** | **✓** | **✓** | **✓** |
| N04 | natural | test-wr | ✗(Explore) | ✗(code-ana) | ✗(code-ana) | ✗(-) |
| N05 | natural | perf-opt | ✓ | ✗(code-ana) | ✓ | ✓ |
| N06 | natural | mig-plan | ✓ | ✓ | ✗(-) | ✓ |
| A01 | ambig | api-des,code-ana | ✗(-) | ✗(-) | ✗(-) | ✗(-) |
| A02 | ambig | db-query,api-des | ✗(-) | ✗(mig-plan) | ✓ | ✗(mig-plan) |
| A03 | ambig | code-ana,api-des | ✗(-) | ✗(-) | ✗(-) | ✗(-) |
| A04 | ambig | mig-plan,perf-opt | ✓ | ✗(-) | ✓ | ✓ |

## 결론

1. **name-only와 detailed가 72%로 공동 1등** — CLAUDE.md에 아무 설명 없어도 description만 좋으면 됨
2. **N03 R1 전 config 성공** — v2에서 detailed만 성공 → v3에서 교차참조로 전부 성공. "느려" 편향 극복
3. **D03 name-only/read-file 성공** — v2에서 전멸이었던 "쿼리 최적화"가 부분 해결
4. **description 프론트매터가 선택의 핵심 변수** — Claude Code가 Agent 도구 생성 시 내부적으로 사용
5. **N04 "엣지 케이스" 전멸 지속** — 테스트 키워드가 프롬프트에 없음

## → v4로의 전환

v3까지 CLAUDE.md와 에이전트 description을 최적화하여 72%에 도달. 하지만 더 이상 description만으로는 한계가 보인다.

한편, 01 실험에서 **"hook으로 시스템 메시지를 주입하면 행동을 100% 강제할 수 있다"**는 것을 이미 증명했다. 01은 Skill() 호출이었지만, 같은 원리를 에이전트 선택에도 적용할 수 있지 않을까?

01의 forced-eval hook은 "각 스킬을 1~5점으로 채점한 뒤 최고 점수를 호출하라"는 구조. 이걸 에이전트 선택용으로 변형한다: **"각 에이전트의 적합도를 채점하고, 가장 적합한 에이전트에 위임하라."**

추가로 다른 접근도 비교한다: 외부 LLM(Haiku 4.5)에게 에이전트를 추천받아 Claude에 주입하는 방식.

→ description 교차참조(v3) + hook 기반 강제 평가(01) 결합 (v4)
