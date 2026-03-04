---
paths:
  - "**/*.md"
  - "docs/**/*"
  - ".claude/**/*"
---

# Documentation Guidelines

## Documentation Types

| 문서 | 위치 | 용도 |
|------|------|------|
| CLAUDE.md (root) | `/CLAUDE.md` | 프로젝트 개요, 아키텍처 |
| CLAUDE.md (claude) | `/.claude/CLAUDE.md` | AI 행동 가이드 |
| ADR | `/docs/adr/` | 아키텍처 결정 기록 |
| Tasks | `/.claude/tasks/` | 작업 계획/추적 |
| AI Context | `/.claude/ai-context/` | AI용 프로젝트 컨텍스트 |
| Skills | `/.claude/skills/` | 재사용 가능한 워크플로우 |

## ADR (Architecture Decision Records)

### 파일명 규칙
```
docs/adr/NNNN-short-title.md
# 예: docs/adr/0001-use-grpc-for-service-communication.md
```

### ADR Template
```markdown
# NNNN. 제목

## Status
Proposed | Accepted | Deprecated | Superseded by [NNNN]

## Context
어떤 문제 상황인가?

## Decision
어떤 결정을 내렸는가?

## Consequences
이 결정의 결과는 무엇인가? (장점/단점)
```

## Task Files

```
.claude/tasks/YYYYMMDD-task-name.md
```

- Git에서 추적하지 않음 (`.gitignore`에 포함)
- 진행 중인 작업의 계획/상태 기록용

## Language

- 기술 문서: 한국어 (프로젝트 컨벤션)
- 코드 내 식별자: 영문
- 커밋 메시지: 한국어 허용
- GraphQL Schema 주석: 영문
