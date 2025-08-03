import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DestinationEventHandler {
  // 목적지 도착 반경 설정 (20m)
  static const double destinationArrivalRadius = 20.0;

  // 목적지 도착 확인 로직
  bool checkDestinationArrival({
    required LatLng userLocation,
    required LatLng destinationLocation,
  }) {
    final double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      destinationLocation.latitude,
      destinationLocation.longitude,
    );

    return distance <= destinationArrivalRadius;
  }

  // 포즈 추천 로직 (플레이스홀더 아이콘)
  List<IconData> getPoseSuggestions() {
    return [
      Icons.favorite_border,
      Icons.camera_alt_outlined,
      Icons.star_border,
      Icons.sentiment_very_satisfied_outlined,
    ];
  }
}
