import 'package:google_maps_flutter/google_maps_flutter.dart';
import './waypoint_event_handler.dart';
import './destination_event_handler.dart';

class WalkStateManager {
  // 핸들러 인스턴스
  final WaypointEventHandler _waypointHandler = WaypointEventHandler();
  final DestinationEventHandler _destinationHandler = DestinationEventHandler();

  // 산책 상태 변수
  LatLng? _startLocation;
  LatLng? _destinationLocation;
  LatLng? _waypointLocation;
  String? _selectedMate;

  // 이벤트 결과 저장 변수
  String? _waypointQuestion;
  String? _userAnswer; // <<< 변수 선언 추가
  String? _photoPath; // <<< 변수 선언 추가
  bool _waypointEventOccurred = false;
  bool _destinationEventOccurred = false;

  // --- Public Getters ---
  LatLng? get waypointLocation => _waypointLocation;
  String? get waypointQuestion => _waypointQuestion;

  // 답변 및 사진 저장 메소드
  void saveAnswerAndPhoto({String? answer, String? photoPath}) {
    _userAnswer = answer;
    _photoPath = photoPath;
    print('WalkStateManager: 답변 저장 -> "$_userAnswer"');
    print('WalkStateManager: 사진 경로 저장 -> "$_photoPath"');
  }

  // 산책 시작 시 초기화
  void startWalk({
    required LatLng start,
    required LatLng destination,
    required String mate,
  }) {
    _startLocation = start;
    _destinationLocation = destination;
    _selectedMate = mate;
    _waypointLocation = _waypointHandler.generateWaypoint(start, destination);
    _waypointEventOccurred = false;
    _destinationEventOccurred = false;
    _waypointQuestion = null;
    _userAnswer = null;
    _photoPath = null;
    print('WalkStateManager: 산책 시작. 경유지: $_waypointLocation');
  }

  // 실시간 위치 업데이트 처리
  String? updateUserLocation(LatLng userLocation) {
    // 경유지 이벤트 확인
    if (!_waypointEventOccurred) {
      final String? question = _waypointHandler.checkWaypointArrival(
        userLocation: userLocation,
        waypointLocation: _waypointLocation,
        selectedMate: _selectedMate,
      );

      if (question != null) {
        _waypointQuestion = question;
        _waypointEventOccurred = true;
        print('WalkStateManager: 경유지 질문 생성 -> "$_waypointQuestion"');
        return _waypointQuestion;
      }
    }

    // 목적지 이벤트 확인
    if (!_destinationEventOccurred) {
      final bool arrived = _destinationHandler.checkDestinationArrival(
        userLocation: userLocation,
        destinationLocation: _destinationLocation!,
      );

      if (arrived) {
        _destinationEventOccurred = true;
        print('WalkStateManager: 목적지 도착!');
        return "destination_reached";
      }
    }

    return null;
  }
}
