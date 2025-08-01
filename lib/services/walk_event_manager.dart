import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class WalkEventManager {
  LatLng? _startLocation;
  LatLng? _destinationLocation;
  LatLng? _waypointLocation;
  String? _selectedMate;

  // 경유지 도착 반경 (미터)
  static const double _waypointArrivalRadius = 50.0;

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

  WalkEventManager();

  // 산책 시작 시 초기화 및 경유지 생성
  void startWalk({
    required LatLng start,
    required LatLng destination,
    required String mate,
  }) {
    _startLocation = start;
    _destinationLocation = destination;
    _selectedMate = mate;
    _waypointLocation = _generateWaypoint(start, destination);
    print('WalkEventManager initialized. Waypoint: $_waypointLocation, Mate: $_selectedMate');
  }

  // 경유지 좌표 반환
  LatLng? getWaypoint() {
    return _waypointLocation;
  }

  // 시작점과 목적지 사이의 중간 지점을 경유지로 생성
  LatLng _generateWaypoint(LatLng start, LatLng destination) {
    // 간단하게 중간 지점 계산 (위도, 경도 평균)
    // 실제 경로를 따라가는 중간 지점 계산은 더 복잡한 알고리즘이 필요합니다.
    final double lat = (start.latitude + destination.latitude) / 2;
    final double lng = (start.longitude + destination.longitude) / 2;
    return LatLng(lat, lng);
  }

  // 사용자 위치 업데이트 시 경유지 도착 여부 확인
  Future<String?> checkWaypointArrival(LatLng userLocation) async {
    if (_waypointLocation == null || _selectedMate == null) {
      return null;
    }

    final double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      _waypointLocation!.latitude,
      _waypointLocation!.longitude,
    );

    if (distance <= _waypointArrivalRadius) {
      print('경유지 도착! 선택된 메이트: $_selectedMate');
      _waypointLocation = null; // 경유지 도착 후 초기화

      // 선택된 메이트에 맞는 질문 목록에서 랜덤으로 질문 선택
      final List<String>? mateQuestions = _questions[_selectedMate!];
      if (mateQuestions != null && mateQuestions.isNotEmpty) {
        final Random random = Random();
        final String question = mateQuestions[random.nextInt(mateQuestions.length)];
        return question;
      }
    }
    return null;
  }

  // TODO: 경유지 도착 시 이벤트 트리거 (질문 목록 관리 및 띄우기)
  // void _triggerWaypointEvent(String mate) {
  //   // 선택된 메이트에 따라 질문 목록에서 질문 선택 및 띄우기
  // }
}
