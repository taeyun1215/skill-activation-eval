# v4 — hook 기반 에이전트 선택

> UserPromptSubmit hook으로 사고 과정을 강제하면 에이전트 선택 정확도가 올라가는가?

## 배경

v3에서 에이전트 description 교차참조로 75%에 도달했지만 한계가 보였다. 한편, 01 실험에서 hook으로 스킬 호출을 100% 강제한 성공 사례가 있다. **두 접근을 결합**한다: description 교차참조(v3) + hook 기반 강제 평가(01).

01의 forced-eval hook은 "각 스킬을 채점하고 최고점을 호출하라"는 구조였다. 이걸 에이전트 선택용으로 변형: **"각 에이전트의 적합도를 1~5점으로 채점하고, 가장 적합한 에이전트에 위임하라."** 추가로, 외부 LLM(Haiku 4.5)에게 정답을 물어보고 Claude에 주입하는 방식도 비교.

또한 테스트 케이스를 16건 → 20건으로 확장하고, 2R 반복으로 신뢰도를 높였다.

## 설정

| 항목 | 값 |
|------|-----|
| 독립변수 | hook 전략 (none → simple → forced-eval → llm-eval-haiku) |
| 고정 | Agent Delegation = must, 에이전트 description 교차참조 포함 |
| 테스트 | 20건 × 4 configs × 2R |
| 모델 | sonnet, max-turns 8 |

### Config 상세

| Config | 설명 |
|--------|------|
| none | hook 없음 — CLAUDE.md 지시만 사용 |
| simple | "에이전트에 위임하세요" 단순 안내 |
| forced-eval | Step 1~3 강제 평가 (각 에이전트 적합도 1~5점 채점 후 선택) |
| llm-eval-haiku | Haiku 4.5가 에이전트를 추천 → Claude에 주입 |

## 전체 정확도

| Config | R1 | R2 | 평균 |
|--------|-----|-----|------|
| none | 11/20 (55%) | 13/20 (65%) | 24/40 (60%) |
| simple | 14/20 (70%) | 14/20 (70%) | 28/40 (70%) |
| forced-eval | 17/20 (85%) | 16/20 (80%) | **33/40 (82%)** |
| llm-eval-haiku | 14/20 (70%) | 14/20 (70%) | 28/40 (70%) |

## v3 대비 변화

| Config | v3 정확도 (best) | v4 정확도 | 변화 |
|--------|-----------------|----------|------|
| none (≈name-only) | 75% | 60% | -15% |
| forced-eval | — | **82%** | 신규 최고 |

> v3 → v4는 테스트 케이스가 16건→20건으로 확장되었고, 2R 평균을 사용하므로 직접 비교에 주의 필요.

## 유형별 정확도 (R1+R2 합산)

| Config | direct (7건×2R) | natural (9건×2R) | ambiguous (4건×2R) |
|--------|-----------------|------------------|-------------------|
| none | 11/14 (78%) | 10/18 (55%) | 3/8 (37%) |
| simple | 13/14 (92%) | 11/18 (61%) | 4/8 (50%) |
| forced-eval | **14/14 (100%)** | **15/18 (83%)** | 4/8 (50%) |
| llm-eval-haiku | 13/14 (92%) | 10/18 (55%) | **5/8 (62%)** |

## 케이스별 상세 (R1/R2)

