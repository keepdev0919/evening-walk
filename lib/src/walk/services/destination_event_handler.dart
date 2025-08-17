import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/src/core/constants/app_constants.dart';
import 'package:walk/src/core/services/log_service.dart';

class DestinationEventHandler {
  // 목적지 도착 확인 로직 (에러 핸들링 강화)
  bool checkDestinationArrival({
    required LatLng userLocation,
    required LatLng destinationLocation,
    bool forceDestinationEvent = false,
  }) {
    try {
      // 강제 이벤트 처리
      if (forceDestinationEvent) {
        LogService.info('Walk', 'DestinationEventHandler: 목적지 도착! (강제)');
        return true;
      }
      
      // 입력 데이터 유효성 검증
      if (!_isValidLatLng(userLocation)) {
        LogService.warning('Walk', 'DestinationEventHandler: 유효하지 않은 사용자 위치 - $userLocation');
        return false;
      }
      
      if (!_isValidLatLng(destinationLocation)) {
        LogService.warning('Walk', 'DestinationEventHandler: 유효하지 않은 목적지 위치 - $destinationLocation');
        return false;
      }
      
      final double distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        destinationLocation.latitude,
        destinationLocation.longitude,
      );
      
      final bool hasArrived = distance <= AppConstants.destinationTriggerDistance;
      
      if (hasArrived) {
        LogService.info('Walk', 'DestinationEventHandler: 목적지 도착! 거리: ${distance.toStringAsFixed(1)}m');
      }

      return hasArrived;
    } catch (e) {
      LogService.error('Walk', 'DestinationEventHandler: 목적지 도착 확인 중 오류', e);
      return false;
    }
  }
  
  /// 좌표 유효성 검증
  bool _isValidLatLng(LatLng location) {
    return location.latitude.abs() <= 90.0 && 
           location.longitude.abs() <= 180.0 &&
           location.latitude != 0.0 && 
           location.longitude != 0.0;
  }
}
