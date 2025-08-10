import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'waypoint_event_handler.dart';
import 'destination_event_handler.dart';
import 'start_return_event_handler.dart';
import 'waypoint_questions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/services/log_service.dart';

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
  String? _destinationBuildingName; // 목적지 건물명

  // 이벤트 결과 저장 변수
  String? _waypointQuestion;
  String? _userAnswer;
  String? _photoPath;
  String? _userReflection;
  String? _poseImageUrl; // 목적지 추천 포즈 이미지 URL 저장
  bool _waypointEventOccurred = false;
  bool _destinationEventOccurred = false;
  bool _startReturnEventOccurred = false; // 출발지 복귀 이벤트 상태 추가
  bool _isReturningHome = false; // 목적지에서 출발지로 돌아가는 중인지 여부

  // 실제 산책 시간 추적
  DateTime? _actualStartTime;
  DateTime? _actualEndTime;

  // 저장된 세션 ID (1차 저장 후 업데이트용)
  String? _savedSessionId;

  // --- Public Getters ---
  LatLng? get startLocation => _startLocation;
  LatLng? get waypointLocation => _waypointLocation;
  String? get waypointQuestion => _waypointQuestion;
  String? get userAnswer => _userAnswer;
  String? get photoPath => _photoPath;
  String? get userReflection => _userReflection;
  String? get selectedMate => _selectedMate;
  String? get poseImageUrl => _poseImageUrl;
  String? get destinationBuildingName => _destinationBuildingName;
  bool get isWalkComplete => _startReturnEventOccurred;
  DateTime? get actualStartTime => _actualStartTime;
  DateTime? get actualEndTime => _actualEndTime;
  String? get savedSessionId => _savedSessionId;

  // 실제 산책 소요 시간 계산 (분 단위)
  int? get actualDurationInMinutes {
    if (_actualStartTime == null || _actualEndTime == null) return null;
    return _actualEndTime!.difference(_actualStartTime!).inMinutes;
  }

  /// 답변 및 사진 저장 메소드
  ///
  /// 역할: 주어진 파라미터만 선택적으로 반영합니다. null이 전달되었더라도
  ///       기본적으로는 기존 값을 보존하며, 명시적으로 지울 때는 clear 플래그를 사용합니다.
  ///
  /// - answer: 업데이트할 답변 (null이면 기본적으로 변경 없음)
  /// - photoPath: 업데이트할 사진 경로 (null이면 기본적으로 변경 없음)
  /// - clearAnswer: true인 경우 답변을 명시적으로 null로 초기화
  /// - clearPhoto: true인 경우 사진 경로를 명시적으로 null로 초기화
  void saveAnswerAndPhoto({
    String? answer,
    String? photoPath,
    bool clearAnswer = false,
    bool clearPhoto = false,
  }) {
    if (clearAnswer) {
      _userAnswer = null;
    } else if (answer != null) {
      _userAnswer = answer;
    }

    if (clearPhoto) {
      _photoPath = null;
    } else if (photoPath != null) {
      _photoPath = photoPath;
    }

    LogService.walkState(' 답변 저장 -> "$_userAnswer"');
    LogService.walkState(' 사진 경로 저장 -> "$_photoPath"');
  }

  // 목적지 추천 포즈 이미지 URL 저장 메소드
  void savePoseImageUrl(String? url) {
    _poseImageUrl = url;
    LogService.walkState(' 추천 포즈 URL 저장 -> "$_poseImageUrl"');
  }

  // 소감 저장 메소드
  void saveReflection(String? reflection) {
    _userReflection = reflection;
    LogService.walkState(' 소감 저장 -> "$_userReflection"');
  }

  // 경유지 질문 설정 메소드 (기록 조회용)
  void setWaypointQuestion(String? question) {
    _waypointQuestion = question;
    LogService.walkState(' 경유지 질문 설정 -> "$_waypointQuestion"');
  }

  // 저장된 세션 ID 설정 메소드 (1차 저장 후)
  void setSavedSessionId(String sessionId) {
    _savedSessionId = sessionId;
    LogService.walkState(' 저장된 세션 ID 설정 -> "$_savedSessionId"');
  }

  // 목적지 건물명 설정 메소드
  void setDestinationBuildingName(String? buildingName) {
    _destinationBuildingName = buildingName;
    LogService.walkState(' 목적지 건물명 설정 -> "$_destinationBuildingName"');
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
    _poseImageUrl = null;
    _savedSessionId = null;
    _destinationBuildingName = null;

    // 실제 산책 시작 시간 기록
    _actualStartTime = DateTime.now();
    _actualEndTime = null; // 초기화
    LogService.walkState(' 실제 산책 시작 시간 기록 -> $_actualStartTime');
    print(
        'WalkStateManager: 산책 시작. 출발지: $_startLocation, 경유지: $_waypointLocation');
  }

  // 목적지에서 출발지로 돌아가기 시작
  void startReturningHome() {
    _isReturningHome = true;
    LogService.walkState(' 이제 출발지로 돌아갑니다.');
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
          LogService.walkState(' 경유지 질문 생성 -> "$_waypointQuestion"');
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
        LogService.walkState(' 목적지 도착!');
        return "destination_reached";
      }
    }

    // 출발지 복귀 이벤트 확인 (목적지 이벤트가 완료되고, 돌아오는 중일 때만)
    LogService.walkState(
        ' 출발지 복귀 체크 - _destinationEventOccurred: $_destinationEventOccurred');
    LogService.walkState(' 출발지 복귀 체크 - _isReturningHome: $_isReturningHome');
    LogService.walkState(
        ' 출발지 복귀 체크 - _startReturnEventOccurred: $_startReturnEventOccurred');

    if (_destinationEventOccurred &&
        _isReturningHome &&
        !_startReturnEventOccurred) {
      LogService.walkState(' 출발지 복귀 조건 만족 - 거리 체크 중...');
      final bool returned = _startReturnHandler.checkStartArrival(
        userLocation: userLocation,
        startLocation: _startLocation!,
        forceStartReturnEvent: forceStartReturnEvent,
      );

      if (returned) {
        _startReturnEventOccurred = true;
        _actualEndTime = DateTime.now(); // 실제 산책 종료 시간 기록
        LogService.walkState(' 출발지 복귀 완료! 산책 끝!');
        LogService.walkState(' 실제 산책 종료 시간 기록 -> $_actualEndTime');
        LogService.walkState(' 총 산책 시간: ${actualDurationInMinutes}분');
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
        LogService.info('WalkState', '사진 촬영 성공: ${photo.path}');
        return photo.path;
      } else {
        LogService.info('WalkState', '사용자가 사진 촬영을 취소했습니다.');
        return null;
      }
    } catch (e) {
      LogService.error('WalkState', '사진 촬영 중 오류 발생', e);
      return null;
    }
  }

  // === 위치 정보 관련 메소드 ===
  LatLng? get destinationLocation => _destinationLocation;

  /// 기록 보기 복원을 위해 외부에서 좌표를 주입할 수 있는 세터
  void setLocationsForRestore({
    required LatLng start,
    required LatLng waypoint,
    required LatLng destination,
  }) {
    _startLocation = start;
    _waypointLocation = waypoint;
    _destinationLocation = destination;
    LogService.walkState(' 위치 정보 복원 완료');
    print('출발지: $_startLocation');
    print('경유지: $_waypointLocation');
    print('목적지: $_destinationLocation');
  }

  /// 좌표를 주소로 변환하는 메소드
  Future<String> _convertCoordinateToAddress(LatLng coordinate) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinate.latitude,
        coordinate.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        // 한국 주소 형식: 시/도 구/군 동 (상세 주소 제외)
        String address = '';

        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          address += '${place.administrativeArea} ';
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address += '${place.locality} ';
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          address += place.subLocality!;
        }

        return address.trim().isNotEmpty ? address.trim() : '알 수 없는 위치';
      }
    } catch (e) {
      LogService.error('WalkState', '주소 변환 실패', e);
    }

    // fallback으로 좌표 표시
    return '${coordinate.latitude.toStringAsFixed(4)}, ${coordinate.longitude.toStringAsFixed(4)}';
  }

  /// 출발지 주소 가져오기
  Future<String> getStartLocationAddress() async {
    if (_startLocation == null) return '출발지 정보 없음';
    return await _convertCoordinateToAddress(_startLocation!);
  }

  /// 경유지 주소 가져오기
  Future<String?> getWaypointLocationAddress() async {
    if (_waypointLocation == null) return null;
    return await _convertCoordinateToAddress(_waypointLocation!);
  }

  /// 목적지 주소 가져오기 (건물명이 있으면 우선 표시)
  Future<String> getDestinationLocationAddress() async {
    LogService.walkState(' getDestinationLocationAddress 호출');
    print('_destinationLocation: $_destinationLocation');
    print('_destinationBuildingName: $_destinationBuildingName');

    if (_destinationLocation == null) return '목적지 정보 없음';

    // 건물명이 있으면 우선 표시
    if (_destinationBuildingName != null &&
        _destinationBuildingName!.isNotEmpty) {
      return _destinationBuildingName!;
    }

    // 건물명이 없으면 주소로 fallback
    return await _convertCoordinateToAddress(_destinationLocation!);
  }
}
