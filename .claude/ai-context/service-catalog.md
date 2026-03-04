# Service Catalog

## API Overview

- **타입**: GraphQL (NOT REST)
- **인증**: JWT (`@PreAuthorize("hasAuthority('User')")`)
- **컨텍스트**: `userId`, `remoteAddr`, `deviceLang`
- **페이지네이션**: cursor-based (`lastEvaluatedKey`)
- **배치 최적화**: `batchGetUsersByIds`, `batchGetEvaluationsByIds`, `batchGetBalloons`
- **다국어**: `deviceLang` (ko/ja/en)
- **총 오퍼레이션**: 143+ (Query 52, Mutation 91)

---

## Modules

### graphql (API Gateway, port 8080)

클라이언트 진입점. JWT 인증/인가, GraphQL Query/Mutation, gRPC 클라이언트.

| 패키지 | 역할 |
|--------|------|
| `controller/` | GraphQL 리졸버 (23개 카테고리) |
| `service/` | gRPC 클라이언트 호출 (25개 서비스) |
| `jwt/` | JWT 토큰 처리 |
| `config/` | Spring 설정 |

### user (gRPC)

사용자 등록/로그인, 프로필 관리, 팔로우/언팔로우, 신분증 인증, 차단/신고.

**GraphQL API** (`UserController.kt`):
- Query: `hasReportOrBlock`, `nowUsers`, `nearExposure`, `nearFriends`
- Mutation: `addFollow`, `deleteFollow`, `deleteUser`, `logout`, `toggleNearExposure`, `createReport`

