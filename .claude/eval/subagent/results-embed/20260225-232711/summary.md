# Phase 3: 서브에이전트 스킬 전달률 비교

## 실험 목적

서브에이전트(Task)에 스킬을 **얼마나 확실하게 전달**할 수 있는가?

## 실험 조건

| 항목 | 값 |
|------|-----|
| 모델 | Sonnet |
| 테스트 케이스 | 20개 (positive 16 + negative 4) |
| 라운드 | 2회 |
| 타임아웃 | 60초 |
| max-turns | 3 |
| Tools | 제한 없음 (All Tools) |
| OMC | 비활성화 |
| 실행 | `claude -p` (서브에이전트 시뮬레이션) |

## Config 설명

| Config | 프롬프트에 추가되는 것 | 전달 감지 방법 |
|--------|-------------------|--------------|
| **none** | 없음 | Skill() 호출 여부 |
| **tag** | `<!-- skill: entity-skill -->` | Skill() 호출 여부 |
| **light-embed** | "entity-skill과 관련됩니다. SKILL.md를 참고하세요" | Read tool 사용 여부 |
| **direct-embed** | `<skill-guide>{SKILL.md 전체 내용}</skill-guide>` | 항상 전달 (프롬프트 포함) |

## 핵심 결과: 전달률

| Config | R1 | R2 | 평균 | 전달 보장 |
|--------|-----|-----|------|----------|
| **none** | 6/16 (37%) | 5/16 (31%) | **34%** | X |
| **tag** | 12/16 (75%) | 12/16 (75%) | **75%** | X |
| **light-embed** | 14/16 (87%) | 11/16 (68%) | **78%** | X |
| **direct-embed** | 16/16 (100%) | 16/16 (100%) | **100%** | **O** |

## 케이스별 전달 상세

### Direct (명시적 요청, 6건)

| ID | 프롬프트 | none | tag | light | embed |
|----|---------|------|-----|-------|-------|
| D02 | JPA Entity 새로 만들어줘 | OO | OO | OO | OO |
| D03 | GraphQL 스키마 추가해줘 | XX | OO | OX | OO |
| D04 | gRPC Proto 파일 정의해줘 | OO | OO | OO | OO |
| D05 | Gradle 빌드 설정 수정해줘 | XX | OO | OO | OO |
| D06 | JUnit 테스트 작성해줘 | OO | OX | OO | OO |
| D07 | 구현 계획 세워줘 | OO | OO | OO | OO |
| | **소계** | **8/12** | **11/12** | **11/12** | **12/12** |

### Natural (자연어 요청, 6건)

| ID | 프롬프트 | none | tag | light | embed |
|----|---------|------|-----|-------|-------|
| N01 | 채팅에 이미지 전송 기능 추가 | XX | OX | OO | OO |
| N02 | User 테이블 컬럼 추가 | XX | OO | OO | OO |
| N03 | 사용자 프로필 수정 API | XX | XO | OX | OO |
| N04 | 서비스 간 내부 통신 | XX | XX | OX | OO |
| N06 | 팔로우 기능 검증 | XX | XX | XX | OO |
| N08 | DynamoDB 전환 문서화 | OO | OO | OO | OO |
| | **소계** | **2/12** | **6/12** | **8/12** | **12/12** |

### Ambiguous (모호한 요청, 4건)

| ID | 프롬프트 | none | tag | light | embed |
|----|---------|------|-----|-------|-------|
| A01 | 새 API endpoint 만들어줘 | XX | OO | OO | OO |
| A02 | 데이터 모델 설계해줘 | XX | OO | OO | OO |
| A04 | notification 모듈 새 기능 | OX | XO | XX | OO |
| A05 | 빌드가 깨졌어 고쳐줘 | XX | OO | OO | OO |
| | **소계** | **1/8** | **7/8** | **6/8** | **8/8** |

> O = R1 또는 R2에서 전달 성공, X = 실패. 좌=R1, 우=R2

### Negative (스킬 불필요, 4건)

전 config, 전 라운드 false positive 0.

## 카테고리별 전달률 (R1+R2 합산)

| Category | none | tag | light-embed | direct-embed |
|----------|------|-----|-------------|-------------|
| direct (12) | 67% | 92% | 92% | **100%** |
| natural (12) | 17% | 50% | 67% | **100%** |
| ambiguous (8) | 12% | 88% | 75% | **100%** |
| negative (8) | FP 0 | FP 0 | FP 0 | FP 0 |

## 안정성 (R1 vs R2 변동)

| Config | R1 | R2 | 변동폭 |
|--------|-----|-----|--------|
| none | 37% | 31% | -6%p |
| tag | 75% | 75% | **0%p** |
| light-embed | 87% | 68% | **-19%p** |
| direct-embed | 100% | 100% | **0%p** |

- **direct-embed**: 2라운드 모두 100% — 완벽한 안정성
- **tag**: 2라운드 모두 75% — 안정적
- **light-embed**: R1 87% → R2 68% — 불안정 (Read 호출 여부가 비결정적)
- **none**: 31~37% — 낮고 불안정

## 핵심 발견

1. **전달률은 정보량에 비례**: none(34%) → tag(75%) → light-embed(78%) → direct-embed(100%)
2. **direct-embed만 100% 보장**: 2라운드 모두 16/16, 변동 0
3. **light-embed는 불안정**: R1 87% vs R2 68% (19%p 차이) — Read 호출이 비결정적
4. **tag는 의외로 안정적**: 2라운드 모두 75%, ambiguous에서 88%
5. **N06(팔로우 검증)만 전 config 실패**: direct-embed 제외 전부 미전달 — 가장 어려운 케이스

## 결론

서브에이전트에 스킬을 **확실하게** 전달하려면 `direct-embed`가 유일한 방법.

## 파일 구조

```
results-embed/20260225-232711/
├── summary.md              ← 이 파일
├── {config}-r1.csv         ← R1 결과 (none, tag, light-embed, direct-embed)
├── {config}-r2.csv         ← R2 결과
└── raw/{config}/{id}-prompt.txt  ← 실제 전달된 프롬프트
```
