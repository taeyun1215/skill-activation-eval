# v1 — 위임 지시 강도

> CLAUDE.md에 "반드시 위임하세요"라고 강하게 쓰면 에이전트 선택이 나아지는가?

## 배경

01 실험에서 UserPromptSubmit hook으로 메인 에이전트의 스킬 호출을 100% 유도할 수 있음을 확인했다. 하지만 실제 워크플로에서는 메인 에이전트가 직접 코드를 쓰지 않고, **서브에이전트에 위임**한다. hook은 서브에이전트에 전파되지 않으므로, CLAUDE.md 지시만으로 올바른 서브에이전트를 선택하게 만들어야 한다.

가장 단순한 가설부터 시작: **"위임하세요"라는 지시를 강하게 쓰면 위임률과 정확도가 올라갈 것이다.**

## 설정

| 항목 | 값 |
|------|-----|
| 독립변수 | Agent Delegation 지시 강도 (none → mention → should → must) |
| 고정 | 에이전트 이름만 나열 (설명 없음) |
| 테스트 | 16건 × 4 configs × 1R |
| 모델 | sonnet, max-turns 8 |

## 전체 정확도

| Config | 위임률 | 정확도 |
|--------|--------|--------|
| none | 12/16 (75%) | 5/16 (31%) |
| mention | 14/16 (87%) | 8/16 (50%) |
| should | 11/16 (68%) | 8/16 (50%) |
| must | 13/16 (81%) | 8/16 (50%) |

## 유형별 정확도

| Config | direct (6) | natural (6) | ambiguous (4) |
|--------|-----------|-------------|---------------|
| none | 2/6 (33%) | 3/6 (50%) | 0/4 (0%) |
| mention | 3/6 (50%) | 4/6 (66%) | 1/4 (25%) |
| should | 4/6 (66%) | 3/6 (50%) | 1/4 (25%) |
| must | 4/6 (66%) | 3/6 (50%) | 1/4 (25%) |

## 케이스별 상세

| ID | Type | Expected | none | mention | should | must |
|----|------|----------|------|---------|--------|------|
| D01 | direct | api-des | ✓ | ✓ | ✓ | ✓ |
| D02 | direct | code-ana | ✓ | ✓ | ✓ | ✓ |
| D03 | direct | db-query | ✗(perf-opt) | ✗(code-ana) | ✗(-) | ✗(perf-opt) |
| D04 | direct | test-wr | ✗(Explore) | ✗(Explore) | ✓ | ✓ |
| D05 | direct | perf-opt | ✗(Explore) | ✓ | ✓ | ✓ |
| D06 | direct | mig-plan | ✗(-) | ✗(-) | ✗(-) | ✗(-) |
| N01 | natural | api-des | ✓ | ✓ | ✓ | ✓ |
| N02 | natural | code-ana | ✓ | ✓ | ✓ | ✓ |
| N03 | natural | db-query | ✗(perf-opt) | ✗(perf-opt) | ✗(perf-opt) | ✗(perf-opt) |
| N04 | natural | test-wr | ✗(Explore) | ✗(Explore) | ✗(-) | ✗(code-ana) |
| N05 | natural | perf-opt | ✓ | ✓ | ✓ | ✓ |
| N06 | natural | mig-plan | ✗(-) | ✓ | ✗(-) | ✗(code-ana) |
| A01 | ambig | api-des,code-ana | ✗(-) | ✗(Explore) | ✗(-) | ✗(-) |
| A02 | ambig | db-query,api-des | ✗(Explore) | ✓ | ✗(Explore) | ✓ |
| A03 | ambig | code-ana,api-des | ✗(Explore) | ✗(Explore) | ✗(Explore) | ✗(Explore) |
| A04 | ambig | mig-plan,perf-opt | ✗(-) | ✗(-) | ✓ | ✗(-) |

## 결론

1. **위임 지시 강도는 의미 없음** — none 75% vs must 81%. 차이 미미
2. **정확도 병목은 에이전트 "설명" 부재** — 이름만으로는 50%가 한계
3. **D06 migration-planner 전멸** — 이름이 낯설면 아예 선택 안 함
4. **N03 "쿼리가 느려" 전멸** — "느려" → perf-opt 키워드 편향

## → v2로의 전환

가설이 틀렸다. 문제는 "위임을 안 한다"가 아니라 **"올바른 에이전트를 못 고른다"**. `db-query-helper`, `migration-planner` 같은 낯선 이름은 선택률 0%. 모델이 에이전트가 뭘 하는지 모르니까 익숙한 것(code-analyzer, Explore)만 고른다.

→ CLAUDE.md에 에이전트 **설명을 추가**하면 정확도가 올라가는지 테스트 (v2)
