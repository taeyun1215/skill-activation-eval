---
name: test-skill
description: "JUnit5 + Mockito 테스트 작성 가이드"
---

# Test Skill

## 설명

JUnit5 + Mockito 기반의 단위 테스트와 통합 테스트를 작성한다.

## 실행 절차

### 1. 단위 테스트 (Service Layer)

위치: `{module}/src/test/kotlin/com/maum/backend/service/`

```kotlin
@ExtendWith(MockitoExtension::class)
class FeatureServiceTest {

    @Mock
    private lateinit var repository: FeatureRepository

    @InjectMocks
    private lateinit var service: FeatureService

    @Test
    fun `should return features by userId`() {
        // given
        val userId = "test-user-id"
        val entities = listOf(
            FeatureEntity(id = "1", userId = userId, name = "feature1")
        )
        `when`(repository.findByUserId(userId)).thenReturn(entities)

        // when
        val result = service.getFeatures(userId)

        // then
        assertThat(result).hasSize(1)
        assertThat(result[0].name).isEqualTo("feature1")
        verify(repository).findByUserId(userId)
    }

    @Test
    fun `should throw when feature not found`() {
        // given
        `when`(repository.findById("invalid")).thenReturn(Optional.empty())

        // when & then
        assertThrows<NotFoundException> {
            service.getFeatureById("invalid")
        }
    }
}
```

### 2. gRPC Service 테스트

```kotlin
@ExtendWith(MockitoExtension::class)
class FeatureGrpcServiceTest {

    @Mock
    private lateinit var service: FeatureService

    @InjectMocks
    private lateinit var grpcService: FeatureGrpcService

    @Test
    fun `should return features via gRPC`() {
        // given
        val request = GetFeaturesRequest.newBuilder()
            .setUserId("user-id")
            .build()
        val responseObserver = mock<StreamObserver<GetFeaturesResponse>>()

        `when`(service.getFeatures("user-id")).thenReturn(listOf(/* ... */))

        // when
        grpcService.getFeatures(request, responseObserver)

        // then
        verify(responseObserver).onNext(any())
        verify(responseObserver).onCompleted()
        verify(responseObserver, never()).onError(any())
    }
}
```

### 3. Repository 테스트 (통합)

```kotlin
@DataJpaTest
class FeatureRepositoryTest {

    @Autowired
    private lateinit var repository: FeatureRepository

    @Test
    fun `should find by userId`() {
        // given
        val entity = FeatureEntity(userId = "user-1", name = "test")
        repository.save(entity)

        // when
        val result = repository.findByUserId("user-1")

        // then
        assertThat(result).hasSize(1)
    }
}
```

### 4. 실행

```bash
# 전체 테스트
./gradlew :module:test

# 특정 클래스
./gradlew :module:test --tests "*.FeatureServiceTest"
```

## 테스트 네이밍

- 백틱 사용: `` `should return features by userId` ``
- `should + 동사` 패턴
- 실패 케이스: `should throw when ...`, `should return empty when ...`

## 패턴

| 패턴 | 설명 |
|------|------|
| given-when-then | 모든 테스트에 적용 |
| `@Mock` + `@InjectMocks` | 단위 테스트 기본 |
| `@DataJpaTest` | Repository 통합 테스트 |
| `@SpringBootTest` | 전체 통합 테스트 (최소화) |
