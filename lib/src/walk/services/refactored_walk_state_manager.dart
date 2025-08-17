import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/log_service.dart';
import 'waypoint_event_handler.dart';
import 'destination_event_handler.dart';
import 'waypoint_questions.dart';
import 'location_address_service.dart';
import 'photo_capture_service.dart';
import 'speech_bubble_state_service.dart';
import '../../common/utils/string_validation_utils.dart';

/// 리팩토링된 산책 상태 관리자
/// SRP를 준수하여 책임을 분리하고, 의존성 주입을 통해 테스트 가능성을 높임
class RefactoredWalkStateManager {
  // 의존성 주입을 통한 서비스 분리
  final WaypointEventHandler _waypointHandler;
  final DestinationEventHandler _destinationHandler;
  final WaypointQuestionProvider _questionProvider;
  final LocationAddressService _locationAddressService;
  final PhotoCaptureService _photoCaptureService;
  final SpeechBubbleStateService _speechBubbleService;

  // 생성자에서 의존성 주입 (테스트 가능성 향상)
  RefactoredWalkStateManager({
    WaypointEventHandler? waypointHandler,
    DestinationEventHandler? destinationHandler,
    WaypointQuestionProvider? questionProvider,
    LocationAddressService? locationAddressService,
    PhotoCaptureService? photoCaptureService,
    SpeechBubbleStateService? speechBubbleService,
  })  : _waypointHandler = waypointHandler ?? WaypointEventHandler(),
        _destinationHandler = destinationHandler ?? DestinationEventHandler(),
        _questionProvider = questionProvider ?? WaypointQuestionProvider(),
        _locationAddressService = locationAddressService ?? LocationAddressService(),
        _photoCaptureService = photoCaptureService ?? PhotoCaptureService(),
        _speechBubbleService = speechBubbleService ?? SpeechBubbleStateService();

  // 핵심 산책 상태 데이터 (private으로 캡슐화)
  LatLng? _startLocation;
  LatLng? _destinationLocation;
  LatLng? _waypointLocation;
  String? _selectedMate;
  String? _friendGroupType;
  String? _friendQuestionType;
  String? _destinationBuildingName;
  String? _customStartName;

  // 이벤트 결과 데이터
  String? _waypointQuestion;
  String? _userAnswer;
  String? _photoPath;
  String? _userReflection;
  String? _poseImageUrl;
  Uint8List? _routeSnapshotPng;
  bool _waypointEventOccurred = false;
  bool _destinationEventOccurred = false;

  // 시간 및 거리 추적
  DateTime? _actualStartTime;
  DateTime? _actualEndTime;
  LatLng? _lastUserLocation;
  double _accumulatedDistanceMeters = 0.0;
  String? _savedSessionId;

  // Public getters (필요한 것만 노출)
  LatLng? get startLocation => _startLocation;
  LatLng? get destinationLocation => _destinationLocation;
  LatLng? get waypointLocation => _waypointLocation;
  String? get selectedMate => _selectedMate;
  String? get friendGroupType => _friendGroupType;
  String? get friendQuestionType => _friendQuestionType;
  String? get waypointQuestion => _waypointQuestion;
  String? get userAnswer => _userAnswer;
  String? get photoPath => _photoPath;
  String? get userReflection => _userReflection;
  String? get poseImageUrl => _poseImageUrl;
  Uint8List? get routeSnapshotPng => _routeSnapshotPng;
  String? get destinationBuildingName => _destinationBuildingName;
  String? get customStartName => _customStartName;
  bool get isWalkComplete => _destinationEventOccurred;
  DateTime? get actualStartTime => _actualStartTime;
  DateTime? get actualEndTime => _actualEndTime;
  String? get savedSessionId => _savedSessionId;
  bool get waypointEventOccurred => _waypointEventOccurred;

  // 말풍선 관련 getters (위임)
  SpeechBubbleState? get currentSpeechBubbleState => _speechBubbleService.currentState;
  bool get speechBubbleVisible => _speechBubbleService.isVisible;

  // 계산된 속성들
  int? get actualDurationInMinutes {
    if (_actualStartTime == null || _actualEndTime == null) return null;
    return _actualEndTime!.difference(_actualStartTime!).inMinutes;
  }

  double? get accumulatedDistanceKm {
    if (_accumulatedDistanceMeters <= 0) return null;
    return _accumulatedDistanceMeters / 1000.0;
  }

  double? get walkDistance {
    if (_startLocation == null || _destinationLocation == null) return null;
    return Geolocator.distanceBetween(
      _startLocation!.latitude,
      _startLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );
  }

