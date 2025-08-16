import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';

/// 순수 나침반 센서 기반 방향 컨트롤러
/// 사용자가 현재 바라보는 방향(0~360°)을 제공합니다.
/// - GPS 융합 없음: 순수 나침반 센서만 사용
/// - 실시간 반응: 핸드폰 방향 변화 시 즉시 반영
/// - 사용 목적: 사용자의 현재 바라보는 방향 표시 (네비게이션 아님)
class HeadingController {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  StreamSubscription<CompassEvent>? _compassSub;

  double? _currentHeading; // 0~360
  double? _smoothedHeading; // EMA 적용된 최근 결과 (0~360)

  // 나침반 센서 상태 관리
  bool _isCompassAvailable = false;
  bool _hasInterference = false;
  DateTime? _lastValidHeadingTime;
  static const Duration _interferenceThreshold = Duration(seconds: 2);

  /// 나침반 각도 스트림(도 단위, 0~360).
  /// 사용자가 현재 바라보는 방향을 실시간으로 제공합니다.
  Stream<double> get stream => _controller.stream;

  /// 나침반 센서 사용 가능 여부
  bool get isCompassAvailable => _isCompassAvailable;

  /// 자기장 간섭 여부
  bool get hasInterference => _hasInterference;

  /// 나침반 센서 시작
  void start() {
    if (_compassSub != null) return; // 이미 시작된 경우 중복 방지

    _compassSub = FlutterCompass.events?.listen((event) {
      final double? heading = event.heading;
      final double? accuracy = event.accuracy;

      if (heading != null && accuracy != null) {
        _isCompassAvailable = true;
        _hasInterference = false;
        _lastValidHeadingTime = DateTime.now();

        // 정확도가 낮으면 간섭으로 간주
        if (accuracy > 15.0) {
          _hasInterference = true;
        }

        _updateHeading(_normalize(heading));
      } else {
        // 나침반 데이터가 없거나 간섭이 있는 경우
        _isCompassAvailable = false;
        _checkInterferenceStatus();
      }
    });
  }

  /// 나침반 센서 정지
  Future<void> stop() async {
    await _compassSub?.cancel();
    _compassSub = null;
    _isCompassAvailable = false;
    _hasInterference = false;
  }

  /// 자원 해제
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  /// 새로운 나침반 방향 업데이트
  void _updateHeading(double newHeading) {
    if (_currentHeading == null) {
      // 첫 번째 값: 즉시 설정
      _currentHeading = newHeading;
      _smoothedHeading = newHeading;
      _controller.add(_smoothedHeading!);
      return;
    }

    // 급격한 변화 감지 (간섭 가능성)
    final double angleDiff = (newHeading - _currentHeading!).abs();
    final double normalizedDiff = angleDiff > 180 ? 360 - angleDiff : angleDiff;

    if (normalizedDiff > 45.0) {
      // 급격한 변화는 간섭일 가능성이 높음
      _hasInterference = true;
      // 간섭 시에는 부드러운 전환을 위해 더 낮은 알파값 사용
      final double alpha = 0.1;
      _smoothedHeading = _lerpAngleShortestDegrees(
        _smoothedHeading!,
        newHeading,
        alpha,
      );
    } else {
      // 정상적인 변화
      _hasInterference = false;
      // 부드러운 전환을 위한 EMA 필터링
      // 너무 급격한 변화를 방지하면서도 반응성 유지
      final double alpha = 0.3; // 적절한 반응성과 안정성의 균형
      _smoothedHeading = _lerpAngleShortestDegrees(
        _smoothedHeading!,
        newHeading,
        alpha,
      );
    }

    _currentHeading = newHeading;
    _controller.add(_smoothedHeading!);
  }

  /// 자기장 간섭 상태 체크
  void _checkInterferenceStatus() {
    if (_lastValidHeadingTime != null) {
      final timeSinceLastValid =
          DateTime.now().difference(_lastValidHeadingTime!);
      if (timeSinceLastValid >= _interferenceThreshold) {
        _hasInterference = true;
        _isCompassAvailable = false;
      }
    }
  }

  /// 각도 정규화 (0~360 범위로 변환)
  double _normalize(double deg) {
    double a = deg % 360.0;
    if (a < 0) a += 360.0;
    return a;
  }

  /// 최단 회전 경로로 각도 보간
  /// 360° ↔ 0° 전환 시 자연스러운 회전을 위해 사용
  double _lerpAngleShortestDegrees(double fromDeg, double toDeg, double t) {
    double from = _normalize(fromDeg);
    double to = _normalize(toDeg);
    double diff = to - from;

    // 180도보다 큰 차이면 반대 방향으로 회전하는 것이 더 짧음
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;

    return _normalize(from + diff * t);
  }
}
