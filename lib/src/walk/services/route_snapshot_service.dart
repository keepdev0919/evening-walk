import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:walk/src/core/services/log_service.dart';

/// Static Maps API를 사용해 출발지-경유지-목적지 경로 이미지를 생성하는 서비스
class RouteSnapshotService {
  /// 출발지(start) → 경유지(선택) → 목적지(destination) 경로의 정적 지도 이미지를 생성합니다.
  /// 반환: PNG 바이트 (성공 시) 또는 null (실패 시)
  static Future<Uint8List?> generateRouteSnapshot({
    required LatLng start,
    LatLng? waypoint,
    required LatLng destination,
    int width = 600,
    int height = 400,
  }) async {
    final String? apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;

    final String size = 'size=${width}x$height';

    // 마커: 출발지(S, 파란색), 경유지(W, 주황색), 목적지(D, 빨간색)
    final String startMarker =
        'markers=color:blue%7Clabel:S%7C${start.latitude},${start.longitude}';
    final String waypointMarker = waypoint != null
        ? 'markers=color:orange%7Clabel:W%7C${waypoint.latitude},${waypoint.longitude}'
        : '';
    final String destinationMarker =
        'markers=color:red%7Clabel:D%7C${destination.latitude},${destination.longitude}';

    // 경로선 제거: 마커만 표시

    final List<String> parts = [
      'https://maps.googleapis.com/maps/api/staticmap?',
      size,
      '&scale=2', // 고해상도
      '&maptype=roadmap',
      '&$startMarker',
      if (waypoint != null) '&$waypointMarker',
      '&$destinationMarker',
      '&key=$apiKey',
    ];

    final String url = parts.join('');
    LogService.info('RouteSnapshot', 'Static Maps 요청: $url');

    try {
      final http.Response resp = await http.get(Uri.parse(url));
      LogService.info('RouteSnapshot', '응답 코드: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        LogService.info(
            'RouteSnapshot', 'PNG 크기: ${resp.bodyBytes.length} bytes');
        return resp.bodyBytes;
      } else {
        LogService.warning('RouteSnapshot',
            '실패 응답: ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}');
      }
    } catch (e) {
      LogService.error('RouteSnapshot', 'Static Maps 요청 중 오류', e);
    }
    return null;
  }
}
