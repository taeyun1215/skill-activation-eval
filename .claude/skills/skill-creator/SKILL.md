---
name: skill-creator
description: "새로운 스킬을 생성하는 메타스킬"
---

# Skill Creator

## 설명

새로운 Claude Code 스킬을 `.claude/skills/` 디렉토리에 생성한다.

## 실행 절차

### 1. 스킬 디렉토리 생성

```
.claude/skills/{skill-name}/SKILL.md
```

### 2. SKILL.md 템플릿

```markdown
---
name: {skill-name}
description: "{한 줄 설명}"
---

# {Skill Title}

## 설명

이 스킬이 무엇을 하는지 설명한다.

## 실행 절차

### 1. [첫 번째 단계]
설명 및 코드 예시

### 2. [두 번째 단계]
설명 및 코드 예시

### 3. [검증]
```bash
# 확인 명령어
./gradlew :module:compileKotlin
```

## 주의사항
- 주의할 점 나열
```

### 3. 체크리스트

- [ ] `name`이 디렉토리명과 일치하는가?
- [ ] `description`이 한 줄로 명확한가?
- [ ] 실행 절차가 단계별로 구체적인가?
- [ ] 코드 예시가 프로젝트 컨벤션을 따르는가?
- [ ] 검증 방법이 포함되어 있는가?

### 4. 참고 자료 (선택)

상세 문서가 필요한 경우:
```
.claude/skills/{skill-name}/
├── SKILL.md
└── references/
    └── detailed-guide.md
```

## 네이밍 규칙

- 디렉토리: `kebab-case` (예: `entity-skill`)
- SKILL.md 내 name: 디렉토리명과 동일
- description: 따옴표로 감싸기