  /// 산책 시작 - 명확한 파라미터와 검증 로직 포함
  void startWalk({
    required LatLng startLocation,
    required LatLng destinationLocation,
    required String selectedMate,
    String? friendGroupType,
  }) {
    // 입력 데이터 검증
    if (!_isValidLocation(startLocation)) {
      throw ArgumentError('유효하지 않은 출발지 좌표입니다.');
    }
    if (!_isValidLocation(destinationLocation)) {
      throw ArgumentError('유효하지 않은 목적지 좌표입니다.');
    }
    if (selectedMate.isEmpty) {
      throw ArgumentError('동반자를 선택해주세요.');
    }

    // 상태 초기화 및 설정
    _initializeWalkState(startLocation, destinationLocation, selectedMate, friendGroupType);
    
    LogService.walkState('산책 시작 완료 - 출발지: $_startLocation, 목적지: $_destinationLocation');
  }

  /// 산책 상태 초기화 (private 메서드로 분리)
  void _initializeWalkState(
    LatLng startLocation,
    LatLng destinationLocation, 
    String selectedMate,
    String? friendGroupType,
  ) {
    _startLocation = startLocation;
    _destinationLocation = destinationLocation;
    _selectedMate = selectedMate;
    _friendGroupType = friendGroupType;
    _friendQuestionType = null;
    
    _waypointLocation = _waypointHandler.generateWaypoint(startLocation, destinationLocation);
    
    // 이벤트 상태 초기화
    _waypointEventOccurred = false;
    _destinationEventOccurred = false;
    
    // 데이터 초기화
    _clearEventData();
    
    // 시간 및 거리 추적 초기화
    _actualStartTime = DateTime.now();
    _actualEndTime = null;
    _accumulatedDistanceMeters = 0.0;
    _lastUserLocation = null;
    
    // 말풍선 상태 초기화
    _speechBubbleService.reset();
    
    LogService.walkState('실제 산책 시작 시간 기록: $_actualStartTime');
  }

  /// 이벤트 관련 데이터 초기화
  void _clearEventData() {
    _waypointQuestion = null;
    _userAnswer = null;
    _photoPath = null;
    _userReflection = null;
    _poseImageUrl = null;
    _routeSnapshotPng = null;
    _savedSessionId = null;
    _destinationBuildingName = null;
    _customStartName = null;
  }

  /// 실시간 위치 업데이트 처리
  Future<String?> updateUserLocation(
    LatLng userLocation, {
    bool forceWaypointEvent = false,
    bool forceDestinationEvent = false,
  }) async {
    try {
      // 위치 유효성 검증
      if (!_isValidLocation(userLocation)) {
        LogService.warning('WalkState', '유효하지 않은 위치 데이터: $userLocation');
        return null;
      }

      // 누적 거리 업데이트
      _updateAccumulatedDistance(userLocation);

      // 말풍선 상태 업데이트
      _updateSpeechBubbleState(userLocation);

      // 경유지 이벤트 확인
      final waypointResult = await _checkWaypointEvent(userLocation, forceWaypointEvent);
      if (waypointResult != null) return waypointResult;

      // 목적지 이벤트 확인
      final destinationResult = _checkDestinationEvent(userLocation, forceDestinationEvent);
      if (destinationResult != null) return destinationResult;

      return null;
    } catch (e) {
      LogService.error('WalkState', '위치 업데이트 중 오류 발생', e);
      return null;
    }
  }

  /// 누적 거리 계산 및 업데이트
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

      if (segmentDistance.isFinite && segmentDistance > 0) {
        _accumulatedDistanceMeters += segmentDistance;
      }

