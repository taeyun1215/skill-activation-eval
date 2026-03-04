# Maum App Backend Mono

## Project Overview

Maum(마음)은 음성 통화 기반 소셜/데이팅 앱의 백엔드 시스템입니다.

- **언어**: Kotlin 1.8.22 / **프레임워크**: Spring Boot 3.1.4 / **Java**: 17
- **API**: GraphQL (클라이언트), gRPC (서비스 간)
- **DB**: MySQL 8.0.28, Redis, DynamoDB

```
┌─────────────────────────────────────┐
│     GraphQL API Gateway (graphql/)  │  ← 클라이언트 진입점
├─────────────────────────────────────┤
│     Microservices (gRPC 통신)       │
│  user/ call/ chat/ feed/ product/   │
│  notification/ tracking/ adreward/  │
├─────────────────────────────────────┤
│     Shared Domain (domain/)         │  ← 113개 엔티티
├─────────────────────────────────────┤
│     Protocol Buffers (protobuf/)    │  ← gRPC 정의
└─────────────────────────────────────┘
```

## Quick Commands

```bash
./gradlew clean build -x test          # 전체 빌드
./gradlew :graphql:build -x test       # 특정 모듈 빌드
./gradlew test                         # 테스트
./gradlew :graphql:bootRun             # 로컬 실행
```

## AI Guidelines

### Language
- 코드: Kotlin (영문 식별자)
- 주석/문서/커밋 메시지: 한국어 허용 (프로젝트 컨벤션)

### TDD (Red → Green → Refactor)
1. **Red**: 실패하는 테스트 먼저 작성 (JUnit5 + Mockito)
2. **Green**: 테스트를 통과하는 최소한의 코드
3. **Refactor**: 테스트 통과 상태에서 개선

### Tidy First
- **구조 변경** (리팩터링)과 **행동 변경** (기능 추가)을 별도 커밋으로 분리

### Commit Convention
```
<type>/<ticket>: <설명>
# feat, fix, refactor, test, docs, chore
# 예: feat/#540: 프로모션 푸시알림 기능 추가
```

### Agent Delegation
서브 에이전트에 Task 위임 시, 관련 스킬 파일의 **내용을 직접 포함**하여 위임:
1. 관련 스킬 파일을 Read로 읽음 (`.claude/skills/{스킬명}/SKILL.md`)
2. 스킬 내용을 Task prompt에 포함하여 위임

```
Task(prompt="""
<skill-guide>
{.claude/skills/graphql-skill/SKILL.md 내용}
</skill-guide>

Discovery Proto/GraphQL 스키마를 분석해줘...
""")
```

스킬 목록: `develop`, `entity-skill`, `graphql-skill`, `grpc-skill`, `gradle-skill`, `test-skill`, `plan-skill`, `adr-skill`

## Context Files

상세 정보는 `.claude/ai-context/` 참조:
- `data-model.md` — ERD, 테이블 스키마, Enum 타입
- `service-catalog.md` — 모듈 역할, GraphQL API, gRPC 메서드
- `policies.md` — 비즈니스 정책 (신고, 회원, 통화, 결제, 푸시)
