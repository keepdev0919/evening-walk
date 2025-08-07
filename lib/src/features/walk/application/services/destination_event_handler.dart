import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DestinationEventHandler {
  // 목적지 도착 반경 설정 (20m)
  static const double destinationArrivalRadius = 20.0;

  // 목적지 도착 확인 로직
  bool checkDestinationArrival({
    required LatLng userLocation,
    required LatLng destinationLocation,
    bool forceDestinationEvent = false,
  }) {
    if (forceDestinationEvent) {
      return true;
    }
    final double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      destinationLocation.latitude,
      destinationLocation.longitude,
    );

    return distance <= destinationArrivalRadius;
  }
}
