---
description: "PR 자동 생성 — 변경 분석, 빌드 확인, GitHub PR 생성"
allowed-tools: ["Bash", "Read", "Glob", "Grep"]
argument-hint: "base branch (default: master)"
---

# PR 생성 워크플로우

## 절차

1. **변경 분석**
   - `git diff $ARGUMENTS...HEAD` 로 전체 변경 확인 (base branch 기본값: master)
   - 변경된 모듈 식별
   - 커밋 히스토리 확인: `git log $ARGUMENTS..HEAD --oneline`

2. **빌드 확인**
   - 변경된 모듈 컴파일: `./gradlew :변경모듈:compileKotlin`
   - 테스트 실행: `./gradlew :변경모듈:test`
   - 실패 시 수정 후 재시도

3. **PR 생성**
   - 브랜치명에서 이슈 번호 추출 (예: `app-backend-540` → `#540`)
   - 변경 분석 기반으로 PR 제목/본문 작성
   - `gh pr create` 로 PR 생성

## PR 본문 형식

```markdown
## Summary
- 변경 요약 (1-3줄)

## Change Type
- [ ] 구조 변경 (리팩터링, 파일 이동)
- [ ] 행동 변경 (새 기능, 버그 수정)
- [ ] 설정 변경 (config, 의존성)
- [ ] 문서 변경

## Changes
- 상세 변경 내역

## How to Test
1. 테스트 방법 단계별 기술

## Checklist
- [ ] `./gradlew clean build` 성공
- [ ] 테스트 추가/수정
- [ ] Proto 변경 시 하위 호환성 확인
```
