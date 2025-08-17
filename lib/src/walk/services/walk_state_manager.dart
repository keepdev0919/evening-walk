import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'waypoint_event_handler.dart';
import 'destination_event_handler.dart';
import 'firestore_question_service.dart';
import 'location_address_service.dart';
import 'photo_capture_service.dart';
import 'speech_bubble_state_service.dart';
import '../../core/services/log_service.dart';
import '../../common/utils/string_validation_utils.dart';

class WalkStateManager {
  // 핸들러 및 프로바이더 인스턴스
  final WaypointEventHandler _waypointHandler = WaypointEventHandler();
  final DestinationEventHandler _destinationHandler = DestinationEventHandler();
  final FirestoreQuestionService _questionService = FirestoreQuestionService();

  // 새로운 서비스 인스턴스들
  final LocationAddressService _locationAddressService =
      LocationAddressService();
  final PhotoCaptureService _photoCaptureService = PhotoCaptureService();
  final SpeechBubbleStateService _speechBubbleService =
      SpeechBubbleStateService();

  // 산책 상태 변수
  LatLng? _startLocation; // 출발지 위치 추가
  LatLng? _destinationLocation;
  LatLng? _waypointLocation;
  String? _selectedMate;
  String? _friendGroupType; // 친구 인원 구분: 'two' or 'many'
  String? _friendQuestionType; // 친구 질문 타입: 'game' or 'talk'
  String? _coupleQuestionType; // 연인 질문 타입: 'talk' or 'balance'
  String? _destinationBuildingName; // 목적지 건물명
  String? _customStartName; // 사용자 지정 출발지 이름

  // 이벤트 결과 저장 변수
  String? _waypointQuestion;
  String? _userAnswer;
  String? _photoPath;
  String? _userReflection;
  String? _poseImageUrl; // 목적지 추천 포즈 이미지 URL 저장
  Uint8List? _routeSnapshotPng; // 정적 지도 캡처 PNG
  bool _waypointEventOccurred = false;
  bool _destinationEventOccurred = false;

  // 실제 산책 시간 추적
  DateTime? _actualStartTime;
  DateTime? _actualEndTime;

  // 누적 이동 거리 추적 (미터 단위)
  LatLng? _lastUserLocation; // 마지막으로 기록된 사용자 위치
  double _accumulatedDistanceMeters = 0.0; // 누적 이동 거리 (m)

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
  String? get friendGroupType => _friendGroupType;
  String? get friendQuestionType => _friendQuestionType;
  String? get coupleQuestionType => _coupleQuestionType;
  String? get poseImageUrl => _poseImageUrl;
  Uint8List? get routeSnapshotPng => _routeSnapshotPng;
  String? get destinationBuildingName => _destinationBuildingName;
  String? get customStartName => _customStartName;
  bool get isWalkComplete => _destinationEventOccurred; // 목적지 도착 시 산책 완료
  DateTime? get actualStartTime => _actualStartTime;
  DateTime? get actualEndTime => _actualEndTime;
  String? get savedSessionId => _savedSessionId;

  // 말풍선 관련 getters (서비스에 위임)
  SpeechBubbleState? get currentSpeechBubbleState =>
      _speechBubbleService.currentState;
  bool get speechBubbleVisible => _speechBubbleService.isVisible;

  /// 경유지 이벤트 발생 여부 (경유지 도착 알림 트리거 여부)
  bool get waypointEventOccurred => _waypointEventOccurred;

  // 실제 산책 소요 시간 계산 (분 단위)
  int? get actualDurationInMinutes {
    if (_actualStartTime == null || _actualEndTime == null) return null;
    return _actualEndTime!.difference(_actualStartTime!).inMinutes;
  }

  /// 누적 이동 거리 (km). 0에 가까우면 null 처리하여 표시를 생략할 수 있도록 함
  double? get accumulatedDistanceKm {
    if (_accumulatedDistanceMeters <= 0) return null;
    return _accumulatedDistanceMeters / 1000.0;
  }

