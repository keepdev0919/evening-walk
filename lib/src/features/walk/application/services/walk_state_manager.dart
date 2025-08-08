import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'waypoint_event_handler.dart';
import 'destination_event_handler.dart';
import 'waypoint_questions.dart';
import 'package:image_picker/image_picker.dart';

class WalkStateManager {
  // 핸들러 및 프로바이더 인스턴스
  final WaypointEventHandler _waypointHandler = WaypointEventHandler();
  final DestinationEventHandler _destinationHandler = DestinationEventHandler();
  final WaypointQuestionProvider _questionProvider = WaypointQuestionProvider();

  // 산책 상태 변수
  LatLng? _startLocation;  // 출발지 위치 추가
  LatLng? _destinationLocation;
  LatLng? _waypointLocation;
  String? _selectedMate;

  // 이벤트 결과 저장 변수
  String? _waypointQuestion;
  String? _userAnswer;
  String? _photoPath;
  bool _waypointEventOccurred = false;
  bool _destinationEventOccurred = false;
  bool _startReturnEventOccurred = false;  // 출발지 복귀 이벤트 상태 추가

  // --- Public Getters ---
  LatLng? get startLocation => _startLocation;
  LatLng? get waypointLocation => _waypointLocation;
  String? get waypointQuestion => _waypointQuestion;
  String? get userAnswer => _userAnswer;
  String? get photoPath => _photoPath;
  String? get selectedMate => _selectedMate;
  bool get isWalkComplete => _startReturnEventOccurred;

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
    _startLocation = start;  // 출발지 위치 저장
    _destinationLocation = destination;
    _selectedMate = mate;
    _waypointLocation = _waypointHandler.generateWaypoint(start, destination);
    _waypointEventOccurred = false;
    _destinationEventOccurred = false;
    _startReturnEventOccurred = false;  // 출발지 복귀 상태 초기화
    _waypointQuestion = null;
    _userAnswer = null;
    _photoPath = null;
    print('WalkStateManager: 산책 시작. 출발지: $_startLocation, 경유지: $_waypointLocation');
  }

  // 실시간 위치 업데이트 처리 (Future<String?>으로 변경)
  Future<String?> updateUserLocation(LatLng userLocation, {
    bool forceWaypointEvent = false,
    bool forceDestinationEvent = false,
    bool forceStartReturnEvent = false,  // 출발지 복귀 디버그 옵션 추가
  }) async {
    // 경유지 이벤트 확인 (아직 발생하지 않았을 때만)
    if (!_waypointEventOccurred) {
      final bool arrived = _waypointHandler.checkWaypointArrival(
        //이함수는 waypoint_event_handler에 있음.
        userLocation: userLocation,
        waypointLocation: _waypointLocation,
        forceWaypointEvent: forceWaypointEvent,
      );

      if (arrived) {
        _waypointEventOccurred = true; // 이벤트 발생 기록
        // 질문 프로바이더를 통해 질문을 비동기적으로 가져옴
        final String? question =
            await _questionProvider.getQuestionForMate(_selectedMate);

        if (question != null) {
          _waypointQuestion = question;
          print('WalkStateManager: 경유지 질문 생성 -> "$_waypointQuestion"');
          return _waypointQuestion;
        }
      }
    }

    // 목적지 이벤트 확인
    if (!_destinationEventOccurred) {
      final bool arrived = _destinationHandler.checkDestinationArrival(
        userLocation: userLocation,
        destinationLocation: _destinationLocation!,
        forceDestinationEvent: forceDestinationEvent,
      );

      if (arrived) {
        _destinationEventOccurred = true;
        print('WalkStateManager: 목적지 도착!');
        return "destination_reached";
      }
    }

    // 출발지 복귀 이벤트 확인 (목적지 이벤트가 완료된 후에만)
    if (_destinationEventOccurred && !_startReturnEventOccurred) {
      final bool returned = _checkStartArrival(
        userLocation: userLocation,
        forceStartReturnEvent: forceStartReturnEvent,
      );

      if (returned) {
        _startReturnEventOccurred = true;
        print('WalkStateManager: 출발지 복귀 완료! 산책 끝!');
        return "start_returned";
      }
    }

    return null;
  }

  // 사진 촬영 메서드
  Future<String?> takePhoto() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        print('사진 촬영 성공: ${photo.path}');
        return photo.path;
      } else {
        print('사용자가 사진 촬영을 취소했습니다.');
        return null;
      }
    } catch (e) {
      print('사진 촬영 중 오류 발생: $e');
      return null;
    }
  }

  // 출발지 복귀 확인 로직 (목적지 도착 후에만 호출됨)
  bool _checkStartArrival({
    required LatLng userLocation,
    bool forceStartReturnEvent = false,
  }) {
    if (forceStartReturnEvent) {
      // 출발지 복귀 디버그 버튼을 눌렀을 때
      return true;
    }

    if (_startLocation == null) {
      print('WalkStateManager: 출발지 위치가 설정되지 않음');
      return false;
    }

    // 출발지와 현재 위치 간의 거리 계산 (30m 반경 설정)
    const double startArrivalRadius = 30.0;
    final double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      _startLocation!.latitude,
      _startLocation!.longitude,
    );

    print('WalkStateManager: 출발지까지 거리: ${distance.toStringAsFixed(1)}m');
    return distance <= startArrivalRadius;
  }
}
