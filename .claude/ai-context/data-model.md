# Data Model

## Database Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MySQL 8.0.28                                    │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────────────┤
│    maum     │    call     │    chat     │   moment    │    notification     │
│  (메인 DB)   │  (통화 DB)   │  (채팅 DB)   │ (모먼트 DB)  │     (알림 DB)        │
├─────────────┼─────────────┼─────────────┼─────────────┼─────────────────────┤
│   account   │   tracking  │  adreward   │             │                     │
│  (계정 DB)   │  (추적 DB)   │  (광고보상)  │             │                     │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────────────┘
```

---

## 1. User & Profile (maum, account)

### ERD
```
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│   maum.user      │       │  maum.profile    │       │ maum.profile_    │
│──────────────────│  1:1  │──────────────────│  1:N  │     image        │
│ uuid (PK)        │◄─────►│ user_id (PK,FK)  │◄─────►│──────────────────│
│ email            │       │ nickname         │       │ id (PK)          │
│ password         │       │ gender           │       │ user_id (FK)     │
│ status           │       │ birthday         │       │ image            │
│ language         │       │ latitude         │       │ is_repr          │
│ is_del           │       │ longitude        │       │ ordering         │
│ date_joined      │       │ country_code     │       └──────────────────┘
└──────────────────┘       │ index            │
                           └──────────────────┘
                                   │ 1:N
                    ┌──────────────┴──────────────┐
                    ▼                              ▼
        ┌──────────────────┐           ┌──────────────────┐
        │ maum.profile_    │           │ maum.profile_    │
        │  interest_tag    │           │  language_tag    │
        │──────────────────│           │──────────────────│
        │ id (PK)          │           │ id (PK)          │
        │ user_id (FK)     │           │ user_id (FK)     │
        │ interest_tag_id  │           │ language_tag_id  │
        └──────────────────┘           │ priority         │
                │                      └──────────────────┘
                ▼ N:1                          │
        ┌──────────────────┐                   ▼ N:1
        │ maum.interest_   │           ┌──────────────────┐
        │      tag         │           │ maum.language_   │
        │──────────────────│           │      tag         │
        │ id (PK)          │           │──────────────────│
        │ ko/en/ja         │           │ code (PK)        │
        │ category         │           │ name             │
        │ emoji            │           └──────────────────┘
        └──────────────────┘
```

### maum.user
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| uuid | VARCHAR(50) | PK | UUID |
| email | VARCHAR(255) | IDX | 이메일 |
| password | VARCHAR(128) | | 비밀번호 |
| last_login | DATETIME(3) | | 마지막 로그인 |
| last_device_id | VARCHAR(150) | IDX | 마지막 디바이스 |
| is_staff | TINYINT(1) | | 스태프 여부 |
| is_del | TINYINT(1) | IDX | 삭제 여부 |
| deleted_at | DATETIME(3) | | 삭제 시간 |
| date_joined | DATETIME(3) | | 가입일 |
| language | VARCHAR(10) | | 언어 (ko/en/ja) |
| os | VARCHAR(7) | | OS (ios/android) |
| status | VARCHAR(20) | | 상태 (NORMAL/BANNED) |
| status_date | DATETIME(3) | | 상태 변경일 |
| login_status | VARCHAR(10) | | 로그인 상태 (ON/OFF) |
| is_member | TINYINT(1) | | 멤버 여부 |
| version | VARCHAR(10) | | 앱 버전 |

### maum.profile
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| user_id | VARCHAR(50) | PK,FK | user.uuid 참조 |
| phone_code | VARCHAR(10) | | 국가 전화코드 |
| phone_number | VARCHAR(300) | IDX | 전화번호 (암호화) |
| nickname | VARCHAR(100) | IDX | 닉네임 |
| self_introduction | VARCHAR(300) | | 자기소개 |
| country | VARCHAR(100) | | 국가명 |
| country_code | VARCHAR(5) | | 국가코드 (KR/JP/US) |
| city | VARCHAR(100) | | 도시명 |
| latitude | DECIMAL(16,13) | IDX | 위도 |
| longitude | DECIMAL(16,13) | IDX | 경도 |
| gender | CHAR(1) | | 성별 (m/f) |
| birthday | DATETIME(3) | | 생년월일 |
| index | BIGINT | UQ | 고유 인덱스 (자동증가) |
| nick_type | VARCHAR(20) | | 닉네임 타입 (dog/cat) |
| timezone | VARCHAR(100) | | 타임존 |
| job | VARCHAR(50) | | 직업 |
| company | VARCHAR(50) | | 회사 |
| school | VARCHAR(50) | | 학교 |

### account.sns_login
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | VARCHAR(44) | PK | SNS 고유 ID |
| user_id | VARCHAR(36) | FK | user.uuid |
| type | VARCHAR(20) | | APPLE/GOOGLE/KAKAO/LINE |
| email | VARCHAR(255) | | SNS 이메일 |
| created_at | DATETIME(3) | | 생성일 |

### account.personal_auth (본인인증)
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | INT | PK | AUTO_INCREMENT |
| user_id | VARCHAR(36) | | user.uuid |
| name | VARCHAR(100) | | 실명 |
| birthdate | VARCHAR(8) | | 생년월일 (YYYYMMDD) |
| gender | VARCHAR(1) | | 성별 |
| di | VARCHAR(255) | | 중복가입확인정보 |
| mobile_no | VARCHAR(20) | | 휴대폰번호 |
| created_at | DATETIME(3) | | 인증일 |

---

## 2. Call (call)

### ERD
```
┌──────────────────┐       ┌──────────────────┐
│   call.call      │       │ call.call_       │
│──────────────────│  1:N  │   evaluation     │
│ id (PK)          │◄─────►│──────────────────│
│ call_type        │       │ id (PK)          │
│ members (JSON)   │       │ room_id (FK)     │
│ created_at       │       │ evaluator_id     │
│ connected_at     │       │ evaluatee_id     │
│ closed_at        │       │ score            │
└──────────────────┘       └──────────────────┘

