import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:walk/src/core/services/log_service.dart';
import 'package:walk/src/core/constants/app_constants.dart';

/// 사용자의 위치가 경유지에 도착했는지 여부를 확인하는 역할을 담당하는 클래스.
class WaypointEventHandler {
  /// 시작점과 목적지 사이의 중간 지점을 경유지로 생성합니다.
  LatLng generateWaypoint(LatLng start, LatLng destination) {
    try {
      // 입력 좌표 유효성 검증
      if (!_isValidLatLng(start) || !_isValidLatLng(destination)) {
        LogService.error('Walk', 'WaypointEventHandler: 유효하지 않은 좌표 - start: $start, destination: $destination');
        // 유효하지 않은 경우 기본값 반환
        return const LatLng(37.5665, 126.9780); // 서울시청 좌표
      }
      
      final double lat = (start.latitude + destination.latitude) / 2;
      final double lng = (start.longitude + destination.longitude) / 2;
      final waypoint = LatLng(lat, lng);
      
      LogService.info('Walk', 'WaypointEventHandler: 경유지 생성 성공 - $waypoint');
      return waypoint;
    } catch (e) {
      LogService.error('Walk', 'WaypointEventHandler: 경유지 생성 중 오류', e);
      return const LatLng(37.5665, 126.9780); // 기본값 반환
    }
  }

  /// 사용자 위치가 경유지 도착 반경 내에 있는지 확인합니다.
  bool checkWaypointArrival({
    required LatLng userLocation,
    required LatLng? waypointLocation, // LatLng? 타입으로 수정하여 null을 허용
    bool forceWaypointEvent = false, // 디버그용 플래그
  }) {
    // 경유지 위치가 null이면 절대 도착할 수 없으므로 false를 반환합니다.
    if (waypointLocation == null) {
      return false;
    }

    // 강제 이벤트 발생 플래그가 true이면 항상 도착한 것으로 간주합니다.
    if (forceWaypointEvent) {
      LogService.info('Walk', 'WaypointEventHandler: 경유지 도착! (강제)');
      return true;
    }

    final double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      waypointLocation.latitude, // null 체크 이후이므로 안전하게 사용 가능
      waypointLocation.longitude,
    );

    return distance <= AppConstants.waypointTriggerDistance;
  }
  
  /// 좌표 유효성 검증
  bool _isValidLatLng(LatLng location) {
    return location.latitude.abs() <= 90.0 && 
           location.longitude.abs() <= 180.0 &&
           location.latitude != 0.0 && 
           location.longitude != 0.0;
  }
}
