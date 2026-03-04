---
paths:
  - "build.gradle.kts"
  - "**/build.gradle.kts"
  - "settings.gradle.kts"
  - "gradle.properties"
---

# Project Structure — Gradle Multi-Module

## Module Overview

```
maum-app-backend-mono/
├── graphql/          # GraphQL API Gateway (port 8080)
├── user/             # 사용자/프로필/인증 (gRPC)
├── call/             # 음성 통화/평가/매칭 (gRPC)
├── chat/             # 채팅/메시지/번역 (gRPC)
├── feed/             # Moment/Post 피드 (gRPC)
├── notification/     # FCM 푸시/활동 피드 (gRPC)
├── product/          # 상품/결제/구독 (gRPC)
├── tracking/         # 분석/A/B 테스트 (gRPC)
├── adreward/         # 광고 보상 (gRPC)
├── scheduler/        # 배치 작업 (port 8080)
├── grouptalk/        # WebSocket 그룹채팅 (port 8080)
├── domain/           # 공유 엔티티/레포지토리 (Library)
└── protobuf/         # gRPC Proto 정의 (Library)
```

## Module Dependencies

```
graphql  ──→  protobuf (gRPC stubs)
graphql  ──→  domain   (공유 DTO)

user/call/chat/...  ──→  domain    (Entity, Repository)
user/call/chat/...  ──→  protobuf  (gRPC service base)

domain     ──→  (독립, JPA 엔티티만)
protobuf   ──→  (독립, Proto 파일만)
```

## Database Catalogs

| Catalog | 용도 | 주요 테이블 |
|---------|------|------------|
| `maum` | 메인 | user, profile, call, product, follow |
| `moment` | 피드 | post, moment, comment, like |
| `chat` | 채팅 | chat_room, (DynamoDB: messages) |
| `notification` | 알림 | notification, notification_setting |

## Key Directories per Module

```
{module}/src/main/kotlin/com/maum/backend/
├── controller/    # GrpcService (gRPC 서버) 또는 GraphQL Controller
├── service/       # 비즈니스 로직
├── config/        # 모듈별 설정
└── dto/           # 입출력 DTO

domain/src/main/kotlin/com/maum/backend/
├── entity/        # JPA Entity (@Entity)
└── repository/    # JPA Repository

protobuf/src/main/proto/
├── common.proto   # 공통 메시지
├── user/          # 사용자 서비스 Proto
├── call/          # 통화 서비스 Proto
└── ...
```

## Adding a New Module

1. `settings.gradle.kts`에 `include("module-name")` 추가
2. `module-name/build.gradle.kts` 생성
3. `domain`, `protobuf` 의존성 설정
4. `application.yml` 설정 (local, stg, prod)