┌──────────────────┐       ┌──────────────────┐
│ call.conversation│       │   call.friend    │
│──────────────────│  1:N  │──────────────────│
│ id (PK)          │◄─────►│ id (복합PK)       │
│ user_id          │       │ conversation_id  │
│ created_at       │       │ last_call_date   │
└──────────────────┘       │ is_del           │
                           └──────────────────┘
```

### call.call
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | VARCHAR(36) | PK | UUID |
| call_type | INT | | 1:RANDOM, 2:PREVIOUS, 4:FREE_CHAT, 5:CHAT |
| members | JSON | | 참여자 user_id 배열 |
| created_at | DATETIME(3) | | 생성일 |
| connected_at | DATETIME(3) | | 연결 시간 |
| closed_at | DATETIME(3) | | 종료 시간 |

### call.call_evaluation
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | VARCHAR(50) | PK | UUID |
| room_id | VARCHAR(36) | FK | call.id |
| evaluator_id | VARCHAR(36) | | 평가자 user_id |
| evaluatee_id | VARCHAR(36) | | 피평가자 user_id |
| score | BIGINT | | 평가 점수 (비트마스크) |
| created_at | DATETIME(3) | | 평가일 |

**Score 비트마스크**: Bit0:GOOD_VOICE, Bit1:KIND, Bit2:FUN, Bit3:GOOD_LISTENER, Bit4:MORE_TALK

### call.public_ip (스캠 감지용)
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | UUID | PK | |
| user_id | VARCHAR(36) | FK | profile.user_id |
| ip | VARCHAR(45) | | 공개 IP |
| device_id | VARCHAR(150) | | 디바이스 ID |
| created_at | DATETIME(3) | | 기록일 |

---

## 3. Chat (chat)

### ERD
```
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│   chat.room      │       │ chat.room_detail │       │ chat.last_message│
│──────────────────│  1:N  │──────────────────│  1:1  │──────────────────│
│ id (PK)          │◄─────►│ id (PK)          │◄─────►│ chat_id (PK)     │
│ open_page        │       │ chat_id (FK)     │       │ writer_id        │
│ created_at       │       │ user_id          │       │ type             │
└──────────────────┘       │ talk_mate_id     │       │ details          │
                           │ exit_type        │       │ latest_at        │
                           │ payment_type     │       └──────────────────┘
                           │ unread           │
                           └──────────────────┘
