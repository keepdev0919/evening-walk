import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 기기 나침반(자기 센서)과 이동 진행방향(course, GPS)을 융합해
/// 안정적이고 사용자 인지에 맞는 바라보는 방향(0~360°)을 제공하는 컨트롤러입니다.
/// - 정지/저속: 나침반 가중치↑ (실시간 나침반 갱신)
/// - 고속 이동: 진행방향(course) 가중치↑
/// - 각도는 최단경로 보간과 EMA 성격의 완화로 급격한 튐을 억제합니다.
class HeadingController {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<Position>? _positionSub;
  Timer? _compassUpdateTimer;

  double? _lastCompassHeading; // 0~360
  Position? _lastPosition; // course 계산용
  double? _smoothedHeading; // EMA 적용된 최근 결과 (0~360)

  // 정지 상태 감지를 위한 변수들
  DateTime? _lastPositionUpdateTime;
  bool _isStationary = false;
  static const Duration _stationaryThreshold = Duration(seconds: 2);

  /// 융합 각도 스트림(도 단위, 0~360).
  Stream<double> get stream => _controller.stream;

  /// 스트림 시작. 이미 시작되어 있다면 중복 시작하지 않습니다.
  void start({LocationSettings? locationSettings}) {
    if (_compassSub != null || _positionSub != null) return;

    _compassSub = FlutterCompass.events?.listen((event) {
      final double? h = event.heading; // 0~360 또는 null
      if (h != null) {
        _lastCompassHeading = _normalize(h);

        // 정지 상태일 때는 나침반 변화만으로도 즉시 업데이트
        if (_isStationary && _smoothedHeading != null) {
          _updateHeadingFromCompass();
        }
      }
    });

    // 나침반 전용 타이머 시작 (정지 상태에서 200ms마다 체크)
    _startCompassTimer();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings ??
          const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          ),
    ).listen((pos) {
      final double speed = pos.speed; // m/s
      final DateTime now = DateTime.now();

      // 정지 상태 감지 로직 업데이트
      _updateStationaryStatus(pos, now);

      // 이동 진행방향(course) 후보 계산
      double? courseHeading;
      if (_lastPosition != null) {
        final double movedMeters = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (movedMeters >= 2.0) {
          courseHeading = _bearingBetween(
            LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
            LatLng(pos.latitude, pos.longitude),
          );
        }
      }

      // 가중치 산정: 속도에 따라 course 비중↑, 정지 시 compass 비중↑
      final weights = _weightsBySpeed(speed);
      final double? compassHeading = _lastCompassHeading;

      // 둘 다 없으면 업데이트 못함
      if (compassHeading == null && courseHeading == null) {
        _lastPosition = pos;
        return;
      }

      // 하나만 유효한 경우, 그 값으로 대체
      final double fused = _fuseAnglesWeighted(
        compassHeading,
        courseHeading,
        weights.$1,
        weights.$2,
      );

      // EMA 스타일 완화 적용 (최단 경로 보간)
      final double alpha = _alphaBySpeed(speed);
      _smoothedHeading = (_smoothedHeading == null)
          ? fused
          : _lerpAngleShortestDegrees(_smoothedHeading!, fused, alpha);

      _controller.add(_smoothedHeading!);
      _lastPosition = pos;
      _lastPositionUpdateTime = now;
    });
  }

  /// 정지.
  Future<void> stop() async {
    await _compassSub?.cancel();
    await _positionSub?.cancel();
    _compassUpdateTimer?.cancel();
    _compassSub = null;
    _positionSub = null;
    _compassUpdateTimer = null;
  }

  /// 자원 해제.
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  // ---- 내부 보조 함수들 ----

  /// 나침반 전용 타이머 시작 (정지 상태 감지 및 실시간 업데이트)
  void _startCompassTimer() {
    _compassUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 200), (_) {
      _checkStationaryStatus();
    });
  }

  /// 정지 상태 체크 및 나침반 업데이트
  void _checkStationaryStatus() {
    if (_lastPositionUpdateTime != null) {
      final timeSinceLastUpdate =
          DateTime.now().difference(_lastPositionUpdateTime!);
      final wasStationary = _isStationary;
      _isStationary = timeSinceLastUpdate >= _stationaryThreshold;

      // 정지 상태로 전환되었거나 계속 정지 중일 때 나침반으로 업데이트
      if (_isStationary &&
          _lastCompassHeading != null &&
          _smoothedHeading != null) {
        if (!wasStationary || _shouldUpdateCompass()) {
          _updateHeadingFromCompass();
        }
      }
    }
  }

  /// 정지 상태 업데이트 (위치 변화 감지)
  void _updateStationaryStatus(Position pos, DateTime now) {
    if (_lastPosition != null) {
      final double movedMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );

      // 의미있는 이동이 있으면 정지 상태 해제
      if (movedMeters >= 2.0) {
        _isStationary = false;
      }
    }
    _lastPositionUpdateTime = now;
  }

  /// 나침반만으로 방향 업데이트 (정지 상태용)
  void _updateHeadingFromCompass() {
    if (_lastCompassHeading == null) return;

    // 정지 상태에서는 나침반 100% 적용, 부드러운 보간 사용
    final double alpha = 0.3; // 부드러운 전환을 위한 낮은 알파값
    _smoothedHeading = _lerpAngleShortestDegrees(
      _smoothedHeading!,
      _lastCompassHeading!,
      alpha,
    );

    _controller.add(_smoothedHeading!);
  }

  /// 나침반 업데이트가 필요한지 판단
  bool _shouldUpdateCompass() {
    if (_lastCompassHeading == null || _smoothedHeading == null) return false;

    // 현재 방향과 나침반 방향의 차이가 5도 이상이면 업데이트
    final double diff = (_lastCompassHeading! - _smoothedHeading!).abs();
    final double normalizedDiff = diff > 180 ? 360 - diff : diff;
    return normalizedDiff >= 5.0;
  }

  double _normalize(double deg) {
    double a = deg % 360.0;
    if (a < 0) a += 360.0;
    return a;
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final double lat1 = from.latitude * math.pi / 180.0;
    final double lon1 = from.longitude * math.pi / 180.0;
    final double lat2 = to.latitude * math.pi / 180.0;
    final double lon2 = to.longitude * math.pi / 180.0;
    final double dLon = lon2 - lon1;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final double brng = math.atan2(y, x);
    return _normalize(brng * 180.0 / math.pi);
  }

  // 속도별 보정 민감도 (EMA 계수)
  double _alphaBySpeed(double speedMetersPerSecond) {
    if (speedMetersPerSecond >= 3.0) return 0.35; // 빠름
    if (speedMetersPerSecond >= 1.5) return 0.25; // 보통
    if (speedMetersPerSecond >= 0.5) return 0.15; // 느림
    return 0.10; // 정지
  }

  // 속도별 compass/course 가중치
  (double, double) _weightsBySpeed(double speedMetersPerSecond) {
    if (speedMetersPerSecond >= 3.0) return (0.2, 0.8);
    if (speedMetersPerSecond >= 1.5) return (0.4, 0.6);
    if (speedMetersPerSecond >= 0.5) return (0.7, 0.3);
    return (1.0, 0.0);
  }

  // 두 각(0~360)을 가중 평균. 벡터 평균으로 래핑 문제 해결
  double _fuseAnglesWeighted(
    double? compass,
    double? course,
    double wCompass,
    double wCourse,
  ) {
    if (compass == null) return _normalize(course!);
    if (course == null) return _normalize(compass);

    final double cRad = compass * math.pi / 180.0;
    final double sRad = course * math.pi / 180.0;
    final double x = wCompass * math.sin(cRad) + wCourse * math.sin(sRad);
    final double y = wCompass * math.cos(cRad) + wCourse * math.cos(sRad);
    final double fused = math.atan2(x, y) * 180.0 / math.pi; // 0:북 기준
    return _normalize(fused);
  }

  // 최단 회전 경로로 각도 보간
  double _lerpAngleShortestDegrees(double fromDeg, double toDeg, double t) {
    double from = _normalize(fromDeg);
    double to = _normalize(toDeg);
    double diff = to - from;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    return _normalize(from + diff * t);
  }
}
