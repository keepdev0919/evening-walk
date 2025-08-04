import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 산책 중 지도를 표시하는 위젯입니다.
/// GoogleMap 위젯을 캡슐화하고, 필요한 속성들을 외부에서 주입받아 사용합니다.
class WalkMapView extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final MapCreatedCallback onMapCreated;

  const WalkMapView({
    Key? key,
    required this.initialCameraPosition,
    required this.markers,
    required this.onMapCreated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: initialCameraPosition,
      markers: markers,
      myLocationButtonEnabled: false, // 현재 위치 버튼 비활성화
      zoomControlsEnabled: false, // 줌 컨트롤 비활성화
    );
  }
}