**gRPC** (`user.proto` → `UserService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `GetUserInfo` | `BasicRequest` → `GetUserInfoResponse` | 사용자 정보 조회 |
| `GetUserInfoListByIds` | `UserIdsRequest` → `GetUserInfoListByIdsResponse` | 복수 사용자 조회 |
| `CreateProfileImage` | `CreateProfileImageRequest` → `ProfileImageResponse` | 프로필 이미지 생성 |
| `UpdateGender` | `UpdateGenderRequest` → `UpdateGenderResponse` | 성별 업데이트 |
| `HasReportOrBlock` | `HasReportOrBlockRequest` → `HasReportOrBlockResponse` | 신고/차단 여부 |
| `GetScamMonitoringUsers` | `GetScamMonitoringUsersRequest` → `GetScamMonitoringUsersResponse` | 스캠 의심 사용자 |

### profile (GraphQL only)

**GraphQL API** (`ProfileController.kt`):
- Query: `getUserProfile`, `latLngByIp`, `profileVisitors`
- Mutation: `updateGeolocation`, `updateGender`, `addProfileImage`, `updateProfileImage`, `updateProfileImageIsRepr`, `deleteProfileImage`, `updateProfileInterests`, `updateProfileCompany`, `updateProfileSchool`, `updateBirthday`, `updateJob`, `updateIntroduction`, `updateNickname`, `updateUserCache`, `updateUserListCache`, `updateProfileLanguageTags`, `updateProfileLanguagePreferences`

### call (gRPC)

통화 기록 저장, 통화 평가, 친구 목록, 매칭 상태, 스캠 감지.

**GraphQL API** (`CallController.kt`):
- Query: `checkCallTutorial`, `callReview`, `totalRecentCalls`
- Mutation: `addCallTutorial`, `addCallReview`

**gRPC** (`call.proto` → `CallService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `CreateCallTutorial` | `BasicRequest` → `EmptyResponse` | 통화 튜토리얼 완료 |
| `CreateCallReview` | `CreateCallReviewRequest` → `EmptyResponse` | 통화 평가 생성 |
| `GetCallReview` | `GetCallReviewRequest` → `GetCallReviewResponse` | 통화 평가 조회 |
| `TotalRecentCallsByDays` | `TotalRecentCallsByDaysRequest` → `TotalRecentCallsByDaysResponse` | 최근 통화 수 |
| `GetScamUserIdsByCall` | `GetScamUserIdsByCallRequest` → `GetScamUserIdsByCallResponse` | 스캠 사용자 조회 |

### chat (gRPC)

채팅방 관리, 메시지 저장 (DynamoDB), 메시지 번역 (AWS Translate), 금지어 필터링.

**GraphQL API** (`ChatController.kt`):
- Query: `chatRooms`, `translateMessage`, `banWords`
- Mutation: `translateChatText`, `deleteChatRoom`, `deleteChatRoomList`, `deleteAllChatRoom`

**gRPC** (`chat.proto` → `ChatService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `GetChatRooms` | `GetChatRoomsRequest` → `GetChatRoomsResponse` | 채팅방 목록 |
| `TranslateMessage` | `TranslateMessageRequest` → `TranslateMessageResponse` | 메시지 번역 |

### feed (gRPC)

Moment/Post CRUD, 댓글/답글, 해시태그, 좋아요.

**GraphQL API — Moment** (`MomentController.kt`):
- Query: `moments`, `momentById`, `momentComments`, `momentReplies`, `allowsWriteMoment`, `momentCategories`, `myMoments`
- Mutation: `addMoment`, `deleteMoment`, `addMomentComment`, `deleteMomentComment`, `addMomentReply`, `deleteMomentReply`, `addMomentReport`, `addCommentReport`, `addReplyReport`, `addMomentTranslate`

**GraphQL API — Post** (`PostController.kt`):
- Query: `post`, `latestPosts`, `postLikes`, `postHashTags`
- Mutation: `addPost`, `deletePost`, `addPostLike`, `deletePostLike`, `addPostReport`

**gRPC** (`moment.proto` → `MomentService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `CreateMoment` | `CreateMomentRequest` → `CreateMomentResponse` | 모먼트 생성 |
| `ListMoments` | `ListMomentsRequest` → `ListMomentsResponse` | 모먼트 목록 |
| `GetMomentById` | `GetMomentByIdRequest` → `GetMomentByIdResponse` | 모먼트 상세 |
| `CreateMomentComment` | `CreateMomentCommentRequest` → `CreateMomentCommentResponse` | 댓글 생성 |
| `GetMomentComments` | `GetMomentCommentsRequest` → `GetMomentCommentsResponse` | 댓글 조회 |
| `CreateMomentReport` | `CreateMomentReportRequest` → `EmptyResponse` | 모먼트 신고 |

### notification (gRPC)

FCM 푸시 알림, 활동 피드, 알림 설정. 외부: Firebase FCM.

**GraphQL API** (`NotificationController.kt`):
- Query: `activities`
- Mutation: `deleteActivity`

**gRPC** (`notification.proto` → `NotificationService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `SendPushNotification` | `SendPushNotificationRequest` → `EmptyResponse` | 푸시 전송 |
| `CreateActivity` | `CreateActivityRequest` → `EmptyResponse` | 활동 생성 |
| `GetActivities` | `GetActivitiesRequest` → `GetActivitiesResponse` | 활동 목록 |

### product (gRPC)

상품 관리, 풍선 시스템, 구독, 일일 미션, 결제. 외부: Google Play, Apple IAP, Toss Payments.

**GraphQL API** (`ProductController.kt`):
- Query: `dailyMissions`, `dailyMissionsV2`, `checkFirstCallBalloon`, `callNudgeMissions`, `hasReviewBalloon`, `hasWebVisitBalloon`, `checkWebPaymentAvailable`, `firstWebPaymentAvailable`, `currentSubscriptions`
- Mutation: `purchaseBalloons`, `useBalloon`, `addMissionBalloons`, `addFirstCallBalloon`, `addCallNudgeMission`, `addCallNudgeMissionBalloon`, `purchaseSubscription`, `restoreSubscription`, `failSubscription`, `createOfferToken`, `addStoreErrorLog`

**gRPC** (`product.proto` → `ProductService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `GetDailyMissions` | `GetDailyMissionsRequest` → `GetDailyMissionsResponse` | 일일 미션 |
| `PurchaseBalloons` | `PurchaseBalloonsRequest` → `PurchaseBalloonsResponse` | 풍선 구매 |
| `UseBalloon` | `UseBalloonRequest` → `UseBalloonResponse` | 풍선 사용 |
| `GetCurrentSubscriptions` | `GetCurrentSubscriptionsRequest` → `GetCurrentSubscriptionsResponse` | 구독 조회 |
| `HasRecentPayment` | `HasRecentPaymentRequest` → `BooleanResponse` | N일 내 결제 이력 여부 |

### tracking (gRPC)

이벤트 추적, 온보딩 분석, A/B 테스트.

**gRPC** (`tracking.proto` → `TrackingService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `TrackEvent` | `TrackEventRequest` → `EmptyResponse` | 이벤트 추적 |
| `TrackOnboarding` | `TrackOnboardingRequest` → `EmptyResponse` | 온보딩 추적 |

### adreward (gRPC)

광고 시청 보상, SSV 검증. 외부: Tapjoy, Edison, AdPopcorn.

**gRPC** (`adReward.proto` → `AdRewardService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `RewardUser` | `RewardUserRequest` → `RewardUserResponse` | 광고 보상 지급 |

### scheduler (배치, port 8080)

만료 풍선 알림, 신고 취소, 친구 초기화, 정기 보상.

### grouptalk (WebSocket + gRPC, port 8080)

Socket.IO 실시간 통신, 그룹 채팅방, 디스커버리.

**gRPC** (`discovery.proto` → `DiscoveryService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `GetDiscoveryUsers` | `GetDiscoveryUsersRequest` → `GetDiscoveryUsersResponse` | 온라인 유저 리스트 조회 |
| `RequestDiscoveryCall` | `RequestDiscoveryCallRequest` → `RequestDiscoveryCallResponse` | 통화/채팅 요청 |
| `RespondDiscoveryCall` | `RespondDiscoveryCallRequest` → `RespondDiscoveryCallResponse` | 요청 수락/거절 |
| `CancelDiscoveryCall` | `CancelDiscoveryCallRequest` → `CancelDiscoveryCallResponse` | 매칭 요청 취소 |
| `HasDailyRandomChatLimits` | `HasDailyRandomChatLimitsRequest` → `HasDailyRandomChatLimitsResponse` | 여성 일일 랜덤채팅 리밋 체크 |

**gRPC 의존**: `product-grpc` (60일 내 구매 확인), `chat-legacy-grpc` (채팅방 생성)

### auth (GraphQL only, public)

**GraphQL API** (`AuthController.kt`) — `@PreAuthorize` 없음:
- Query: `getNickname`
- Mutation: `loginSns`, `testLogin`, `webLogin`, `generateShortLivedToken`

### promotion (GraphQL only)

**GraphQL API** (`PromotionController.kt`):
- Query: `promotionInfo`
- Mutation: `syncSeasonalStreakChallenge`, `syncChristmasChallenge`

### slack (gRPC)

**gRPC** (`slack.proto` → `SlackService`):
| Method | Request → Response | 설명 |
|--------|-------------------|------|
| `SendMessage` | `SendMessageRequest` → `EmptyResponse` | Slack 메시지 전송 |

### domain (Library)

JPA 엔티티 (113개), Repository, 공통 유틸리티.

### protobuf (Library)

Proto 파일 정의, gRPC Stub 생성.

---

## Common Messages

| Message | Fields |
|---------|--------|
| `BasicRequest` | `user_id: string` |
| `EmptyRequest` | (없음) |
| `EmptyResponse` | (없음) |
| `BooleanResponse` | `result: bool` |
| `UserIdsRequest` | `user_id: repeated string` |
| `User` | `id`, `image`, `index`, `nick_type`, `nickname` |

## Enums

| Enum | Values |
|------|--------|
| `BanType` | UNSPECIFIED, NORMAL, WARNING, TEMPORARY, TEMPORARY_UNLOCKING, PERMANENT, PERMANENT_UNLOCKING |
| `GenderType` | UNSPECIFIED, FEMALE, MALE |
| `InterestCategory` | ENTERTAINMENTS, HOBBIES, CHARACTER, LIFESTYLE, ART_BEAUTY, FOOD, SPORTS, WELL_BEING, INVESTMENT, CAREER, MBTI |

## Common Patterns

| 패턴 | 설명 |
|------|------|
| Soft Delete | `isDel` 플래그, `deletedAt` 타임스탬프 |
| Abuse Check | `findAbuseUser`, `readReportedTypes`, `checkHasReward` |
| Rewards | 많은 Mutation 응답에 `has_reward` 필드 |
| Notifications | 소셜 액션(follow, like, post) 시 자동 활동 생성 + 푸시 전송 |
| Monitoring | Slack 웹훅으로 중요 이벤트 알림 |

## External APIs

| 서비스 | 용도 |
|--------|------|
| Slack | 모니터링 (게시물, 신고, 결제) |
| Google Sheets | 온보딩 설문 데이터 |
| AdMob | 광고 보상 SSV 검증 |
| Toss Payments | 웹 결제 처리 |
| AWS Translate | 채팅/모먼트 번역 |
| Geolocation | IP → 위도/경도 변환 |
| NICE API | 한국 본인 인증 |

## Module Dependencies

```
graphql → user, call, chat, feed, notification, product, tracking, adreward, slack, grouptalk(discovery)
user, call, chat, feed, notification, product, tracking, adreward → domain
scheduler → domain, graphql-client
grouptalk → product(gRPC), chat-legacy(gRPC)
```
