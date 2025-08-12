# Firebase 데이터 구조 마이그레이션 가이드

## 개요
기존 `walk_sessions` 독립 컬렉션을 `users/{userId}/walk_sessions` 서브컬렉션 구조로 변경하여 확장성과 성능을 개선합니다.

## 마이그레이션 전후 구조 비교

### Before (기존)
```
walk_sessions/
  session1/
    - userId: "user1"
    - startTime: ...
    - ...
  session2/
    - userId: "user1"
    - ...
  session3/
    - userId: "user2"
    - ...
```

### After (변경 후)
```
users/
  user1/
    - email: ...
    - nickname: ...
    walk_sessions/
      session1/
        - startTime: ...  (userId 제거됨)
        - ...
      session2/
        - ...
  user2/
    - email: ...
    - nickname: ...
    walk_sessions/
      session3/
        - ...
```

## 마이그레이션 단계

### 1단계: 코드 업데이트 (완료)
- ✅ `WalkSessionService.dart` 서브컬렉션 구조로 변경
- ✅ 모든 Firebase 쿼리 경로 업데이트
- ✅ Firebase 인덱스 주석 업데이트

### 2단계: 데이터 마이그레이션
```bash
# 마이그레이션 스크립트 실행
dart run scripts/migrate_walk_sessions.dart
```

**주의사항:**
- 실행 전 Firebase 프로젝트 설정 확인
- 데이터 백업 권장
- 서비스 사용량이 적은 시간에 실행

### 3단계: 보안 규칙 업데이트
```bash
# 새로운 보안 규칙 배포
firebase deploy --only firestore:rules
```

`firestore_security_rules.rules` 파일을 Firebase Console 또는 Firebase CLI로 배포합니다.

### 4단계: 검증 및 정리
1. 앱에서 새로운 구조 정상 작동 확인
2. Firebase Console에서 기존 `walk_sessions` 컬렉션 삭제
3. 보안 규칙에서 기존 컬렉션 관련 규칙 제거

## 예상 효과

### 성능 개선
- **쿼리 속도**: 사용자별 데이터만 스캔하므로 대폭 향상
- **인덱스 크기**: 서브컬렉션별 인덱스로 최적화
- **네트워크**: 불필요한 데이터 전송 감소

### 비용 절감
- **읽기 횟수**: userId 필터링 없이 직접 접근
- **인덱스 비용**: 작은 서브컬렉션 인덱스 사용
- **대역폭**: 필요한 데이터만 전송

### 확장성
- **사용자 수**: 무제한 확장 가능
- **데이터 양**: 사용자별 분산으로 선형 확장
- **관리 용이성**: 사용자별 데이터 독립 관리

## 롤백 계획
문제 발생 시 기존 `walk_sessions` 컬렉션이 그대로 유지되므로:
1. 코드를 이전 버전으로 되돌림
2. 보안 규칙을 이전 버전으로 복원
3. 새로 생성된 서브컬렉션 데이터는 수동 정리

## 주의사항
- 마이그레이션 중에는 앱 사용을 제한하는 것이 좋습니다
- 대량의 데이터가 있는 경우 단계적 마이그레이션을 고려하세요
- Firebase 할당량과 요금을 미리 확인하세요

## 문의
마이그레이션 관련 문의사항은 개발팀에 문의해주세요.