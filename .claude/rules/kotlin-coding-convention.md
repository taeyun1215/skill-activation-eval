---
paths:
  - "**/*.kt"
---

# Kotlin Coding Convention

## Naming

| 대상 | 패턴 | 예시 |
|------|------|------|
| Entity | `XxxEntity` (또는 도메인명) | `ProfileEntity`, `Post` |
| Repository | `XxxRepository` | `ProfileRepository` |
| Service | `XxxService` | `UserService` |
| GraphQL Controller | `XxxController` | `UserController` |
| gRPC Service | `XxxGrpcService` | `UserGrpcService` |
| DTO | `XxxDto`, `XxxInput` | `UserDto`, `CreatePostInput` |

## Kotlin Idioms

### Null Safety
```kotlin
// Good: Elvis operator
val profile = profileRepository.findByUserId(userId)
    ?: throw NotFoundException("Profile not found")

// Good: safe call chain
val nickname = user?.profile?.nickname ?: "Unknown"

// Bad: !! 사용 금지 (테스트 제외)
val name = user!!.name
```

### Data Class
```kotlin
// DTO는 data class 사용
data class UserDto(
    val id: String,
    val nickname: String,
    val age: Int,
)

// Entity는 일반 class (JPA 호환성)
@Entity
class UserEntity(
    @Id val id: String = "",
    var nickname: String,
)
```

### Extension Function
```kotlin
// Entity → Proto 변환
fun UserEntity.toProto(): UserProto = UserProto.newBuilder()
    .setId(id)
    .setNickname(nickname)
    .build()

// Entity → DTO 변환
fun UserEntity.toDto() = UserDto(
    id = id,
    nickname = nickname,
    age = calculateAge(birthday),
)
```

### Scope Functions
```kotlin
// apply: 객체 초기화
val response = GetUsersResponse.newBuilder().apply {
    addAllUsers(users.map { it.toProto() })
}.build()

// let: null 체크 후 변환
val dto = entity?.let { it.toDto() }

// also: 부수 효과 (로깅 등)
return result.also { log.info("Result: $it") }
```

## Spring Patterns

### Service Layer
```kotlin
@Service
class FeatureService(
    private val repository: FeatureRepository,  // 생성자 주입
) {
    @Transactional
    fun create(input: CreateInput): Entity {
        // 비즈니스 로직
    }

    @Transactional(readOnly = true)
    fun findById(id: String): Entity {
        return repository.findById(id)
            .orElseThrow { NotFoundException("Not found: $id") }
    }
}
```

### gRPC Service
```kotlin
@GrpcService
class FeatureGrpcService(
    private val service: FeatureService,  // Service 주입 (Repository 아님!)
) : FeatureServiceGrpc.FeatureServiceImplBase() {

    override fun getFeature(
        request: GetFeatureRequest,
        responseObserver: StreamObserver<GetFeatureResponse>,
    ) {
        val result = service.getFeature(request.id)
        responseObserver.onNext(result.toProtoResponse())
        responseObserver.onCompleted()
    }
}
```

### GraphQL Controller
```kotlin
@Controller
class FeatureController(
    private val featureService: FeatureService,
) {
    @QueryMapping
    @PreAuthorize("hasAuthority('User')")
    fun features(@UserId userId: String): List<FeatureResponse> {
        return featureService.getFeatures(userId)
    }
}
```

## Anti-Patterns

- `!!` 사용 금지 (테스트 코드 제외)
- `var` 최소화, `val` 우선
- 불필요한 `companion object` 지양
- Entity에 비즈니스 로직 넣지 않기 (Service에 위치)
- Repository에서 직접 gRPC 응답 만들지 않기 (Service 거쳐야 함)