      _lastUserLocation = currentLocation;
    } catch (e) {
      LogService.error('WalkState', '누적 거리 계산 실패', e);
    }
  }

  /// 말풍선 상태 업데이트 (서비스에 위임)
  void _updateSpeechBubbleState(LatLng currentLocation) {
    if (_startLocation == null || _destinationLocation == null || _waypointLocation == null) {
      return;
    }

    _speechBubbleService.updateState(
      currentPosition: currentLocation,
      startLocation: _startLocation!,
      waypointLocation: _waypointLocation!,
      destinationLocation: _destinationLocation!,
      waypointEventCompleted: _waypointEventOccurred,
    );
  }

  /// 경유지 이벤트 확인 및 처리
  Future<String?> _checkWaypointEvent(LatLng userLocation, bool forceEvent) async {
    if (_waypointEventOccurred) return null;

    final hasArrived = _waypointHandler.checkWaypointArrival(
      userLocation: userLocation,
      waypointLocation: _waypointLocation,
      forceWaypointEvent: forceEvent,
    );

    if (!hasArrived) return null;

    _waypointEventOccurred = true;
    _speechBubbleService.completeWaypointEvent();

    // 질문 생성
    final question = await _questionProvider.getQuestionForMate(
      _selectedMate,
      friendGroupType: _friendGroupType,
      friendQuestionType: _friendQuestionType,
    );

    if (question != null) {
      _waypointQuestion = question;
      LogService.walkState('경유지 질문 생성: "$_waypointQuestion"');
      return _waypointQuestion;
    }

    return null;
  }

  /// 목적지 이벤트 확인 및 처리
  String? _checkDestinationEvent(LatLng userLocation, bool forceEvent) {
    if (_destinationEventOccurred) return null;

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
  }

  /// 위치 좌표 유효성 검증
  bool _isValidLocation(LatLng location) {
    return location.latitude.abs() <= 90.0 && 
           location.longitude.abs() <= 180.0 &&
           location.latitude != 0.0 && 
           location.longitude != 0.0;
  }

  /// 사진 촬영 (서비스에 위임)
  Future<String?> takePhoto() async {
    return await _photoCaptureService.takePhoto();
  }

  /// 답변 및 사진 저장 (개선된 인터페이스)
  void saveUserAnswerAndPhoto({
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

    LogService.walkState('답변 저장: "$_userAnswer"');
    LogService.walkState('사진 경로 저장: "$_photoPath"');
  }

  /// 목적지 건물명 설정 (유틸리티 사용)
  void setDestinationBuildingName(String? buildingName) {
    _destinationBuildingName = StringValidationUtils.sanitizeString(buildingName);
    LogService.walkState('목적지 건물명 설정: "$_destinationBuildingName"');
  }

  /// 사용자 지정 출발지 이름 설정 (유틸리티 사용)
  void setCustomStartName(String? name) {
    _customStartName = StringValidationUtils.sanitizeString(name);
    LogService.walkState('사용자 지정 출발지 이름 설정: "$_customStartName"');
  }

  /// 주소 정보 가져오기 메서드들 (서비스에 위임)
  Future<String> getStartLocationAddress() async {
    if (_startLocation == null) return '출발지 정보 없음';
    if (_customStartName != null && _customStartName!.isNotEmpty) {
      return _customStartName!;
    }
    return await _locationAddressService.convertCoordinateToAddress(_startLocation!);
  }

  Future<String?> getWaypointLocationAddress() async {
    if (_waypointLocation == null) return null;
    return await _locationAddressService.convertCoordinateToAddress(_waypointLocation!);
  }

  Future<String> getDestinationLocationAddress() async {
    if (_destinationLocation == null) return '목적지 정보 없음';

    if (_destinationBuildingName != null && _destinationBuildingName!.isNotEmpty) {
      return _destinationBuildingName!;
    }

    return await _locationAddressService.convertCoordinateToAddress(_destinationLocation!);
  }

  // 기타 설정 메서드들 (간단한 setter들)
  void savePoseImageUrl(String? url) {
    _poseImageUrl = url;
    LogService.walkState('추천 포즈 URL 저장: "$_poseImageUrl"');
  }

  void saveRouteSnapshot(Uint8List? pngBytes) {
    _routeSnapshotPng = pngBytes;
    LogService.walkState('경로 스냅샷 저장 여부: ${pngBytes != null}');
  }

  void saveReflection(String? reflection) {
    _userReflection = reflection;
    LogService.walkState('소감 저장: "$_userReflection"');
  }

  void setWaypointQuestion(String? question) {
    _waypointQuestion = question;
    LogService.walkState('경유지 질문 설정: "$_waypointQuestion"');
  }

  void setSavedSessionId(String sessionId) {
    _savedSessionId = sessionId;
    LogService.walkState('저장된 세션 ID 설정: "$_savedSessionId"');
  }

  void setFriendQuestionType(String? questionType) {
    _friendQuestionType = questionType;
    LogService.walkState('친구 질문 타입 설정: "$_friendQuestionType"');
  }

  // 말풍선 관련 메서드들 (서비스에 위임)
  void setSpeechBubbleVisible(bool visible) {
    _speechBubbleService.setVisible(visible);
  }

  void setDebugSpeechBubbleState(SpeechBubbleState state) {
    _speechBubbleService.setDebugState(state);
  }

  void completeWaypointEvent() {
    _speechBubbleService.completeWaypointEvent();
  }

  /// 기록 보기를 위한 위치 정보 복원
  void setLocationsForRestore({
    required LatLng start,
    required LatLng waypoint,
    required LatLng destination,
  }) {
    _startLocation = start;
    _waypointLocation = waypoint;
    _destinationLocation = destination;
    LogService.walkState('위치 정보 복원 완료');
  }
}