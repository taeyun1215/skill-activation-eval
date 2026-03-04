---
paths:
  - "**/*"
---

# Tech Specification

## Core Stack

| Category | Technology | Version |
|----------|-----------|---------|
| Language | Kotlin | 1.8.22 |
| Framework | Spring Boot | 3.1.4 |
| Java | JDK | 17 |
| Build | Gradle (Kotlin DSL) | 8.x |
| API (Client) | GraphQL (Spring for GraphQL) | — |
| API (Internal) | gRPC + Protobuf | — |

## Data

| Category | Technology | Usage |
|----------|-----------|-------|
| RDBMS | MySQL | 8.0.28 |
| Cache | Redis | 세션, 캐싱, 실시간 데이터 |
| NoSQL | DynamoDB | 채팅 메시지 |
| ORM | Spring Data JPA + Hibernate | Entity 관리 |
| Query | QueryDSL | 복잡한 쿼리 |

## Infrastructure

| Category | Technology | Usage |
|----------|-----------|-------|
| Container | Kubernetes | 오케스트레이션 |
| Push | Firebase FCM | 푸시 알림 |
| Storage | AWS S3 | 이미지/파일 |
| Translation | AWS Translate | 채팅 번역 |
| Monitoring | Prometheus + Actuator | 메트릭 |

## Testing

| Category | Technology |
|----------|-----------|
| Unit Test | JUnit 5 |
| Mocking | Mockito / MockK |
| Spring Test | @SpringBootTest, @DataJpaTest |
| API Test | GraphQL Tester |

## External Services

| Service | Provider | Usage |
|---------|----------|-------|
| Payment | Google Play, Apple IAP, Toss | 인앱 결제 |
| Identity | Argos | 신분증/지문 인증 |
| Ad Reward | Tapjoy, Edison, AdPopcorn | 광고 보상 |
| WebSocket | Spring WebSocket + STOMP | 그룹톡 |
