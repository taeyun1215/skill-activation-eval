---
paths:
  - ".claude/skills/**/*"
---

# Skills Management Rules

## SKILL.md Format

모든 스킬은 다음 frontmatter 형식을 따른다:

```markdown
---
name: skill-name
description: "한 줄 설명"
---

# Skill Name

## 설명
...

## 실행 절차
1. ...
2. ...

## 예시
...
```

## Skill Directory Structure

```
.claude/skills/
├── {skill-name}/
│   ├── SKILL.md           # 스킬 정의 (필수)
│   └── references/        # 참고 자료 (선택)
│       └── *.md
```

## Rules

1. **하나의 스킬 = 하나의 디렉토리**: `{skill-name}/SKILL.md` 구조 유지
2. **Frontmatter 필수**: `name`, `description` 항목 반드시 포함
3. **실행 절차 포함**: 스킬은 "어떻게 실행하는가"를 단계별로 기술
4. **참고 자료 분리**: 상세 문서는 `references/` 하위에 배치
5. **새 스킬 추가**: `skill-creator` 스킬을 사용하여 생성

## Naming Convention

- 디렉토리명: `kebab-case` (예: `entity-skill`, `grpc-skill`)
- SKILL.md 내 name: 디렉토리명과 동일