```

### chat.room_detail
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | INT | PK | AUTO_INCREMENT |
| chat_id | VARCHAR(50) | FK | room.id |
| user_id | VARCHAR(36) | IDX | 사용자 |
| talk_mate_id | VARCHAR(36) | | 상대방 |
| exit_type | INT | | 0:NONE, 1:NORMAL, 2:BLOCKER, 3:BLOCKED, 4:REPORTER, 5:REPORTED |
| payment_type | INT | | 0:LEGACY, 1:NO, 2:PAYER, 3:PAYEE |
| unread | INT | | 읽지 않은 메시지 수 |

### chat.last_message
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| chat_id | VARCHAR(50) | PK | room.id |
| writer_id | VARCHAR(36) | | 작성자 |
| type | INT | | 0:TEXT, 1:GIFT, 2:HAND_WAVE, 9:IMAGE 등 |
| details | TEXT | | 메시지 내용 |
| latest_at | DATETIME(3) | | 최신 시간 |

---

## 4. Moment (moment)

### ERD
```
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│  moment.moment   │       │ moment.comment   │       │  moment.reply    │
│──────────────────│  1:N  │──────────────────│  1:N  │──────────────────│
│ id (PK)          │◄─────►│ id (PK)          │◄─────►│ id (PK)          │
│ user_id (FK)     │       │ moment_id (FK)   │       │ comment_id (FK)  │
│ category_id (FK) │       │ user_id (FK)     │       │ moment_id (FK)   │
│ content          │       │ content          │       │ user_id (FK)     │
│ report_count     │       │ report_count     │       │ content          │
│ deleted_at       │       │ deleted_at       │       │ report_count     │
└──────────────────┘       └──────────────────┘       └──────────────────┘
```

### moment.moment
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | VARCHAR(36) | PK | UUID |
| user_id | VARCHAR(36) | FK,IDX | moment.user.id |
| category_id | INT | FK | moment_category.id |
| content | VARCHAR(1000) | | 내용 |
| report_count | INT | | 신고 수 |
| deleted_at | DATETIME(3) | IDX | 삭제 시간 |
| created_at | DATETIME(3) | IDX | 생성일 |

### moment.moment_report
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | INT | PK | AUTO_INCREMENT |
| moment_id | VARCHAR(36) | FK,UQ | moment.id |
| user_id | VARCHAR(36) | FK,UQ | 신고자 |
| type | INT | | 1:SEXUAL, 2:ABUSE, 3:CONTACT, 4:SCAM, 5:SPAM |
| created_at | DATETIME(3) | | 신고일 |

---

## 5. Post (maum)

### ERD
```
┌──────────────────┐       ┌──────────────────┐
│    maum.post     │  1:N  │ maum.post_image  │
│──────────────────│◄─────►│──────────────────│
│ uuid (PK)        │       │ uuid (PK)        │
│ user_id (FK)     │       │ post_id (FK)     │
│ content          │       │ image            │
│ like             │       │ is_repr          │
│ report_count     │       │ ordering         │
│ is_del           │       └──────────────────┘
└──────────────────┘
        │ 1:N
        ├──────────────────────────┐
        ▼                          ▼
┌──────────────────┐       ┌──────────────────┐
│  maum.post_like  │       │ maum.post_hash_  │
│──────────────────│       │      tag         │
│ uuid (PK)        │       │──────────────────│
│ post_id (FK)     │       │ uuid (PK)        │
│ user_id (FK)     │       │ post_id (FK)     │
│ created_at       │       │ hash_tag_id (FK) │
└──────────────────┘       └──────────────────┘
```

### maum.post
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| uuid | VARCHAR(36) | PK | UUID |
| user_id | VARCHAR(36) | FK | user.uuid |
| content | LONGTEXT | | 내용 |
| like | INT | | 좋아요 수 |
| report_count | INT | | 신고 수 |
| is_del | TINYINT(1) | IDX | 삭제 여부 |
| created_at | DATETIME(3) | IDX | 생성일 |

---

## 6. Product & Payment (maum)

### ERD
```
┌──────────────────┐       ┌──────────────────┐
│ maum.product_    │  1:N  │  maum.product    │
│    category      │◄─────►│──────────────────│
│──────────────────│       │ uuid (PK)        │
│ code (PK)        │       │ category_id (FK) │
│ type (p/m)       │       │ user_id (FK)     │
│ ko/en/ja         │       │ count            │
└──────────────────┘       │ price            │
                           │ transaction_id   │
                           │ platform         │
                           └──────────────────┘

