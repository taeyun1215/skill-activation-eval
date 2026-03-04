---
paths:
  - "**/*"
---

# Development Environment

## Build Commands

```bash
# 전체 빌드 (테스트 제외)
./gradlew clean build -x test

# 특정 모듈 빌드
./gradlew :graphql:build -x test
./gradlew :user:build -x test
./gradlew :call:build -x test

# Proto 컴파일
./gradlew :protobuf:build
```

## Test Commands

```bash
# 전체 테스트
./gradlew test

# 특정 모듈 테스트
./gradlew :user:test

# 특정 테스트 클래스
./gradlew :user:test --tests "com.maum.backend.service.UserServiceTest"
```

## Verification Checklist

변경 후 반드시 확인:
1. `./gradlew :변경모듈:compileKotlin` — 컴파일 성공
2. `./gradlew :변경모듈:test` — 테스트 통과
3. Proto 변경 시: `./gradlew :protobuf:build` 먼저 실행

## Local Run

```bash
# GraphQL Gateway
./gradlew :graphql:bootRun

# 특정 마이크로서비스
./gradlew :user:bootRun
./gradlew :call:bootRun
```

## Troubleshooting

- **Proto import 오류**: `./gradlew :protobuf:clean :protobuf:build` 후 재빌드
- **Entity 변경 반영 안됨**: `./gradlew :domain:clean :domain:build`
- **gRPC stub 없음**: `./gradlew :protobuf:build` 후 IDE 새로고침
