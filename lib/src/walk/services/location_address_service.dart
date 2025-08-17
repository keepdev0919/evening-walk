import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/log_service.dart';

/// 위치 좌표를 주소로 변환하는 전용 서비스
/// SRP: 단일 책임 원칙에 따라 주소 변환 로직만 담당
class LocationAddressService {
  /// 좌표를 주소로 변환하는 메인 메서드
  Future<String> convertCoordinateToAddress(LatLng coordinate) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        coordinate.latitude,
        coordinate.longitude,
      );

      if (placemarks.isEmpty) {
        return _formatCoordinateFallback(coordinate);
      }

      return _buildAddressFromPlacemark(placemarks.first);
    } catch (e) {
      LogService.error('LocationAddress', '주소 변환 실패', e);
      return _formatCoordinateFallback(coordinate);
    }
  }

  /// Placemark 정보를 읽기 쉬운 주소로 변환
  String _buildAddressFromPlacemark(Placemark placemark) {
    final addressParts = _extractAddressParts(placemark);
    final cleanedParts = _removeInvalidTokens(addressParts);
    final finalAddress = cleanedParts.join(' ').trim();
    
    return finalAddress.isNotEmpty ? finalAddress : '알 수 없는 위치';
  }

  /// Placemark에서 유효한 주소 구성 요소 추출
  List<String> _extractAddressParts(Placemark placemark) {
    final parts = <String>[];
    
    final cityA = _sanitizeString(placemark.locality);
    final cityB = _sanitizeString(placemark.subAdministrativeArea);
    final district = _sanitizeString(placemark.subLocality);
    final road = _sanitizeString(placemark.thoroughfare);
    final number = _sanitizeString(placemark.subThoroughfare);
    
    if (cityA.isNotEmpty) parts.add(cityA);
    if (cityB.isNotEmpty && _isDifferentCity(cityA, cityB)) {
      parts.add(cityB);
    }
    if (district.isNotEmpty) parts.add(district);
    
    final roadInfo = _buildRoadInfo(road, number);
    if (roadInfo.isNotEmpty) parts.add(roadInfo);
    
    return parts;
  }

  /// 문자열 정리 및 유효성 검증
  String _sanitizeString(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty || _isPlaceholder(trimmed)) return '';
    return trimmed;
  }

  /// 플레이스홀더 문자열 판별
  bool _isPlaceholder(String value) {
    return const ['.', '·', '-'].contains(value);
  }

  /// 서로 다른 도시인지 확인
  bool _isDifferentCity(String cityA, String cityB) {
    return cityB != cityA && 
           !cityA.contains(cityB) && 
           !cityB.contains(cityA);
  }

  /// 도로명과 번지 정보를 조합
  String _buildRoadInfo(String road, String number) {
    if (road.isEmpty) return '';
    return number.isNotEmpty ? '$road $number' : road;
  }

  /// 유효하지 않은 토큰 제거
  List<String> _removeInvalidTokens(List<String> parts) {
    final deduplicated = <String>[];
    for (final part in parts) {
      if (part.isNotEmpty && !deduplicated.contains(part)) {
        deduplicated.add(part);
      }
    }
    return deduplicated;
  }

  /// 좌표 형태로 fallback 주소 생성
  String _formatCoordinateFallback(LatLng coordinate) {
    return '${coordinate.latitude.toStringAsFixed(4)}, '
           '${coordinate.longitude.toStringAsFixed(4)}';
  }
}