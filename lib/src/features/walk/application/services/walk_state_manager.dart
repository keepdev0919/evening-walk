import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'waypoint_event_handler.dart';
import 'destination_event_handler.dart';
import 'start_return_event_handler.dart';
import 'waypoint_questions.dart';
import 'package:image_picker/image_picker.dart';

class WalkStateManager {
  // 핸들러 및 프로바이더 인스턴스
  final WaypointEventHandler _waypointHandler = WaypointEventHandler();
  final DestinationEventHandler _destinationHandler = DestinationEventHandler();
  final StartReturnEventHandler _startReturnHandler = StartReturnEventHandler();
  final WaypointQuestionProvider _questionProvider = WaypointQuestionProvider();

  // 산책 상태 변수
  LatLng? _startLocation; // 출발지 위치 추가
  LatLng? _destinationLocation;
  LatLng? _waypointLocation;
  String? _selectedMate;

  // 이벤트 결과 저장 변수
  String? _waypointQuestion;
  String? _userAnswer;
  String? _photoPath;
  String? _userReflection;
  bool _waypointEventOccurred = false;
  bool _destinationEventOccurred = false;
  bool _startReturnEventOccurred = false; // 출발지 복귀 이벤트 상태 추가
  bool _isReturningHome = false; // 목적지에서 출발지로 돌아가는 중인지 여부
  
  // 실제 산책 시간 추적
  DateTime? _actualStartTime;
  DateTime? _actualEndTime;

  // --- Public Getters ---
  LatLng? get startLocation => _startLocation;
  LatLng? get waypointLocation => _waypointLocation;
  String? get waypointQuestion => _waypointQuestion;
  String? get userAnswer => _userAnswer;
  String? get photoPath => _photoPath;
  String? get userReflection => _userReflection;
  String? get selectedMate => _selectedMate;
  bool get isWalkComplete => _startReturnEventOccurred;
  DateTime? get actualStartTime => _actualStartTime;
  DateTime? get actualEndTime => _actualEndTime;
  
  // 실제 산책 소요 시간 계산 (분 단위)
  int? get actualDurationInMinutes {
    if (_actualStartTime == null || _actualEndTime == null) return null;
    return _actualEndTime!.difference(_actualStartTime!).inMinutes;
  }

  // 답변 및 사진 저장 메소드
  void saveAnswerAndPhoto({String? answer, String? photoPath}) {
    _userAnswer = answer;
    _photoPath = photoPath;
    print('WalkStateManager: 답변 저장 -> "$_userAnswer"');
    print('WalkStateManager: 사진 경로 저장 -> "$_photoPath"');
  }

  // 소감 저장 메소드
  void saveReflection(String? reflection) {
    _userReflection = reflection;
    print('WalkStateManager: 소감 저장 -> "$_userReflection"');
  }

  // 경유지 질문 설정 메소드 (기록 조회용)
  void setWaypointQuestion(String? question) {
    _waypointQuestion = question;
    print('WalkStateManager: 경유지 질문 설정 -> "$_waypointQuestion"');
  }

  // 산책 시작 시 초기화
  void startWalk({
    required LatLng start,
    required LatLng destination,
    required String mate,
  }) {
    _startLocation = start; // 출발지 위치 저장
    _destinationLocation = destination;
    _selectedMate = mate;
    _waypointLocation = _waypointHandler.generateWaypoint(start, destination);
    _waypointEventOccurred = false;
    _destinationEventOccurred = false;
    _startReturnEventOccurred = false; // 출발지 복귀 상태 초기화
    _isReturningHome = false; // 초기화
    _waypointQuestion = null;
    _userAnswer = null;
    _photoPath = null;
    _userReflection = null;
    
    // 실제 산책 시작 시간 기록
    _actualStartTime = DateTime.now();
    _actualEndTime = null; // 초기화
    print('WalkStateManager: 실제 산책 시작 시간 기록 -> $_actualStartTime');
    print(
        'WalkStateManager: 산책 시작. 출발지: $_startLocation, 경유지: $_waypointLocation');
  }

  // 목적지에서 출발지로 돌아가기 시작
  void startReturningHome() {
    _isReturningHome = true;
    print('WalkStateManager: 이제 출발지로 돌아갑니다.');
  }

  // 실시간 위치 업데이트 처리 (Future<String?>으로 변경)
  Future<String?> updateUserLocation(
    LatLng userLocation, {
    bool forceWaypointEvent = false,
    bool forceDestinationEvent = false,
    bool forceStartReturnEvent = false,
  }) async {
    // 경유지 이벤트 확인 (아직 발생하지 않았을 때만)
    if (!_waypointEventOccurred) {
      final bool arrived = _waypointHandler.checkWaypointArrival(
        userLocation: userLocation,
        waypointLocation: _waypointLocation,
        forceWaypointEvent: forceWaypointEvent,
      );

      if (arrived) {
        _waypointEventOccurred = true;
        final String? question =
            await _questionProvider.getQuestionForMate(_selectedMate);

        if (question != null) {
          _waypointQuestion = question;
          print('WalkStateManager: 경유지 질문 생성 -> "$_waypointQuestion"');
          return _waypointQuestion;
        }
      }
    }

    // 목적지 이벤트 확인 (아직 발생하지 않았을 때만)
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

    // 출발지 복귀 이벤트 확인 (목적지 이벤트가 완료되고, 돌아오는 중일 때만)
    if (_destinationEventOccurred &&
        _isReturningHome &&
        !_startReturnEventOccurred) {
      final bool returned = _startReturnHandler.checkStartArrival(
        userLocation: userLocation,
        startLocation: _startLocation!,
        forceStartReturnEvent: forceStartReturnEvent,
      );

      if (returned) {
        _startReturnEventOccurred = true;
        _actualEndTime = DateTime.now(); // 실제 산책 종료 시간 기록
        print('WalkStateManager: 출발지 복귀 완료! 산책 끝!');
        print('WalkStateManager: 실제 산책 종료 시간 기록 -> $_actualEndTime');
        print('WalkStateManager: 총 산책 시간: ${actualDurationInMinutes}분');
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

}
