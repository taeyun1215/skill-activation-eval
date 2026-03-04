# v2 — 에이전트 설명 수준

> CLAUDE.md에 에이전트 설명을 얼마나 자세히 쓰면 정확도가 올라가는가?

## 배경

v1에서 위임 지시 강도는 의미 없고, 정확도 병목이 **에이전트 설명 부재**임을 확인했다. 이름만 나열하면 `migration-planner` 같은 낯선 에이전트는 선택률 0%.

그러면 CLAUDE.md의 `Available Agents` 섹션에 설명을 추가하면 어떨까? 설명의 상세도를 4단계로 나누어 어느 수준이 최적인지 측정한다.

## 설정

| 항목 | 값 |
|------|-----|
| 독립변수 | Available Agents 설명 수준 (name-only → one-liner → detailed → read-file) |
| 고정 | Agent Delegation = must |
| 테스트 | 16건 × 4 configs × 1R |
| 모델 | sonnet, max-turns 8 |

### Config 상세

| Config | Available Agents 섹션 내용 |
|--------|--------------------------|
| name-only | 이름만 나열 (v1 must와 동일 베이스라인) |
| one-liner | 이름 + 한줄 설명 (frontmatter description) |
| detailed | 이름 + 2~3줄 + 적합/비적합 태그 |
| read-file | 이름 + "`.claude/agents/{이름}.md`를 Read하세요" |

## 전체 정확도

| Config | 위임률 | 정확도 |
|--------|--------|--------|
| name-only | 12/16 (75%) | 9/16 (56%) |
| one-liner | 14/16 (87%) | 8/16 (50%) |
| detailed | 11/16 (68%) | **10/16 (62%)** |
| read-file | 11/16 (68%) | 9/16 (56%) |

## v1 대비 변화

| 지표 | v1 must | v2 name-only | v2 detailed |
|------|---------|-------------|-------------|
| 위임률 | 81% | 75% | 68% |
| 정확도 | 50% | 56% | **62%** |

## 유형별 정확도

| Config | direct (6) | natural (6) | ambiguous (4) |
|--------|-----------|-------------|---------------|
| name-only | 4/6 (66%) | 4/6 (66%) | 1/4 (25%) |
| one-liner | 4/6 (66%) | 4/6 (66%) | 0/4 (0%) |
| detailed | **5/6 (83%)** | **5/6 (83%)** | 0/4 (0%) |
| read-file | 4/6 (66%) | 4/6 (66%) | 1/4 (25%) |

## 케이스별 상세

| ID | Type | Expected | name-only | one-liner | detailed | read-file |
|----|------|----------|-----------|-----------|----------|-----------|
| D01 | direct | api-des | ✓ | ✓ | ✓ | ✓ |
| D02 | direct | code-ana | ✓ | ✓ | ✓ | ✓ |
| D03 | direct | db-query | ✗(code-ana,perf-opt) | ✗(perf-opt) | ✗(perf-opt) | ✗(perf-opt) |
| D04 | direct | test-wr | ✗(-) | ✓ | ✓ | ✗(-) |
| D05 | direct | perf-opt | ✓ | ✗(code-ana) | ✓ | ✓ |
| D06 | direct | mig-plan | ✓ | ✓ | ✓ | ✓ |
| N01 | natural | api-des | ✓ | ✓ | ✓ | ✓ |
| N02 | natural | code-ana | ✓ | ✓ | ✓ | ✓ |
| N03 | natural | db-query | ✗(perf-opt) | ✗(perf-opt) | **✓** | ✗(perf-opt) |
| N04 | natural | test-wr | ✗(code-ana) | ✗(code-ana) | ✗(-) | ✗(-) |
| N05 | natural | perf-opt | ✓ | ✓ | ✓ | ✓ |
| N06 | natural | mig-plan | ✓ | ✓ | ✓ | ✓ |
| A01 | ambig | api-des,code-ana | ✗(-) | ✗(-) | ✗(-) | ✗(-) |
| A02 | ambig | db-query,api-des | ✗(-) | ✗(code-ana) | ✗(-) | ✓ |
| A03 | ambig | code-ana,api-des | ✗(-) | ✗(Explore) | ✗(-) | ✗(-) |
| A04 | ambig | mig-plan,perf-opt | ✓ | ✗(-) | ✗(-) | ✗(-) |

## 결론

1. **detailed가 정확도 최고 (62%)** — 적합/비적합 태그가 에이전트 구분에 도움
2. **D06 migration-planner 부활** — v1에서 전멸 → v2에서 전 config 성공. 설명만 있으면 됨
3. **N03 detailed에서 첫 성공** — db-query-helper를 처음으로 올바르게 선택
4. **위임률은 설명 많을수록 하락** — detailed(68%) < name-only(75%). 에이전트 역할을 알게 되니 "내가 직접 하겠다" 판단
5. **D03 "쿼리 최적화" 전멸** — "최적화" 키워드 편향 극복 불가

## → v3로의 전환

v2에서 CLAUDE.md 설명을 아무리 써도 62%가 한계. 그런데 분석하면서 흥미로운 점을 발견했다: Claude Code가 `Task(subagent_type=...)` 도구를 생성할 때 CLAUDE.md가 아니라 **에이전트 .md 파일의 `description` 프론트매터**를 내부적으로 참조한다.

CLAUDE.md를 고치는 게 아니라, **에이전트 .md 파일 자체를 개선**하면 어떨까? 특히 에이전트 간 혼동을 방지하는 **교차참조**를 description에 추가해본다. 예: "쿼리 성능이 느린 경우에도 이 에이전트를 사용하세요. performance-optimizer는 서비스 레벨 성능 최적화용입니다."

→ 에이전트 .md의 description에 교차참조 추가 (v3)