| ID | Type | Expected | none | simple | forced-eval | llm-haiku |
|----|------|----------|------|--------|-------------|------------|
| D01 | direct | api-des | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| D02 | direct | code-ana | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| D03 | direct | db-query | ✗/✗ | ✗/✓ | ✓/✓ | ✓/✓ |
| D04 | direct | test-wr | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✗ |
| D05 | direct | perf-opt | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| D06 | direct | mig-plan | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| D07 | direct | db-query | ✗/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| N01 | natural | api-des | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| N02 | natural | code-ana | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| N03 | natural | db-query | ✗/✗ | ✓/✗ | ✗/✗ | ✗/✓ |
| N04 | natural | test-wr | ✗/✗ | ✗/✗ | ✓/✗ | ✗/✗ |
| N05 | natural | perf-opt | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| N06 | natural | mig-plan | ✓/✓ | ✓/✓ | ✓/✓ | ✗/✓ |
| N07 | natural | test-wr | ✗/✗ | ✗/✗ | ✓/✓ | ✗/✗ |
| N08 | natural | perf-opt | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |
| N09 | natural | api-des | ✗/✗ | ✗/✗ | ✓/✓ | ✗/✗ |
| A01 | ambig | api-des,code-ana | ✗/✗ | ✗/✗ | ✓/✓ | ✗/✗ |
| A02 | ambig | db-query,api-des | ✗/✓ | ✓/✓ | ✗/✗ | ✓/✓ |
| A03 | ambig | code-ana,api-des | ✗/✗ | ✗/✗ | ✗/✗ | ✓/✗ |
| A04 | ambig | mig-plan,perf-opt | ✓/✓ | ✓/✓ | ✓/✓ | ✓/✓ |

## R1 vs R2 안정성

| Config | 양쪽 ✓ | 양쪽 ✗ | 불안정 |
|--------|--------|--------|--------|
| none | 9 | 8 | 3 |
| simple | 12 | 5 | 3 |
| forced-eval | 15 | 4 | 1 (N04) |
| llm-eval-haiku | 12 | 5 | 3 |

## 실패 패턴

| 패턴 | 케이스 | 설명 |
|------|--------|------|
| 키워드 편향 | N03 | "느려" → perf-opt로 편향. forced-eval 포함 전 config 불안정 |
| Explore 유출 | N04, N07 | 에이전트 대신 빌트인 Explore로 보냄 |
| 위임 거부 | A01, N09 | none/simple/llm-haiku에서 위임 자체를 안 함. forced-eval만 해결 |
| 범위 모호 | A03 | "새 기능 추가" — 전 config 불안정 |
| 카테고리 경계 | A02 | "데이터 모델 설계" — forced-eval만 code-ana로 오답 |

## 결론

1. **forced-eval 82%로 최고** — 구조화된 평가 과정 강제가 가장 효과적
2. **"사고 과정 강제" > "정답 알려주기"** — 가장 놀라운 발견. Haiku가 정답을 추천해도 Claude가 무시하고 Explore로 보냄. llm-haiku(70%) = simple(70%). 모델에게 답을 알려주는 것보다 스스로 생각하게 강제하는 것이 효과적
3. **forced-eval은 direct 100%** — 명시적 요청은 완벽 해결
4. **natural 유형이 핵심 차별점** — forced-eval 83% vs others 55~61%
5. **llm-haiku은 ambiguous에 강점** — 62%로 forced-eval(50%)보다 높음
6. **forced-eval 독점 해결 3건** — N07, N09, A01은 forced-eval만 ✓/✓
7. **N03 "느려" 편향은 hook으로도 해결 불가** — v1부터 v4까지 일관된 실패

## → v5로의 전환

82%를 달성했지만, N03 "쿼리가 느려"는 v1부터 v4까지 **전 실험에서 가장 일관되게 실패하는 케이스**다. forced-eval에서 Step 1~3으로 각 에이전트를 평가하라고 지시해도 "느려 → 성능 → performance-optimizer"라는 키워드 편향을 극복하지 못한다.

여러 개선 방안을 검토한 결과, **Step 0 요청 분류**가 가장 범용적이었다. 핵심 아이디어: 에이전트를 평가하기 전에 요청 자체를 먼저 분류. "이 요청이 query-level인지 system-level인지" 구조적으로 파악하면, "느려"라는 키워드에 바로 반응하지 않는다. N03은 "findByNickname 쿼리"라고 명시하므로 query-level → db-query-helper가 자연스럽게 매칭.

→ forced-eval의 Step 1~3 앞에 Step 0 요청 분류 추가 (v5)