  // 출발지-목적지 직선거리 계산 (미터 단위)
  double? get walkDistance {
    if (_startLocation == null || _destinationLocation == null) return null;
    return Geolocator.distanceBetween(
      _startLocation!.latitude,
      _startLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );
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

  /// 산책 경로 정적 지도 PNG 저장
  void saveRouteSnapshot(Uint8List? pngBytes) {
    _routeSnapshotPng = pngBytes;
    LogService.walkState(' 경로 스냅샷 저장 여부 -> ${pngBytes != null}');
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
    _destinationBuildingName =
        StringValidationUtils.sanitizeString(buildingName);
    LogService.walkState(' 목적지 건물명 설정 -> "$_destinationBuildingName"');
  }

  /// 사용자 지정 출발지 이름 설정 메소드
  void setCustomStartName(String? name) {
    _customStartName = StringValidationUtils.sanitizeString(name);
    LogService.walkState(' 사용자 지정 출발지 이름 설정 -> "$_customStartName"');
  }

  /// 친구 질문 타입 설정 메소드 (게임 또는 talk)
  void setFriendQuestionType(String? questionType) {
    _friendQuestionType = questionType;
    LogService.walkState(' 친구 질문 타입 설정 -> "$_friendQuestionType"');
    LogService.info('Walk', '친구 질문 타입 설정 완료: $_friendQuestionType');
  }

  /// 연인 질문 타입 설정 메소드 (talk 또는 balance)
  void setCoupleQuestionType(String? questionType) {
    _coupleQuestionType = questionType;
    LogService.walkState(' 연인 질문 타입 설정 -> "$_coupleQuestionType"');
    LogService.info('Walk', '연인 질문 타입 설정 완료: $_coupleQuestionType');
  }

  /// 현재 설정된 메이트와 타입에 맞는 새로운 질문을 가져오는 메소드
  Future<String?> getNewQuestion() async {
    LogService.info('Walk', 'getNewQuestion 호출 - selectedMate: $_selectedMate, coupleQuestionType: $_coupleQuestionType, friendQuestionType: $_friendQuestionType');
    return await _questionService.getQuestionForMate(
      _selectedMate,
      friendGroupType: _friendGroupType,
      friendQuestionType: _friendQuestionType,
      coupleQuestionType: _coupleQuestionType,
    );
  }

  // 산책 시작 시 초기화
  Future<void> startWalk({
    required LatLng start,
    required LatLng destination,
    required String mate,
    String? friendGroupType,
  }) async {
    _startLocation = start; // 출발지 위치 저장
    _destinationLocation = destination;
    _selectedMate = mate;
    _friendGroupType = friendGroupType;
    _friendQuestionType = null; // 초기화
    _coupleQuestionType = null; // 초기화
    _waypointLocation = _waypointHandler.generateWaypoint(start, destination);
    _waypointEventOccurred = false;
    _destinationEventOccurred = false;

    _waypointQuestion = null;
    _userAnswer = null;
    _photoPath = null;

    // 말풍선 초기화
    _speechBubbleService.reset();
    _userReflection = null;
    _poseImageUrl = null;
    _savedSessionId = null;
    _destinationBuildingName = null;
    _customStartName = null;

    // 실제 산책 시작 시간 기록
    _actualStartTime = DateTime.now();
    _actualEndTime = null; // 초기화
    // 누적 거리 초기화
    _accumulatedDistanceMeters = 0.0;
    _lastUserLocation = null;

    LogService.walkState(' 실제 산책 시작 시간 기록 -> $_actualStartTime');
    LogService.walkState(
        '산책 시작. 출발지: $_startLocation, 경유지: $_waypointLocation');
  }

  // 실시간 위치 업데이트 처리 (에러 핸들링 강화)
  Future<String?> updateUserLocation(
    LatLng userLocation, {
    bool forceWaypointEvent = false,
    bool forceDestinationEvent = false,
  }) async {
    try {
      // 입력 데이터 검증
      if (!_isValidLocation(userLocation)) {
        LogService.warning('WalkState', '유효하지 않은 위치 데이터: $userLocation');
        return null;
      }

      // 산책이 시작되었는지 확인
      if (_startLocation == null || _destinationLocation == null) {
        LogService.warning('WalkState', '산책이 시작되지 않았습니다');
        return null;
      }

      // 누적 이동 거리 갱신
      _updateAccumulatedDistance(userLocation);

      // 말풍선 상태 업데이트
      _updateSpeechBubbleState(userLocation);

      // 경유지 이벤트 확인
      final waypointResult =
          await _checkWaypointEvent(userLocation, forceWaypointEvent);
      if (waypointResult != null) return waypointResult;

      // 목적지 이벤트 확인
      final destinationResult =
          _checkDestinationEvent(userLocation, forceDestinationEvent);
      if (destinationResult != null) return destinationResult;

      return null;
    } catch (e) {
      LogService.error('WalkState', '위치 업데이트 중 오류 발생', e);
      return null;
    }
  }

  // 사진 촬영 메서드 (서비스에 위임)
  Future<String?> takePhoto() async {
    return await _photoCaptureService.takePhoto();
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
    LogService.walkState('출발지: $_startLocation');
    LogService.walkState('경유지: $_waypointLocation');
    LogService.walkState('목적지: $_destinationLocation');
  }

  /// 출발지 주소 가져오기
  Future<String> getStartLocationAddress() async {
    if (_startLocation == null) return '출발지 정보 없음';
    if (_customStartName != null && _customStartName!.trim().isNotEmpty) {
      return _customStartName!;
    }
    return await _locationAddressService
        .convertCoordinateToAddress(_startLocation!);
  }

  /// 경유지 주소 가져오기
  Future<String?> getWaypointLocationAddress() async {
    if (_waypointLocation == null) return null;
    return await _locationAddressService
        .convertCoordinateToAddress(_waypointLocation!);
  }

  /// 목적지 주소 가져오기 (건물명이 있으면 우선 표시)
  Future<String> getDestinationLocationAddress() async {
    LogService.walkState(' getDestinationLocationAddress 호출');
    LogService.walkState('_destinationLocation: $_destinationLocation');
    LogService.walkState('_destinationBuildingName: $_destinationBuildingName');

    if (_destinationLocation == null) return '목적지 정보 없음';

    // 건물명이 있으면 우선 표시
    bool _isInvalidPlaceholder(String? value) {
      if (value == null) return true;
      final t = value.trim();
      if (t.isEmpty) return true;
      return t == '.' || t == '·' || t == '-';
    }

    if (_destinationBuildingName != null &&
        !_isInvalidPlaceholder(_destinationBuildingName)) {
      return _destinationBuildingName!;
    }

    // 건물명이 없으면 주소로 fallback
    return await _locationAddressService
        .convertCoordinateToAddress(_destinationLocation!);
  }

  // --- 말풍선 관련 메서드들 (서비스에 위임) ---

  /// 현재 위치를 기반으로 말풍선 상태를 업데이트합니다.
  void _updateSpeechBubbleState(LatLng currentPosition) {
    if (_startLocation == null ||
        _destinationLocation == null ||
        _waypointLocation == null) {
      return;
    }

    _speechBubbleService.updateState(
      currentPosition: currentPosition,
      startLocation: _startLocation!,
      waypointLocation: _waypointLocation!,
      destinationLocation: _destinationLocation!,
      waypointEventCompleted: _waypointEventOccurred,
    );
  }

  /// 개발자 전용: 말풍선 상태를 강제로 설정합니다. (디버그 모드에서만 작동)
  void setDebugSpeechBubbleState(SpeechBubbleState state) {
    _speechBubbleService.setDebugState(state);
  }

  /// 말풍선 표시 여부를 설정합니다.
  void setSpeechBubbleVisible(bool visible) {
    _speechBubbleService.setVisible(visible);
  }

  /// 경유지 이벤트 확인 후 말풍선 상태를 변경합니다.
  void completeWaypointEvent() {
    _speechBubbleService.completeWaypointEvent();
  }

  // --- 추가된 유틸리티 메서드들 ---

  /// 위치 좌표 유효성 검증
  bool _isValidLocation(LatLng location) {
    return location.latitude.abs() <= 90.0 &&
        location.longitude.abs() <= 180.0 &&
        location.latitude != 0.0 &&
        location.longitude != 0.0;
  }

  /// 누적 거리 계산 및 업데이트 (기존 로직 분리)
  void _updateAccumulatedDistance(LatLng currentLocation) {
    try {
      if (_lastUserLocation == null) {
        _lastUserLocation = currentLocation;
        return;
      }

      final segmentDistance = Geolocator.distanceBetween(
        _lastUserLocation!.latitude,
        _lastUserLocation!.longitude,
        currentLocation.latitude,
        currentLocation.longitude,
      );

      if (segmentDistance.isFinite &&
          segmentDistance > 0 &&
          segmentDistance < 1000) {
        // 1km 이상의 갑작스러운 이동은 GPS 오류로 간주하여 무시
        _accumulatedDistanceMeters += segmentDistance;
      }

      _lastUserLocation = currentLocation;
    } catch (e) {
      LogService.error('WalkState', '누적 거리 계산 실패', e);
    }
  }

  /// 경유지 이벤트 확인 및 처리 (기존 로직 분리)
  Future<String?> _checkWaypointEvent(
      LatLng userLocation, bool forceEvent) async {
    if (_waypointEventOccurred) return null;

    try {
      final hasArrived = _waypointHandler.checkWaypointArrival(
        userLocation: userLocation,
        waypointLocation: _waypointLocation,
        forceWaypointEvent: forceEvent,
      );

      if (!hasArrived) return null;

      _waypointEventOccurred = true;
      LogService.info('Walk', '경유지 도착! 질문은 사용자 선택 후 생성됩니다.');
      
      // 더미 질문 반환 (실제 질문은 다이얼로그에서 생성)
      return "waypoint_arrived";
    } catch (e) {
      LogService.error('WalkState', '경유지 이벤트 처리 중 오류', e);
      return null;
    }
  }

  /// 목적지 이벤트 확인 및 처리 (기존 로직 분리)
  String? _checkDestinationEvent(LatLng userLocation, bool forceEvent) {
    if (_destinationEventOccurred) return null;

    try {
      final hasArrived = _destinationHandler.checkDestinationArrival(
        userLocation: userLocation,
        destinationLocation: _destinationLocation!,
        forceDestinationEvent: forceEvent,
      );

      if (!hasArrived) return null;

      _destinationEventOccurred = true;
      _actualEndTime = DateTime.now();
      LogService.walkState('목적지 도착! 실제 종료 시간: $_actualEndTime');

      return "destination_reached";
    } catch (e) {
      LogService.error('WalkState', '목적지 이벤트 처리 중 오류', e);
      return null;
    }
  }
}
