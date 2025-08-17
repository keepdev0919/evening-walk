import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:walk/src/core/services/log_service.dart';

/// Firebase Analytics를 관리하는 중앙화된 서비스 클래스
/// 앱 전반의 사용자 행동 및 이벤트를 추적합니다.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal() {
    _initializeAnalytics();
  }

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  /// Analytics 초기화 및 디버그 설정
  void _initializeAnalytics() {
    try {
      // 디버그 모드에서 Analytics 활성화
      _analytics.setAnalyticsCollectionEnabled(true);
      LogService.debug('Analytics', '🚀 Firebase Analytics 초기화 완료');
    } catch (e) {
      LogService.error('Analytics', 'Analytics 초기화 실패', e);
    }
  }
  
  /// Analytics Observer (Navigator 연결용)
  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  // =========================
  // 화면 추적 이벤트
  // =========================

  /// 화면 조회 이벤트
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      LogService.debug('Analytics', '화면 조회: $screenName');
    } catch (e) {
      LogService.error('Analytics', '화면 조회 이벤트 실패', e);
    }
  }

  // =========================
  // 인증 관련 이벤트
  // =========================

  /// 로그인 이벤트
  Future<void> logLogin(String method) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      LogService.debug('Analytics', '로그인: $method');
    } catch (e) {
      LogService.error('Analytics', '로그인 이벤트 실패', e);
    }
  }

  /// 회원가입 이벤트
  Future<void> logSignUp(String method) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      LogService.debug('Analytics', '회원가입: $method');
    } catch (e) {
      LogService.error('Analytics', '회원가입 이벤트 실패', e);
    }
  }

  // =========================
  // 산책 관련 커스텀 이벤트
  // =========================

  /// 산책 시작 이벤트
  Future<void> logWalkStarted({
    required String mateType,
    String? startLocation,
  }) async {
    try {
      final parameters = {
        'mate_type': mateType,
        'start_location': startLocation ?? 'unknown',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _analytics.logEvent(
        name: 'walk_started',
        parameters: parameters,
      );
      
      LogService.debug('Analytics', '✅ 산책 시작 이벤트 전송 성공');
      LogService.debug('Analytics', '📊 Parameters: $parameters');
    } catch (e) {
      LogService.error('Analytics', '❌ 산책 시작 이벤트 실패', e);
    }
  }

  /// 경유지 도착 이벤트
  Future<void> logWaypointArrived({
    required String mateType,
    String? questionType,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'waypoint_arrived',
        parameters: {
          'mate_type': mateType,
          'question_type': questionType ?? 'none',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      LogService.debug('Analytics', '경유지 도착: $mateType, $questionType');
    } catch (e) {
      LogService.error('Analytics', '경유지 도착 이벤트 실패', e);
    }
  }

  /// 질문 답변 완료 이벤트
  Future<void> logQuestionAnswered({
    required String mateType,
    required String questionType,
    required int answerLength,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'question_answered',
        parameters: {
          'mate_type': mateType,
          'question_type': questionType,
          'answer_length': answerLength,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      LogService.debug('Analytics', '질문 답변: $mateType, $questionType, ${answerLength}자');
    } catch (e) {
      LogService.error('Analytics', '질문 답변 이벤트 실패', e);
    }
  }

  /// 목적지 도착 이벤트
  Future<void> logDestinationArrived({
    required String mateType,
    String? destinationName,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'destination_arrived',
        parameters: {
          'mate_type': mateType,
          'destination_name': destinationName ?? 'unknown',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      LogService.debug('Analytics', '목적지 도착: $mateType, $destinationName');
    } catch (e) {
      LogService.error('Analytics', '목적지 도착 이벤트 실패', e);
    }
  }

  /// 사진 촬영 이벤트
  Future<void> logPhotoTaken({
    required String mateType,
    String? location,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'photo_taken',
        parameters: {
          'mate_type': mateType,
          'location': location ?? 'destination',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      LogService.debug('Analytics', '사진 촬영: $mateType');
    } catch (e) {
      LogService.error('Analytics', '사진 촬영 이벤트 실패', e);
    }
  }

  /// 산책 완료 이벤트
  Future<void> logWalkCompleted({
    required String mateType,
    required int durationMinutes,
    required double distanceKm,
    bool photoTaken = false,
    bool questionAnswered = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'walk_completed',
        parameters: {
          'mate_type': mateType,
          'duration_minutes': durationMinutes,
          'distance_km': distanceKm,
          'photo_taken': photoTaken,
          'question_answered': questionAnswered,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      LogService.debug('Analytics', '산책 완료: $mateType, ${durationMinutes}분, ${distanceKm}km');
    } catch (e) {
      LogService.error('Analytics', '산책 완료 이벤트 실패', e);
    }
  }

  /// 일기 작성 이벤트
  Future<void> logDiaryWritten({
    required String mateType,
    required int contentLength,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'diary_written',
        parameters: {
          'mate_type': mateType,
          'content_length': contentLength,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      LogService.debug('Analytics', '일기 작성: $mateType, ${contentLength}자');
    } catch (e) {
      LogService.error('Analytics', '일기 작성 이벤트 실패', e);
    }
  }

  // =========================
  // 사용자 속성 설정
  // =========================

  /// 사용자 속성 설정
  Future<void> setUserProperties({
    String? age,
    String? gender,
    String? region,
  }) async {
    try {
      if (age != null) {
        await _analytics.setUserProperty(name: 'age_group', value: age);
      }
      if (gender != null) {
        await _analytics.setUserProperty(name: 'gender', value: gender);
      }
      if (region != null) {
        await _analytics.setUserProperty(name: 'region', value: region);
      }
      LogService.debug('Analytics', '사용자 속성 설정 완료');
    } catch (e) {
      LogService.error('Analytics', '사용자 속성 설정 실패', e);
    }
  }

  /// 선호 메이트 속성 설정
  Future<void> setFavoriteMate(String mateType) async {
    try {
      await _analytics.setUserProperty(name: 'favorite_mate', value: mateType);
      LogService.debug('Analytics', '선호 메이트 설정: $mateType');
    } catch (e) {
      LogService.error('Analytics', '선호 메이트 설정 실패', e);
    }
  }

  // =========================
  // 일반적인 커스텀 이벤트
  // =========================

  /// 버튼 클릭 이벤트
  Future<void> logButtonClick(String buttonName, {String? screenName}) async {
    try {
      await _analytics.logEvent(
        name: 'button_click',
        parameters: {
          'button_name': buttonName,
          'screen_name': screenName ?? 'unknown',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      LogService.debug('Analytics', '버튼 클릭: $buttonName');
    } catch (e) {
      LogService.error('Analytics', '버튼 클릭 이벤트 실패', e);
    }
  }

  /// 오류 이벤트
  Future<void> logError(String errorType, String errorMessage) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      LogService.debug('Analytics', '오류 기록: $errorType');
    } catch (e) {
      LogService.error('Analytics', '오류 이벤트 실패', e);
    }
  }

  // =========================
  // 개발/테스트용 메서드
  // =========================

  /// 테스트용 이벤트 (Analytics 작동 확인용)
  Future<void> logTestEvent() async {
    try {
      await _analytics.logEvent(
        name: 'test_analytics',
        parameters: {
          'test_timestamp': DateTime.now().millisecondsSinceEpoch,
          'app_version': '1.0.0',
        },
      );
      LogService.debug('Analytics', '🧪 테스트 이벤트 전송 완료');
    } catch (e) {
      LogService.error('Analytics', '🧪 테스트 이벤트 실패', e);
    }
  }

  /// Analytics 상태 확인
  Future<bool> isAnalyticsEnabled() async {
    try {
      // Firebase Analytics가 활성화되어 있는지 확인하는 간접적인 방법
      await _analytics.logEvent(name: 'analytics_check', parameters: {});
      LogService.debug('Analytics', '📊 Analytics 활성화 상태: 정상');
      return true;
    } catch (e) {
      LogService.error('Analytics', '📊 Analytics 상태 확인 실패', e);
      return false;
    }
  }
}