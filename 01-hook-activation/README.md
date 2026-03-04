# skill-activation-eval

Claude Code 스킬 활성화 훅 4종(none, simple, forced-eval, llm-eval)을 160건 실험으로 비교한 프로젝트.

## 결과 요약

| Hook | Accuracy | 특징 |
|------|----------|------|
| none | 75% | 훅 없이 description만으로 |
| simple | 85% | 단순 지시문 |
| **forced-eval** | **100%** | 3-step commitment mechanism |
| llm-eval | 92% | Haiku 4.5 동적 사전 평가 |

> Description(프론트메터)을 "~가이드" 제목형에서 "~시 사용" 트리거 키워드형으로 바꾼 것만으로 +23~28pp 상승.

## 구조

```
├── skill-activation-plan.md    # 실험 설계 + 결과 + 분석
├── run.sh                      # 자동화 실행 스크립트
├── test-cases.json             # 테스트 케이스 20개
├── hooks/
│   ├── forced-eval.sh          # 정적 3-step 훅
│   ├── llm-eval.sh             # 동적 LLM 훅 (Haiku 4.5)
│   └── simple.sh               # 단순 지시문 훅
└── results/
    ├── v1/                     # 제목형 description 결과
    └── v2/                     # 트리거 키워드형 description 결과
```

## 실행

```bash
# 전체 (4 configs, 2 rounds)
bash run.sh --rounds 2

# 특정 config만
bash run.sh --rounds 2 --config forced-eval

# 특정 케이스 디버깅
bash run.sh --rounds 1 --id A05 --sequential
```

## 핵심 발견

1. **프론트메터가 1차 변수** — description 품질이 훅보다 중요 (v1 52% → v2 75%, 훅 없이)
2. **forced-eval 100%** — Anthropic 공식 문서의 commitment mechanism, 순차적 단계 지시 원칙에 기반
3. **llm-eval 92%** — 동적 스캔으로 스킬 추가/삭제에 유연하나 description 품질에 크게 의존

## OMC

기본 OFF (`NO_OMC=true`). 순수 Claude 동작만 측정.
