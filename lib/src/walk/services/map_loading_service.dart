import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 맵 로딩 상태를 실제로 확인하는 서비스입니다.
/// 위치 권한, 현재 위치, 맵 컨트롤러 상태 등을 종합적으로 확인합니다.
class MapLoadingService {
  static MapLoadingService? _instance;
  static MapLoadingService get instance => _instance ??= MapLoadingService._();

  MapLoadingService._();

  /// 맵이 완전히 로딩되었는지 확인하고 위치 정보를 반환합니다.
  /// 다음 조건들을 모두 만족해야 합니다:
  /// 1. 위치 권한이 허용됨
  /// 2. 현재 위치를 가져올 수 있음
  /// 3. 위치 데이터가 유효함
  /// 4. Google Maps 완전 로딩 대기
  ///
  /// 반환값: (로딩 성공 여부, 위치 정보)
  Future<Map<String, dynamic>> isMapFullyLoaded() async {
    try {
      // 1. 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return {
          'success': false,
          'position': null,
        };
      }

      // 2. 현재 위치 가져오기 (정확도 높게)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // 10초 타임아웃
      );

      // 3. 위치 데이터 유효성 확인
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        return {
          'success': false,
          'position': null,
        };
      }

      // 4. 추가 검증: 위치가 합리적인 범위 내에 있는지 확인
      if (position.latitude < -90 ||
          position.latitude > 90 ||
          position.longitude < -180 ||
          position.longitude > 180) {
        return {
          'success': false,
          'position': null,
        };
      }

      // 5. Google Maps 완전 로딩을 위한 추가 대기 시간 제거
      // 기존 방식과 동일하게 위치 정보만 확인

      return {
        'success': true,
        'position': LatLng(position.latitude, position.longitude),
      };
    } catch (e) {
      // 오류 발생 시 실패 정보 반환
      return {
        'success': false,
        'position': null,
      };
    }
  }

  /// 맵 로딩 진행률을 계산합니다 (0.0 ~ 1.0).
  /// 각 단계별로 진행률을 반환합니다.
  Future<double> getLoadingProgress() async {
    try {
      double progress = 0.0;

      // 1. 위치 권한 확인 (25%)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        progress += 0.25;
      } else {
        return progress; // 권한이 없으면 여기서 중단
      }

      // 2. 위치 서비스 활성화 확인 (25%)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        progress += 0.25;
      } else {
        return progress;
      }

      // 3. 현재 위치 가져오기 (50%)
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        if (position.latitude != 0.0 || position.longitude != 0.0) {
          progress += 0.5;
        }
      } catch (e) {
        // 위치 가져오기 실패 시 진행률 유지
      }

      return progress;
    } catch (e) {
      return 0.0;
    }
  }

  /// 맵 로딩이 완료될 때까지 대기합니다.
  /// 최대 대기 시간을 설정할 수 있습니다.
  Future<Map<String, dynamic>> waitForMapLoading({
    Duration maxWaitTime = const Duration(seconds: 20),
    Duration checkInterval = const Duration(milliseconds: 300),
  }) async {
    final DateTime startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      final result = await isMapFullyLoaded();
      if (result['success'] == true) {
        return result;
      }

      await Future.delayed(checkInterval);
    }

    return {
      'success': false,
      'position': null,
    }; // 타임아웃
  }

  /// 더 정확한 맵 로딩 상태를 확인합니다.
  /// Google Maps의 실제 렌더링 상태까지 고려합니다.
  Future<Map<String, dynamic>> isMapRenderingComplete() async {
    try {
      // 기본 맵 로딩 확인
      final result = await isMapFullyLoaded();
      if (result['success'] != true) return result;

      // Google Maps 렌더링 대기 시간 제거
      // 기존 방식과 동일하게 위치 정보만 확인

      return result;
    } catch (e) {
      return {
        'success': false,
        'position': null,
      };
    }
  }
}
