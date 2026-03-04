---
name: graphql-skill
description: "GraphQL 스키마 및 리졸버 작성 가이드"
---

# GraphQL Skill

## 설명

GraphQL 스키마 정의부터 Controller/Service 구현까지의 워크플로우를 안내한다.

## 실행 절차

### 1. Schema 정의

위치: `graphql/src/main/resources/graphql/schema.graphqls` 또는 별도 `.graphqls` 파일

```graphql
type Feature {
    id: ID!
    name: String!
    user: SimpleUser
    createdAt: String!
}

input CreateFeatureInput {
    name: String!
}

extend type Query {
    feature(featureId: ID!): Feature
    features(limit: Int, offset: Int): [Feature!]!
}

extend type Mutation {
    createFeature(input: CreateFeatureInput!): Feature!
    deleteFeature(featureId: ID!): Boolean!
}
```

### 2. GraphQL Controller

위치: `graphql/src/main/kotlin/com/maum/backend/controller/{도메인}/`

```kotlin
@Controller
class FeatureController(
    private val featureService: FeatureService,
    private val userService: UserService,
) {
    @QueryMapping
    @PreAuthorize("hasAuthority('User')")
    fun features(
        @UserId userId: String,
        @Argument limit: Int?,
        @Argument offset: Int?,
    ): List<FeatureResponse> {
        val response = featureService.getFeatures(userId, limit ?: 20, offset ?: 0)
        return response.featuresList.map { it.toResponse() }
    }

    @MutationMapping
    @PreAuthorize("hasAuthority('User')")
    fun createFeature(
        @UserId userId: String,
        @Argument input: CreateFeatureInput,
    ): FeatureResponse {
        val response = featureService.createFeature(userId, input.name)
        return response.feature.toResponse()
    }
}
```

### 3. GraphQL Service (gRPC Client)

위치: `graphql/src/main/kotlin/com/maum/backend/service/{도메인}/`

```kotlin
@Service
class FeatureService {
    @GrpcClient("feature-grpc")
    private lateinit var stub: FeatureServiceGrpc.FeatureServiceBlockingStub

    fun getFeatures(userId: String, limit: Int, offset: Int): ListFeaturesResponse {
        val request = ListFeaturesRequest.newBuilder()
            .setUserId(userId)
            .setLimit(limit)
            .setOffset(offset)
            .build()
        return try {
            stub.listFeatures(request)
        } catch (e: StatusRuntimeException) {
            throw CustomGraphQLException(e.trailers!!, e.status.description)
        }
    }
}
```

### 4. 다중 서비스 어그리게이션

```kotlin
@QueryMapping
fun featureWithUser(
    @UserId userId: String,
    @Argument featureId: String,
): FeatureDetailResponse {
    // 여러 gRPC 서비스 호출 후 조합
    val feature = featureService.getFeature(featureId)
    val user = userService.getUserInfo(feature.userId)
    val score = callService.getMannerScore(feature.userId)

    return FeatureDetailResponse(
        feature = feature.toResponse(),
        user = user.toSimpleUser(),
        mannerScore = score,
    )
}
```

## GraphQL 컨벤션

| 항목 | 규칙 |
|------|------|
| Query | 조회 (get, list, search) |
| Mutation | 생성/수정/삭제 |
| Type 명 | PascalCase |
| Input 명 | `{Action}{Domain}Input` |
| 인증 | `@PreAuthorize("hasAuthority('User')")` |
| 사용자 ID | `@UserId userId: String` |

## 주의사항

- Controller에서 직접 Repository 접근 금지 (반드시 gRPC Service 경유)
- 에러 처리: `CustomGraphQLException` 사용
- N+1 문제: DataLoader 패턴 활용
