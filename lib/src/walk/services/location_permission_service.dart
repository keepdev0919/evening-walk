import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../core/services/log_service.dart';

/// 위치 권한 관리 전용 서비스
/// 위치 권한 확인, 요청, GPS 활성화 상태 확인 등을 담당
class LocationPermissionService {
  
  /// 위치 서비스 전반적인 상태 확인 및 권한 요청
  Future<LocationPermissionResult> checkAndRequestPermissions() async {
    try {
      // 1. 위치 서비스 활성화 확인
      final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        LogService.warning('Location', '위치 서비스가 비활성화되어 있습니다.');
        return LocationPermissionResult(
          isGranted: false,
          errorType: LocationErrorType.serviceDisabled,
          message: '위치 서비스를 활성화해주세요.',
        );
      }

      // 2. 현재 권한 상태 확인
      LocationPermission permission = await Geolocator.checkPermission();
      
      // 3. 권한이 거부된 경우 요청
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          LogService.warning('Location', '위치 권한이 거부되었습니다.');
          return LocationPermissionResult(
            isGranted: false,
            errorType: LocationErrorType.permissionDenied,
            message: '위치 권한을 허용해주세요.',
          );
        }
      }

      // 4. 영구적으로 거부된 경우
      if (permission == LocationPermission.deniedForever) {
        LogService.error('Location', '위치 권한이 영구적으로 거부되었습니다.');
        return LocationPermissionResult(
          isGranted: false,
          errorType: LocationErrorType.permissionDeniedForever,
          message: '설정에서 위치 권한을 허용해주세요.',
        );
      }

      // 5. 성공
      LogService.info('Location', '위치 권한이 정상적으로 허용되었습니다.');
      return LocationPermissionResult(
        isGranted: true,
        errorType: null,
        message: '위치 권한 허용 완료',
      );

    } catch (e) {
      LogService.error('Location', '위치 권한 확인 중 오류 발생', e);
      return LocationPermissionResult(
        isGranted: false,
        errorType: LocationErrorType.unknown,
        message: '위치 권한 확인 중 오류가 발생했습니다.',
      );
    }
  }

  /// 현재 위치 가져오기 (에러 핸들링 강화)
  Future<Position?> getCurrentLocationSafely() async {
    try {
      final permissionResult = await checkAndRequestPermissions();
      if (!permissionResult.isGranted) {
        LogService.warning('Location', '위치 권한 없음: ${permissionResult.message}');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // 타임아웃 설정
      );

      LogService.info('Location', '현재 위치 획득 성공: ${position.latitude}, ${position.longitude}');
      return position;
      
    } on TimeoutException {
      LogService.error('Location', 'GPS 신호 획득 시간 초과');
      return null;
    } catch (e) {
      // 모든 geolocator 관련 예외를 포괄적으로 처리
      if (e.toString().contains('location service')) {
        LogService.error('Location', '위치 서비스가 비활성화됨');
      } else if (e.toString().contains('permission')) {
        LogService.error('Location', '위치 권한이 거부됨');
      } else {
        LogService.error('Location', '현재 위치 획득 중 오류 발생', e);
      }
      return null;
    }
  }

  /// 위치 정확도가 충분한지 확인
  bool isAccuracyAcceptable(Position position, {double maxAccuracyMeters = 50.0}) {
    final accuracy = position.accuracy;
    final isAcceptable = accuracy <= maxAccuracyMeters;
    
    if (!isAcceptable) {
      LogService.warning('Location', '위치 정확도 부족: ${accuracy}m (최대 허용: ${maxAccuracyMeters}m)');
    }
    
    return isAcceptable;
  }

  /// GPS 신호 강도 확인
  bool isGpsSignalStrong(Position position) {
    // 정확도가 20m 이하면 강한 신호로 판단
    return position.accuracy <= 20.0;
  }
}

/// 위치 권한 결과를 나타내는 클래스
class LocationPermissionResult {
  final bool isGranted;
  final LocationErrorType? errorType;
  final String message;

  LocationPermissionResult({
    required this.isGranted,
    required this.errorType,
    required this.message,
  });
}

/// 위치 관련 에러 타입
enum LocationErrorType {
  serviceDisabled,      // 위치 서비스 비활성화
  permissionDenied,     // 권한 거부
  permissionDeniedForever, // 권한 영구 거부
  timeout,              // 시간 초과
  accuracyInsufficient, // 정확도 부족
  unknown,              // 알 수 없는 오류
}