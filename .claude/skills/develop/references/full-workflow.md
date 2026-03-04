# Development Full Workflow Reference

## 상세 개발 워크플로우

이 문서는 `develop/SKILL.md`의 상세 참조 문서이다.

## 1. Entity 설계 상세

### ID 전략
```kotlin
// UUID 기반 (기본)
@Id
@GeneratedValue(generator = "uuid2")
@GenericGenerator(name = "uuid2", strategy = "uuid2")
val id: String = ""

// Auto Increment (특수한 경우)
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
val id: Long = 0
```

### 관계 매핑
```kotlin
// ManyToOne (가장 흔함)
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "user_id")
val user: UserEntity? = null

// referencedColumnName 지정 (PK가 아닌 컬럼 참조 시)
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "category_id", referencedColumnName = "code")
val category: CategoryEntity? = null

// OneToMany (필요한 경우만)
@OneToMany(mappedBy = "post", fetch = FetchType.LAZY)
val comments: List<CommentEntity> = emptyList()
```

### Enum 매핑
```kotlin
// DB에 정수로 저장
@Column(nullable = false)
var status: Int = 0

// Kotlin enum과 매핑
enum class UserStatus(val value: Int) {
    ACTIVE(0),
    INACTIVE(1),
    BANNED(2);

    companion object {
        fun fromValue(value: Int) = entries.first { it.value == value }
    }
}
```

## 2. Repository 상세

### QueryDSL
```kotlin
interface CustomRepository {
    fun findByComplexCondition(userId: String, status: Int): List<Entity>
}

class CustomRepositoryImpl(
    private val queryFactory: JPAQueryFactory,
) : CustomRepository {
    override fun findByComplexCondition(userId: String, status: Int): List<Entity> {
        val entity = QEntity.entity
        return queryFactory
            .selectFrom(entity)
            .where(
                entity.userId.eq(userId),
                entity.status.eq(status),
                entity.deletedAt.isNull,
            )
            .orderBy(entity.createdAt.desc())
            .fetch()
    }
}
```

### Native Query
```kotlin
@Query("""
    SELECT e.* FROM maum.entity e
    LEFT JOIN maum.other o ON e.id = o.entity_id
    WHERE e.user_id = :userId
    AND o.id IS NULL
""", nativeQuery = true)
fun findWithoutRelation(@Param("userId") userId: String): List<Entity>
```

## 3. gRPC 에러 처리 상세

### 서버 측 (마이크로서비스)
```kotlin
override fun getFeature(
    request: GetFeatureRequest,
    responseObserver: StreamObserver<GetFeatureResponse>,
) {
    try {
        val result = service.getFeature(request.id)
        responseObserver.onNext(result.toProtoResponse())
        responseObserver.onCompleted()
    } catch (e: NotFoundException) {
        responseObserver.onError(
            Status.NOT_FOUND
                .withDescription(e.message)
                .asRuntimeException()
        )
    } catch (e: Exception) {
        responseObserver.onError(
            Status.INTERNAL
                .withDescription("Internal error")
                .asRuntimeException()
        )
    }
}
```

### 클라이언트 측 (GraphQL 모듈)
```kotlin
fun getFeature(id: String): GetFeatureResponse {
    return try {
        stub.getFeature(request)
    } catch (e: StatusRuntimeException) {
        when (e.status.code) {
            Status.Code.NOT_FOUND -> throw CustomGraphQLException("NOT_FOUND", e.status.description)
            Status.Code.INVALID_ARGUMENT -> throw CustomGraphQLException("BAD_REQUEST", e.status.description)
            else -> throw CustomGraphQLException("INTERNAL", "서비스 오류")
        }
    }
}
```

## 4. 트랜잭션 패턴

```kotlin
@Service
class FeatureService(
    private val repository: FeatureRepository,
    private val eventPublisher: ApplicationEventPublisher,
) {
    // 읽기 전용
    @Transactional(readOnly = true)
    fun getById(id: String): Entity {
        return repository.findById(id).orElseThrow { NotFoundException("Not found: $id") }
    }

    // 쓰기 (기본)
    @Transactional
    fun create(input: CreateInput): Entity {
        val entity = Entity(name = input.name)
        return repository.save(entity)
    }

    // 여러 Repository 사용
    @Transactional
    fun complexOperation(userId: String, input: Input): Result {
        val user = userRepository.findById(userId).orElseThrow()
        val entity = repository.save(Entity(userId = userId))
        historyRepository.save(History(entityId = entity.id, action = "CREATE"))
        return Result(entity)
    }
}
```
