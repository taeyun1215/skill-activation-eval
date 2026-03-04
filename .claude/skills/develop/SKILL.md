---
name: develop
description: "새 기능 개발 워크플로우 가이드"
---

# Develop Skill

## 설명

새 기능을 개발할 때의 표준 워크플로우를 안내한다.

## 개발 순서

```
1. Entity 정의       → domain/.../entity/
2. Repository 작성   → domain/.../repository/
3. GraphQL Schema    → graphql/.../resources/graphql/
4. Proto 정의        → protobuf/.../proto/
5. Service 구현      → {module}/.../service/
6. gRPC Service      → {module}/.../controller/
7. GraphQL Service   → graphql/.../service/
8. GraphQL Controller → graphql/.../controller/
```

## 계층별 역할

| 계층 | 위치 | 역할 |
|------|------|------|
| GraphQL Controller | `graphql/controller/` | 요청 수신, 응답 조합, @PreAuthorize |
| GraphQL Service | `graphql/service/` | @GrpcClient로 gRPC 호출 |
| GrpcService | `{module}/controller/` | gRPC 요청 수신, Service 호출 |
| Service | `{module}/service/` | 비즈니스 로직, @Transactional |
| Repository | `domain/repository/` | DB 접근 (JPA/QueryDSL) |

## 검증

```bash
./gradlew :변경모듈:compileKotlin
./gradlew :변경모듈:test
```

## 주의사항

- GrpcService에 Repository 직접 주입 금지 (반드시 Service 경유)
- GraphQL Controller에서 Repository 접근 금지 (gRPC Service 경유)
- Proto 변경 시 `./gradlew :protobuf:build` 먼저 실행
- 상세 패턴은 `references/full-workflow.md` 참조
