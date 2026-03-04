---
name: grpc-skill
description: "gRPC 서비스 및 Proto 정의 작성 가이드"
---

# gRPC Skill

## 설명

Protocol Buffers 정의부터 gRPC 서비스 구현까지의 워크플로우를 안내한다.

## 실행 절차

### 1. Proto 정의

위치: `protobuf/src/main/proto/{도메인}/{service}.proto`

```protobuf
syntax = "proto3";
package feature;

option java_multiple_files = true;
option java_package = "com.maum.backend.protobuf.feature";

service FeatureService {
  rpc GetFeature(GetFeatureRequest) returns (GetFeatureResponse);
  rpc CreateFeature(CreateFeatureRequest) returns (CreateFeatureResponse);
  rpc ListFeatures(ListFeaturesRequest) returns (ListFeaturesResponse);
}

message GetFeatureRequest {
  string user_id = 1;
  string feature_id = 2;
}

message GetFeatureResponse {
  Feature feature = 1;
}

message Feature {
  string id = 1;
  string name = 2;
  string user_id = 3;
  string created_at = 4;
}
```

### 2. Proto 빌드

```bash
./gradlew :protobuf:clean :protobuf:build
```

### 3. gRPC Service 구현 (서버)

위치: `{module}/src/main/kotlin/com/maum/backend/controller/`

```kotlin
@GrpcService
class FeatureGrpcService(
    private val featureService: FeatureService,
) : FeatureServiceGrpc.FeatureServiceImplBase() {

    override fun getFeature(
        request: GetFeatureRequest,
        responseObserver: StreamObserver<GetFeatureResponse>,
    ) {
        val feature = featureService.getFeature(request.userId, request.featureId)
        val response = GetFeatureResponse.newBuilder()
            .setFeature(feature.toProto())
            .build()
        responseObserver.onNext(response)
        responseObserver.onCompleted()
    }
}
```

### 4. gRPC Client 구현 (GraphQL 모듈)

위치: `graphql/src/main/kotlin/com/maum/backend/service/{도메인}/`

```kotlin
@Service
class FeatureService {
    @GrpcClient("feature-grpc")
    private lateinit var featureStub: FeatureServiceGrpc.FeatureServiceBlockingStub

    fun getFeature(userId: String, featureId: String): GetFeatureResponse {
        val request = GetFeatureRequest.newBuilder()
            .setUserId(userId)
            .setFeatureId(featureId)
            .build()
        return try {
            featureStub.getFeature(request)
        } catch (e: StatusRuntimeException) {
            throw CustomGraphQLException(e.trailers!!, e.status.description)
        }
    }
}
```

### 5. gRPC 채널 설정

`application.yml`:
```yaml
grpc:
  client:
    feature-grpc:
      address: 'dns:///feature-service:9090'
      negotiationType: plaintext
```

## Proto 컨벤션

| 항목 | 규칙 |
|------|------|
| 패키지 | 도메인명 (소문자) |
| 서비스명 | `{Domain}Service` |
| 메서드명 | `Get`, `Create`, `Update`, `Delete`, `List` |
| 필드명 | `snake_case` |
| Request/Response | `{Method}Request`, `{Method}Response` |

## 주의사항

- Proto 변경 시 하위 호환성 유지 (필드 번호 재사용 금지)
- `optional` 키워드로 선택 필드 명시
- 에러 처리: `responseObserver.onError(Status.NOT_FOUND.asException())`
