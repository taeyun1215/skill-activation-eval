# v5 — Step 0 요청 분류 추가

> 에이전트 평가 전에 요청 자체를 먼저 분류(Step 0)하면 키워드 편향을 극복할 수 있는가?

## 배경

v4 forced-eval(82%)의 안정적 실패 케이스 3건을 분석했다:

- **N03 "findByNickname 쿼리가 너무 느려"** — "느려" → perf-opt 키워드 편향. v1부터 v4까지 전 실험 최다 실패.
- **A02 "데이터 모델 설계해줘"** — code-ana로 오분류. 카테고리 경계 문제.
- **A03 "notification 모듈에 새 기능 추가해줘"** — 범위가 너무 넓어 위임 자체를 회피.

forced-eval의 Step 1~3은 "에이전트별 적합도 채점"인데, 모델이 채점하기 전에 이미 "느려 → 성능"이라는 키워드에 끌린다. **에이전트를 보기 전에 요청의 구조적 속성을 먼저 파악**하면 이 편향을 차단할 수 있지 않을까?

핵심 아이디어: **"분류 먼저, 평가 나중."** N03은 "findByNickname 쿼리"라고 명시하므로 query-level로 분류되고, 그러면 db-query-helper가 자연스럽게 매칭된다.

## 설정

| 항목 | 값 |
|------|-----|
| 독립변수 | Step 0 유무 (v4 forced-eval vs v5 forced-eval) |
| 변경 | 기존 Step 1~3 앞에 Step 0 요청 분류 추가 |
| 고정 | Agent Delegation = must, 에이전트 description 교차참조 포함 |
| 테스트 | 20건 × 1 config × 2R |
| 모델 | sonnet, max-turns 8 |

### Step 0 내용

v4 forced-eval의 Step 1~3(에이전트별 적합도 채점) 앞에 요청 분류 단계를 추가:

```
Step 0 — 요청 분류:
- 작업 레벨: query-level | service-level | system-level | design-level
- 작업 유형: 분석 | 작성/수정 | 테스트 | 설계 | 계획
- 대상 특정성: specific | general | vague
```

## 전체 정확도

| Config | R1 | R2 | 평균 |
|--------|-----|-----|------|
| v5 forced-eval | 17/20 (85%) | 18/20 (90%) | **35/40 (87%)** |

## v4 대비 변화

| Config | v4 정확도 | v5 정확도 | 변화 |
|--------|----------|----------|------|
| forced-eval (Step 0 추가) | 82% | **87%** | **+5%p** |

## 유형별 정확도 (R1+R2 합산)

| Config | direct (7건×2R) | natural (9건×2R) | ambiguous (4건×2R) |
|--------|-----------------|------------------|-------------------|
| v5 forced-eval | **14/14 (100%)** | **17/18 (94%)** | 4/8 (50%) |
| v4 forced-eval | 14/14 (100%) | 15/18 (83%) | 4/8 (50%) |

> natural 유형에서 83% → 94%로 개선. direct와 ambiguous는 동일.

## 케이스별 상세 (R1/R2)

| ID | Type | Expected | v5 | v4 forced-eval |
|----|------|----------|-----|----------------|
| D01 | direct | api-des | ✓/✓ | ✓/✓ |
| D02 | direct | code-ana | ✓/✓ | ✓/✓ |
| D03 | direct | db-query | ✓/✓ | ✓/✓ |
| D04 | direct | test-wr | ✓/✓ | ✓/✓ |
| D05 | direct | perf-opt | ✓/✓ | ✓/✓ |
| D06 | direct | mig-plan | ✓/✓ | ✓/✓ |
| D07 | direct | db-query | ✓/✓ | ✓/✓ |
| N01 | natural | api-des | ✓/✓ | ✓/✓ |
| N02 | natural | code-ana | ✓/✓ | ✓/✓ |
| **N03** | natural | db-query | **✓/✓** | ✗/✗ |
| **N04** | natural | test-wr | **✓/✓** | ✓/✗ |
| N05 | natural | perf-opt | ✓/✓ | ✓/✓ |
| N06 | natural | mig-plan | ✓/✓ | ✓/✓ |
| N07 | natural | test-wr | ✗/✓ | ✓/✓ |
| N08 | natural | perf-opt | ✓/✓ | ✓/✓ |
| N09 | natural | api-des | ✓/✓ | ✓/✓ |
| A01 | ambig | api-des,code-ana | ✓/✗ | ✓/✓ |
| **A02** | ambig | db-query,api-des | **✓/✓** | ✗/✗ |
| A03 | ambig | code-ana,api-des | ✗/✗ | ✗/✗ |
| A04 | ambig | mig-plan,perf-opt | ✗/✓ | ✓/✓ |

## 개선된 케이스

| ID | Prompt | v4 | v5 | Step 0이 해결한 것 |
|----|--------|----|----|-------------------|
| N03 | "findByNickname 쿼리가 너무 느려" | ✗/✗ | **✓/✓** | "query-level, specific" 분류 → 키워드 편향 극복 |
| N04 | "엣지 케이스가 걱정돼" | ✓/✗ | **✓/✓** | "테스트" 작업 유형 분류 → 안정화 |
| A02 | "데이터 모델 설계해줘" | ✗/✗ | **✓/✓** | "design-level" 분류 → api-designer 정확 선택 |

## 퇴보/불안정 케이스

| ID | Prompt | v4 | v5 | 비고 |
|----|--------|----|----|------|
| N07 | "버그가 나는데 테스트가 없어" | ✓/✓ | ✗/✓ | R1에서 위임 거부 |
| A01 | "새 API endpoint 만들어줘" | ✓/✓ | ✓/✗ | R2에서 위임 거부 |
| A04 | "채팅 모듈을 DynamoDB로 전환해줘" | ✓/✓ | ✗/✓ | R1에서 위임 거부 |

> 퇴보 케이스 모두 "위임 거부"(직접 처리). Step 0 분류 과정이 추가되면서 오히려 직접 처리 경향이 소폭 증가한 것으로 보임.

## 결론

1. **전체 정확도 82% → 87%** — Step 0 요청 분류 추가로 +5%p 개선
2. **N03 "느려" 편향 해결** — v1~v4까지 전 실험에서 가장 일관된 실패 케이스를 안정적으로 해결
3. **"분류 먼저, 평가 나중" 패턴 유효** — 요청의 구조적 속성을 먼저 파악하면 키워드에 끌리지 않음
4. **natural 94%** — 자연어 표현도 거의 완벽하게 처리
5. **ambiguous 50% 변동 없음** — 모호한 요청은 Step 0로도 개선 한계
6. **위임 거부 소폭 증가** — Step 0 과정이 추가되면서 직접 처리 경향이 미세하게 증가

## 남은 문제

- **A03 전멸 지속** — "notification 모듈에 새 기능 추가해줘"는 전 실험 전 config에서 실패. 요청 자체가 모호하면 분류도 모호
- **ambiguous 50% 천장** — 모호한 요청의 정확도를 올리려면 hook이 아닌 다른 접근(예: 사용자에게 질문, 멀티에이전트)이 필요할 수 있음