┌──────────────────┐       ┌──────────────────┐
│ maum.subscription│       │ maum.daily_reward│
│──────────────────│       │──────────────────│
│ id (PK)          │       │ uuid (PK)        │
│ user_id          │       │ user_id          │
│ product_id       │       │ daily_mission_   │
│ lifecycle        │       │   setting_id(FK) │
│ platform         │       └──────────────────┘
│ expired_at       │
└──────────────────┘
```

### maum.product
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| uuid | VARCHAR(36) | PK | UUID |
| category_id | VARCHAR(20) | FK | product_category.code |
| user_id | VARCHAR(36) | FK | user.uuid |
| count | INT | | 개수 |
| price | DECIMAL(8,2) | | 가격 |
| currency | VARCHAR(10) | | 통화 (KRW/JPY/USD) |
| expires_date | DATETIME(3) | | 만료일 |
| transaction_id | VARCHAR(100) | UQ | 거래 ID |
| platform | VARCHAR(10) | | ios/android/web |

### maum.product_category
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| code | VARCHAR(20) | PK | 카테고리 코드 |
| type | CHAR(1) | | p:구매, m:미션 |
| ko | VARCHAR(50) | | 한국어명 |
| en | VARCHAR(50) | | 영어명 |
| ja | VARCHAR(50) | | 일본어명 |
| is_system | TINYINT(1) | | 시스템 카테고리 |

### maum.subscription
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | VARCHAR(50) | PK | subscription_id |
| user_id | VARCHAR(50) | IDX | user.uuid |
| product_id | VARCHAR(50) | | 상품 ID |
| transaction_id | VARCHAR(50) | | orderId/transactionId |
| original_transaction_id | VARCHAR(200) | | purchaseToken/originalTransactionId |
| lifecycle | VARCHAR(20) | | SUBSCRIBE/CANCEL/EXPIRED/REFUND 등 |
| price | DECIMAL(8,2) | | 가격 |
| platform | VARCHAR(10) | | ios/android |
| started_at | DATETIME(3) | | 시작일 |
| expired_at | DATETIME(3) | | 만료일 |

---

## 7. Notification (notification)

### notification.notification
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | INT UNSIGNED | PK | AUTO_INCREMENT |
| user_id | VARCHAR(36) | UQ | user.uuid |
| token | VARCHAR(255) | IDX | FCM 토큰 |
| language | VARCHAR(10) | | 언어 |
| timezone | VARCHAR(50) | | 타임존 |
| country_code | VARCHAR(5) | IDX | 국가코드 |

### notification.activities
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | BIGINT | PK | AUTO_INCREMENT |
| user_activity | VARCHAR(36) | FK | 활동한 유저 |
| type | VARCHAR(20) | | follow/like/post/hand_wave/moment_comment 등 |
| post_id | VARCHAR(36) | | 관련 게시물 |
| created_at | DATETIME(3) | IDX | 생성일 |

---

## 8. Follow & Block (maum)

### maum.follow
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| uuid | VARCHAR(36) | PK | UUID |
| follower_id | VARCHAR(36) | FK,UQ,IDX | 팔로우 하는 사람 |
| followed_id | VARCHAR(36) | FK,UQ | 팔로우 받는 사람 |
| created_at | DATETIME(3) | | 팔로우 일시 |

### maum.block
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | VARCHAR(50) | PK | UUID |
| blocker_id | VARCHAR(36) | FK,UQ,IDX | 차단한 사람 |
| blocked_id | VARCHAR(36) | FK,UQ | 차단당한 사람 |
| is_del | TINYINT(1) | | 삭제 여부 |
| created_at | DATETIME(3) | | 차단 일시 |

---

## 9. Report (maum)

### maum.report
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | VARCHAR(50) | PK | UUID |
| reporter_id | VARCHAR(36) | FK | 신고자 |
| reported_id | VARCHAR(36) | FK | 피신고자 |
| type | INT | | 신고 유형 |
| from | LONGTEXT | | 신고 출처 |
| detail | VARCHAR(300) | | 신고 상세내용 |
| is_cancel | TINYINT(1) | | 취소 여부 |
| reported_date | DATETIME(3) | | 신고일 |
| apply_count | DECIMAL(3,1) | | 적용 카운트 |

**Report Type**: 1:ABUSE, 2:UNPLEASANT, 3:DEMAND_CONTACT, 4:SEXUAL_REMARK, 5:MISSIONARY_WORK, 6:END_CALL_WITHOUT_TALK, 7:VIOLATE_COMMUNITY_GUIDELINES, 8:FRAUD_AND_SCAMS, 9:NUDITY_OR_SEXUALLY_PHOTO, 10:INAPPROPRIATE_PHOTO, 11:INAPPROPRIATE_CONTENT, 12:FOURTEEN_UNDERAGE

---

## 10. A/B Test (tracking)

### tracking.abtest
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | INT | PK | AUTO_INCREMENT |
| test_name | VARCHAR(100) | UQ | 테스트명 |
| start_at | DATETIME(3) | | 시작일 |
| end_at | DATETIME(3) | | 종료일 |
| created_at | DATETIME(3) | | 생성일 |

---

## 11. Ad Reward (adreward)

### adreward.user_reward
| Column | Type | Key | Description |
|--------|------|-----|-------------|
| id | VARCHAR(26) | PK | ULID |
| user_id | VARCHAR(50) | UQ | user.uuid |
| variable | VARCHAR(50) | UQ | 변수명 |
| value | INT | | 값 |
| updated_at | DATETIME(3) | | 수정일 |

---

## Enum Types Summary

| Category | Enum | Values |
|----------|------|--------|
| User | BanType | NORMAL, WARNING, TEMPORARY, PERMANENT |
| User | LoginStatusType | ON, OFF |
| User | LanguageType | EN, KO, JA |
| User | SnsLoginType | APPLE, GOOGLE, KAKAO, LINE |
| Call | CallType | RANDOM(1), PREVIOUS(2), FREE_CHAT(4), CHAT(5) |
| Chat | MessageType | TEXT(0), GIFT(1), HAND_WAVE(2), IMAGE(9) |
| Chat | ChatExitType | NONE(0), NORMAL(1), BLOCKER(2), BLOCKED(3), REPORTER(4), REPORTED(5) |
| Chat | ChatPaymentType | LEGACY(0), NO(1), PAYER(2), PAYEE(3) |
| Product | ProductPlatformType | WEB, IOS, ANDROID |
| Product | LifecycleType | SUBSCRIBE(1), CANCEL(4), EXPIRED(9), REFUND(10) |
| Report | ReportType | ABUSE(1) ~ FOURTEEN_UNDERAGE(12) |
| Report | MomentReportType | SEXUAL_REMARK(1), ABUSE(2), SCAM(4), SPAM(5) |
| Notification | ActivityType | Follow, Like, Post, HandWave, MomentComment, MomentReply |

---

## Database Catalog Summary

| Catalog | Tables | Description |
|---------|--------|-------------|
| **maum** | ~30+ | 메인 (user, profile, product, post, follow, block, report) |
| **call** | ~7 | 통화 (call, evaluation, conversation, friend, public_ip) |
| **chat** | ~4 | 채팅 (room, room_detail, last_message, ban_words) |
| **moment** | ~8 | 모먼트 (moment, category, comment, reply, report) |
| **notification** | ~7 | 알림 (notification, activities, users) |
| **account** | ~3 | 계정 (personal_auth, sns_login, geolocation_log) |
| **adreward** | ~3 | 광고 보상 (user_reward, reward_history) |
| **tracking** | ~10 | 추적 (abtest, first_open) |

---

## Common Patterns

### Soft Delete
```kotlin
is_del: Boolean = false
deleted_at: LocalDateTime? = null
```

### Audit Fields
```kotlin
@CreatedDate var createdAt: LocalDateTime
@LastModifiedDate var updatedAt: LocalDateTime
```

### UUID Primary Key
```kotlin
@Id @GeneratedValue(generator = "uuid2")
@GenericGenerator(name = "uuid2", strategy = "uuid2")
val id: String = ""
```

### Multi-language
```kotlin
ko: String  // 한국어
en: String  // 영어
ja: String  // 일본어
```
