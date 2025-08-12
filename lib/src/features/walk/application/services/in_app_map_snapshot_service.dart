import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/src/features/walk/presentation/utils/map_marker_creator.dart';

/// 앱 내부에서 GoogleMap을 오버레이로 잠시 렌더링한 뒤 스냅샷을 찍어 PNG를 생성합니다.
class InAppMapSnapshotService {
  static Future<Uint8List?> captureRouteSnapshot({
    required BuildContext context,
    required LatLng start,
    LatLng? waypoint,
    required LatLng destination,
    double width = 600,
    double height = 400,
    double padding = 48,
  }) async {
    final overlay = Overlay.of(context);
    // Overlay는 정상 앱 컨텍스트에서 항상 존재합니다.

    final completer = Completer<Uint8List?>();
    final mapKey = GlobalKey();
    // 컨트롤러는 지역 변수 생략 (takeSnapshot은 매개변수의 c 사용)

    Set<Marker> markers = {};

    // 기본 시작 마커: 파란색 디폴트, 경유지/목적지: 커스텀 비트맵
    final BitmapDescriptor startIcon =
        await MapMarkerCreator.createHomeMarkerBitmap();
    final BitmapDescriptor destIcon =
        await MapMarkerCreator.createDestinationMarkerBitmap();
    final BitmapDescriptor? waypointIcon = waypoint != null
        ? await MapMarkerCreator.createGiftBoxMarkerBitmap()
        : null;

    markers.add(Marker(
      markerId: const MarkerId('start'),
      position: start,
      infoWindow: const InfoWindow(title: '출발지'),
      icon: startIcon,
    ));
    if (waypoint != null && waypointIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('waypoint'),
        position: waypoint,
        infoWindow: const InfoWindow(title: '경유지'),
        icon: waypointIcon,
      ));
    }
    markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: destination,
      infoWindow: const InfoWindow(title: '목적지'),
      icon: destIcon,
    ));

    // 경로선 제거: 마커만 표시
    final Set<Polyline> polylines = {};

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          // 화면 안에 렌더링하되, 거의 투명하게 깔아두고 스냅샷만 촬영
          // 지도 플랫폼 뷰 특성상 완전 offstage/opacity 0은 렌더링되지 않을 수 있음
          left: 0,
          top: 0,
          child: IgnorePointer(
            ignoring: true,
            child: Opacity(
              opacity: 0.01,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: GoogleMap(
                    key: mapKey,
                    initialCameraPosition: CameraPosition(
                      target: start,
                      zoom: 14,
                    ),
                    markers: markers,
                    polylines: polylines,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (c) async {
                      // 카메라를 경로 전체가 보이도록 이동
                      final bounds = _boundsFor([
                        start,
                        if (waypoint != null) waypoint,
                        destination,
                      ].whereType<LatLng>().toList());
                      if (bounds != null) {
                        await c.animateCamera(
                          CameraUpdate.newLatLngBounds(bounds, padding),
                        );
                      }

                      // 타일 로드 대기 후 스냅샷 촬영
                      await Future.delayed(const Duration(milliseconds: 800));
                      try {
                        final bytes = await c.takeSnapshot();
                        completer.complete(bytes);
                      } catch (_) {
                        completer.complete(null);
                      }
                      // overlay 제거는 Future 완료 후 외부에서
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    final png = await completer.future;
    entry.remove();
    return png;
  }

  static LatLngBounds? _boundsFor(List<LatLng> positions) {
    if (positions.isEmpty) return null;
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final p in positions) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
