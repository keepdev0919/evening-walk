import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/log_service.dart';

/// 말풍선 상태를 나타내는 enum
enum SpeechBubbleState {
  toWaypoint("산책 가보자고 ~"), 
  almostWaypoint("선물.. 선물.. 선물.. "), 
  waypointEventCompleted("뚜비두밥~♪"), 
  almostDestination("고지가 코앞이다 !!");

  const SpeechBubbleState(this.message);
  final String message;
}

/// 말풍선 상태 관리 전용 서비스
/// SRP: 말풍선 상태 계산과 관리만 담당
class SpeechBubbleStateService {
  SpeechBubbleState? _currentState;
  bool _isVisible = true;

  SpeechBubbleState? get currentState => _currentState;
  bool get isVisible => _isVisible;

  /// 현재 위치를 기반으로 말풍선 상태 업데이트
  void updateState({
    required LatLng currentPosition,
    required LatLng startLocation,
    required LatLng waypointLocation, 
    required LatLng destinationLocation,
    bool waypointEventCompleted = false,
  }) {
    final newState = _calculateOptimalState(
      currentPosition: currentPosition,
      startLocation: startLocation,
      waypointLocation: waypointLocation,
      destinationLocation: destinationLocation,
      waypointEventCompleted: waypointEventCompleted,
    );

    if (newState != null && newState != _currentState) {
      _currentState = newState;
      LogService.info('SpeechBubble', '말풍선 상태 변경: ${newState.message}');
    }
  }

  /// 현재 위치를 기반으로 적절한 말풍선 상태 계산
  SpeechBubbleState? _calculateOptimalState({
    required LatLng currentPosition,
    required LatLng startLocation,
    required LatLng waypointLocation,
    required LatLng destinationLocation,
    required bool waypointEventCompleted,
  }) {
    final distances = _calculateDistances(
      currentPosition, 
      startLocation, 
      waypointLocation, 
      destinationLocation,
    );

    // 목적지 근처인 경우 (최우선)
    if (distances.toDestination <= distances.halfWaypointToDestination) {
      return SpeechBubbleState.almostDestination;
    }

    // 경유지 이벤트가 완료되었다면 해당 상태 유지
    if (waypointEventCompleted && 
        _currentState == SpeechBubbleState.waypointEventCompleted) {
      return SpeechBubbleState.waypointEventCompleted;
    }

    // 경유지 근처인 경우
    if (distances.toWaypoint <= distances.halfStartToWaypoint) {
      return SpeechBubbleState.almostWaypoint;
    }

    // 기본 상태: 출발지에서 경유지로 향하는 중
    return SpeechBubbleState.toWaypoint;
  }

  /// 거리 계산 결과를 담는 클래스
  _DistanceCalculationResult _calculateDistances(
    LatLng current,
    LatLng start, 
    LatLng waypoint,
    LatLng destination,
  ) {
    return _DistanceCalculationResult(
      toWaypoint: Geolocator.distanceBetween(
        current.latitude, current.longitude,
        waypoint.latitude, waypoint.longitude,
      ),
      toDestination: Geolocator.distanceBetween(
        current.latitude, current.longitude,
        destination.latitude, destination.longitude,
      ),
      startToWaypoint: Geolocator.distanceBetween(
        start.latitude, start.longitude,
        waypoint.latitude, waypoint.longitude,
      ),
      waypointToDestination: Geolocator.distanceBetween(
        waypoint.latitude, waypoint.longitude,
        destination.latitude, destination.longitude,
      ),
    );
  }

  /// 경유지 이벤트 완료 시 상태 변경
  void completeWaypointEvent() {
    if (_currentState == SpeechBubbleState.almostWaypoint) {
      _currentState = SpeechBubbleState.waypointEventCompleted;
      LogService.info('SpeechBubble', 
          '경유지 이벤트 완료 - 말풍선: ${_currentState?.message}');
    }
  }

  /// 말풍선 표시 여부 설정
  void setVisible(bool visible) {
    _isVisible = visible;
  }

  /// 개발자 전용: 말풍선 상태 강제 설정 (디버그 모드에서만)
  void setDebugState(SpeechBubbleState state) {
    if (kDebugMode) {
      _currentState = state;
      LogService.debug('SpeechBubble', 'DEBUG: 말풍선 상태 강제 설정: ${state.message}');
    }
  }

  /// 상태 초기화
  void reset() {
    _currentState = SpeechBubbleState.toWaypoint;
    _isVisible = true;
  }
}

/// 거리 계산 결과를 담는 내부 클래스
class _DistanceCalculationResult {
  final double toWaypoint;
  final double toDestination;
  final double startToWaypoint;
  final double waypointToDestination;

  _DistanceCalculationResult({
    required this.toWaypoint,
    required this.toDestination,
    required this.startToWaypoint,
    required this.waypointToDestination,
  });

  double get halfStartToWaypoint => startToWaypoint / 2;
  double get halfWaypointToDestination => waypointToDestination / 2;
}