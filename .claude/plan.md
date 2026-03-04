# Project Roadmap

## Current Focus
- 그룹톡(디스커버리) WebSocket 기능 개발
- 프로모션 푸시알림 시스템

## Milestones

### v0.9.x — 현재
- [x] 프로모션 푸시알림 (#540)
- [x] 활동내역 차단/신고자 필터링 (#538)
- [ ] 디스커버리 그룹톡 WebSocket
- [ ] gRPC 서비스 간 통신 안정화

### v1.0.0 — 안정화
- [ ] 전체 테스트 커버리지 향상
- [ ] API 문서화 완성
- [ ] 성능 최적화 (N+1 쿼리 제거)
- [ ] 에러 핸들링 표준화

## Backlog
- 채팅 메시지 검색 고도화
- 통화 품질 모니터링 대시보드
- A/B 테스트 프레임워크 개선
- 결제 시스템 리팩터링

## Architecture Decisions
- ADR은 `docs/adr/` 디렉토리에 기록
- 주요 결정은 `.claude/tasks/` 에 태스크로 관리
