import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/src/core/constants/app_constants.dart';

class DestinationEventHandler {
  // 목적지 도착 확인 로직
  bool checkDestinationArrival({
    required LatLng userLocation,
    required LatLng destinationLocation,
    bool forceDestinationEvent = false,
  }) {
    if (forceDestinationEvent) {
      //목적지 도착 디버그 버튼을 눌렀을때 여기가 실행됨.
      return true;
    }
    final double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      destinationLocation.latitude,
      destinationLocation.longitude,
    );

    return distance <= AppConstants.destinationTriggerDistance;
  }
}
