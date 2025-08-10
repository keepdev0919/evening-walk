import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 사용자의 위치가 출발지에 복귀했는지 여부를 확인하는 역할을 담당하는 클래스.
class StartReturnEventHandler {
  // 출발지 복귀 도착 반경 설정
  static const double startReturnArrivalRadius = 20.0;

  /// 사용자 위치가 출발지 도착 반경 내에 있는지 확인합니다.
  bool checkStartArrival({
    required LatLng userLocation,
    required LatLng startLocation,
    bool forceStartReturnEvent = false,
  }) {
    // 강제 이벤트 발생 플래그가 true이면 항상 도착한 것으로 간주합니다.
    if (forceStartReturnEvent) {
      print('StartReturnEventHandler: 출발지 복귀 완료! (강제)');
      return true;
    }

    // 출발지와 현재 위치 간의 거리 계산
    final double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      startLocation.latitude,
      startLocation.longitude,
    );

    print('StartReturnEventHandler: 출발지까지 거리: ${distance.toStringAsFixed(1)}m');
    return distance <= startReturnArrivalRadius;
  }
}
