import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'dart:convert'; // JSON 디코딩을 위해 추가
import 'package:flutter/services.dart' show rootBundle; // rootBundle을 위해 추가

class WaypointEventHandler {
  // 경유지 도착 반경 (미터) - 50m에서 20m로 수정
  static const double waypointArrivalRadius = 20.0;

  // 산책 메이트별 질문 목록 (로드 후 저장될 맵)
  Map<String, List<String>> _loadedQuestions = {};

  // 생성자에서 질문 로드를 시작합니다.
  WaypointEventHandler() {
    _loadQuestions();
  }

  // JSON 파일에서 질문을 비동기적으로 로드합니다.
  Future<void> _loadQuestions() async {
    try {
      final String aloneJson = await rootBundle.loadString('lib/src/features/walk/application/data/walk_question/alone_questions.json');
      final String coupleJson = await rootBundle.loadString('lib/src/features/walk/application/data/walk_question/couple_questions.json');
      final String friendJson = await rootBundle.loadString('lib/src/features/walk/application/data/walk_question/friend_questions.json');

      _loadedQuestions['혼자'] = List<String>.from(json.decode(aloneJson));
      _loadedQuestions['연인'] = List<String>.from(json.decode(coupleJson));
      _loadedQuestions['친구'] = List<String>.from(json.decode(friendJson));

      print('WaypointEventHandler: 질문 파일 로드 완료.');
    } catch (e) {
      print('WaypointEventHandler: 질문 파일 로드 실패: $e');
    }
  }

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
      
      final List<String>? mateQuestions = _loadedQuestions[selectedMate]; // 로드된 질문 사용
      if (mateQuestions != null && mateQuestions.isNotEmpty) {
        final Random random = Random();
        final String question = mateQuestions[random.nextInt(mateQuestions.length)];
        return question;
      }
    }
    return null;
  }
}
