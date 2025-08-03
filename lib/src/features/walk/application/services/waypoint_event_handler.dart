import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class WaypointEventHandler {
  // 경유지 도착 반경 (미터) - 50m에서 20m로 수정
  static const double waypointArrivalRadius = 20.0;

  // 산책 메이트별 질문 목록
  final Map<String, List<String>> _questions = {
    '혼자': [
      '오늘 하루 어땠나요? 가장 기억에 남는 순간은?',
      '지금 이 순간, 당신을 가장 행복하게 하는 것은 무엇인가요?',
      '앞으로 5년 뒤, 당신은 어떤 모습이 되고 싶나요?',
    ],
    '연인': [
      '우리 처음 만났을 때 어땠는지 기억나? 그때 어떤 느낌이었어?',
      '서로에게 가장 고마웠던 순간은 언제야?',
      '앞으로 함께 하고 싶은 일 한 가지를 말해줄래?',
    ],
    '친구': [
      '우리 우정의 시작은 언제였을까? 가장 기억에 남는 추억은?',
      '서로에게 가장 힘이 되어주었던 순간은 언제야?',
      '다음에 같이 하고 싶은 활동이 있다면?',
    ],
  };

  // 시작점과 목적지 사이의 중간 지점을 경유지로 생성
  LatLng generateWaypoint(LatLng start, LatLng destination) {
    final double lat = (start.latitude + destination.latitude) / 2;
    final double lng = (start.longitude + destination.longitude) / 2;
    return LatLng(lat, lng);
  }

  // 사용자 위치 업데이트 시 경유지 도착 여부 확인
  String? checkWaypointArrival({
    required LatLng userLocation,
    required LatLng? waypointLocation,
    required String? selectedMate,
    bool forceWaypointEvent = false, // forceWaypointEvent 매개변수 추가
  }) {
    if (waypointLocation == null || selectedMate == null) {
      return null;
    }

    final double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      waypointLocation.latitude,
      waypointLocation.longitude,
    );

    if (forceWaypointEvent || distance <= waypointArrivalRadius) { // 조건 변경
      print('WaypointEventHandler: 경유지 도착! 선택된 메이트: $selectedMate');
      
      final List<String>? mateQuestions = _questions[selectedMate];
      if (mateQuestions != null && mateQuestions.isNotEmpty) {
        final Random random = Random();
        final String question = mateQuestions[random.nextInt(mateQuestions.length)];
        return question;
      }
    }
    return null;
  }
}
