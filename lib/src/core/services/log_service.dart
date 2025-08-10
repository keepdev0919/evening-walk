import 'package:flutter/foundation.dart';

/// 통합 로깅 서비스
/// 개발 모드에서는 모든 로그를 출력하고, 릴리스 모드에서는 에러 로그만 출력
class LogService {
  // === 디버그 로그 (개발 모드에서만 출력) ===
  static void debug(String tag, String message) {
    if (kDebugMode) {
      print('[DEBUG][$tag] $message');
    }
  }
  
  // === 정보성 로그 ===
  static void info(String tag, String message) {
    print('[INFO][$tag] $message');
  }
  
  // === 경고 로그 ===
  static void warning(String tag, String message) {
    print('[WARNING][$tag] $message');
  }
  
  // === 에러 로그 (항상 출력) ===
  static void error(String tag, String message, [Object? error]) {
    print('[ERROR][$tag] $message');
    if (error != null) {
      print('[ERROR][$tag] Exception: $error');
    }
  }
  
  // === WalkStateManager 전용 로그 ===
  static void walkState(String message) {
    debug('WalkState', message);
  }
  
  // === 위치 추적 전용 로그 ===
  static void location(String message) {
    debug('Location', message);
  }
  
  // === 공유 기능 전용 로그 ===
  static void share(String message) {
    debug('Share', message);
  }
  
  // === 포즈 추천 전용 로그 ===
  static void pose(String message) {
    debug('Pose', message);
  }
  
  // === 이벤트 핸들링 전용 로그 ===
  static void event(String message) {
    debug('Event', message);
  }
}