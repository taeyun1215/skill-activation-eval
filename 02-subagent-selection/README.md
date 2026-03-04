# 02-subagent-selection

> 어떤 설정을 써야, 메인 에이전트가 올바른 서브에이전트를 선택하는가?

## 배경

01 실험에서 hook으로 메인 에이전트의 Skill() 호출을 100% 유도할 수 있음을 확인했다. 하지만 실제 프로젝트에서는 메인 에이전트가 직접 코드를 쓰지 않고 **서브에이전트(`.claude/agents/`)에 위임**한다. hook은 서브에이전트에 전파되지 않으므로, 메인 에이전트가 **올바른 서브에이전트를 선택하는 것**이 핵심 병목이다.

## 정확도 추이

```
v1 위임 지시 강도       50%  ████████████████████
v2 에이전트 설명 수준    62%  █████████████████████████
v3 디스크립션 교차참조   72%  █████████████████████████████
v4 hook 기반 강제 평가     82%  █████████████████████████████████
v5 Step 0 요청 분류      87%  ███████████████████████████████████
```

| 버전 | 핵심 변경 | 정확도 | 핵심 인사이트 |
|------|----------|--------|-------------|
| v1 | 위임 지시 강도 | 50% | 강도는 무의미. 설명이 없어서 못 고름 |
| v2 | `.claude/CLAUDE.md`에 설명 추가 | 62% | detailed가 최고. 하지만 description이 더 중요 |
| v3 | `.claude/agents/*.md` 교차참조 | 72% | description 프론트매터가 핵심 변수 |
| v4 | hook으로 강제 평가 | 82% | 사고 강제 > 정답 알려주기 |
| v5 | Step 0 요청 분류 | 87% | 분류 먼저, 평가 나중. natural 94% |

## 실행

```bash
# v1 — 위임 지시 강도 (4 configs × 16건)
bash runv1.sh --dry-run                           # CLAUDE.md 미리보기
bash runv1.sh --id D02 --config must --rounds 1   # 단건
bash runv1.sh --rounds 1                          # 전체

# v2 — 에이전트 설명 수준 (4 configs × 16건)
bash runv2.sh --dry-run
bash runv2.sh --id D02 --config detailed          # 단건
bash runv2.sh --rounds 1                          # 전체

# v3 — runv2.sh 재사용 (에이전트 .md만 변경)
# 에이전트 .md의 description 프론트매터를 수정한 뒤 runv2.sh 실행

# v4 — hook 전략 비교 (4 configs × 20건 × 2R)
bash runv4.sh --dry-run
bash runv4.sh --id D02 --config forced-eval       # 단건
bash runv4.sh --rounds 2                          # 전체

# v5 — Step 0 요청 분류 (1 config × 20건 × 2R)
bash runv5.sh --dry-run
bash runv5.sh --id N03 --config forced-eval-v5    # 단건
bash runv5.sh --rounds 2                          # 전체
```

> **runv3.sh가 없는 이유**: v3는 독립변수가 "에이전트 .md의 description 프론트매터"이므로, 실행 스크립트는 v2와 동일(runv2.sh). `.claude/agents/*.md` 파일만 교차참조 버전으로 교체한 뒤 runv2.sh를 다시 돌렸다.

## 구조

```
02-subagent-selection/
├── README.md              ← 이 파일
├── PLAN.md                ← 상세 실험 설계 및 내러티브
├── test-cases.json        ← 테스트 프롬프트 (v1-v3: 16건, v4-v5: 20건)
├── hooks/                 ← UserPromptSubmit hook 스크립트
│   ├── simple.sh
│   ├── forced-eval.sh
│   ├── forced-eval-v5.sh  ← Step 0 추가 버전
│   ├── llm-eval.sh
│   └── llm-eval-haiku.sh
├── runv1.sh               ← v1 실행 (위임 지시 강도)
├── runv2.sh               ← v2/v3 실행 (에이전트 설명 수준)
├── runv4.sh               ← v4 실행 (hook 전략 비교)
├── runv5.sh               ← v5 실행 (Step 0 요청 분류)
└── results/
    ├── v1/                ← 16건 × 4 configs × 1R + summary.md
    ├── v2/                ← 16건 × 4 configs × 1R + summary.md
    ├── v3/                ← 16건 × 4 configs × 2R + summary.md
    ├── v4/                ← 20건 × 4 configs × 2R + summary.md
    └── v5/                ← 20건 × 1 config × 2R + summary.md
```

## 핵심 결론

1. **`.claude/agents/{name}.md`의 description 프론트매터를 잘 쓴다** — 교차참조 포함 (+13%p)
2. **`.claude/settings.json`에 hook으로 구조화된 평가를 강제한다** — Step 0 분류 + 채점 (+12%p)
3. **`.claude/CLAUDE.md` 설명은 최소한으로** — name-only면 충분
4. **LLM 추천보다 자체 사고 강제가 낫다** — 정답을 알려줘도 무시함
5. **ambiguous 요청은 50%가 한계** — 다른 접근 필요
