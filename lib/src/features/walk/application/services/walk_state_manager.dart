import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'waypoint_event_handler.dart';
import 'destination_event_handler.dart';
import 'start_return_event_handler.dart';
import 'waypoint_questions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/services/log_service.dart';

/// 말풍선 상태를 나타내는 enum
enum SpeechBubbleState {
  toWaypoint("산책 가보자고 ~"), // 출발지~경유지절반
  almostWaypoint("선물.. 선물.. 선물.. "), // 경유지 도착 절반 전
  waypointEventCompleted("뚜비두밥~♪"), // 경유지 이벤트 확인 후
  almostDestination("고지가 코앞이다 !!"), // 목적지 도착 절반 전
  returning("이제 집가자 ~"), // 목적지→출발지 복귀 시작
  almostHome("거의 다왔다 !!"); // 출발지 도착 절반 전

  const SpeechBubbleState(this.message);
  final String message;
}

/// 산책 방식
enum WalkMode { roundTrip, oneWay }

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
  String? _friendGroupType; // 친구 인원 구분: 'two' or 'many'
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
  bool _startReturnEventOccurred = false; // 출발지 복귀 이벤트 상태 추가
  bool _isReturningHome = false; // 목적지에서 출발지로 돌아가는 중인지 여부
  WalkMode _mode = WalkMode.roundTrip; // 기본은 왕복

  // 실제 산책 시간 추적
  DateTime? _actualStartTime;
  DateTime? _actualEndTime;

  // 누적 이동 거리 추적 (미터 단위)
  LatLng? _lastUserLocation; // 마지막으로 기록된 사용자 위치
  double _accumulatedDistanceMeters = 0.0; // 누적 이동 거리 (m)

  // 저장된 세션 ID (1차 저장 후 업데이트용)
  String? _savedSessionId;

  // 말풍선 상태 관리 변수
  SpeechBubbleState? _currentSpeechBubbleState;
  bool _speechBubbleVisible = true;

  // --- Public Getters ---
  LatLng? get startLocation => _startLocation;
  LatLng? get waypointLocation => _waypointLocation;
  String? get waypointQuestion => _waypointQuestion;
  String? get userAnswer => _userAnswer;
  String? get photoPath => _photoPath;
  String? get userReflection => _userReflection;
  String? get selectedMate => _selectedMate;
  String? get friendGroupType => _friendGroupType;
  String? get poseImageUrl => _poseImageUrl;
  Uint8List? get routeSnapshotPng => _routeSnapshotPng;
  String? get destinationBuildingName => _destinationBuildingName;
  String? get customStartName => _customStartName;
  bool get isWalkComplete => _startReturnEventOccurred;
  DateTime? get actualStartTime => _actualStartTime;
  DateTime? get actualEndTime => _actualEndTime;
  String? get savedSessionId => _savedSessionId;

  // 말풍선 관련 getters
  SpeechBubbleState? get currentSpeechBubbleState => _currentSpeechBubbleState;
  bool get speechBubbleVisible => _speechBubbleVisible;

  /// 경유지 이벤트 발생 여부 (경유지 도착 알림 트리거 여부)
  bool get waypointEventOccurred => _waypointEventOccurred;

  /// 목적지에서 출발지로 돌아가는 중인지 여부
  bool get isReturningHome => _isReturningHome;

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

  /// 산책 방식을 설정합니다. (왕복/편도)
  void setWalkMode(WalkMode mode) {
    _mode = mode;
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
    // 일부 단말/지역에서 '.' 등 플레이스홀더가 전달될 수 있어 필터링
    bool _isInvalidPlaceholder(String? value) {
      if (value == null) return true;
      final t = value.trim();
      if (t.isEmpty) return true;
      return t == '.' || t == '·' || t == '-';
    }

    _destinationBuildingName =
        _isInvalidPlaceholder(buildingName) ? null : buildingName!.trim();
    LogService.walkState(' 목적지 건물명 설정 -> "$_destinationBuildingName"');
  }

  /// 사용자 지정 출발지 이름 설정 메소드
  void setCustomStartName(String? name) {
    bool _isInvalidPlaceholder(String? value) {
      if (value == null) return true;
      final t = value.trim();
      if (t.isEmpty) return true;
      return t == '.' || t == '·' || t == '-';
    }

    _customStartName = _isInvalidPlaceholder(name) ? null : name!.trim();
    LogService.walkState(' 사용자 지정 출발지 이름 설정 -> "$_customStartName"');
  }

  // 산책 시작 시 초기화
  void startWalk({
    required LatLng start,
    required LatLng destination,
    required String mate,
    String? friendGroupType,
  }) {
    _startLocation = start; // 출발지 위치 저장
    _destinationLocation = destination;
    _selectedMate = mate;
    _friendGroupType = friendGroupType;
    _waypointLocation = _waypointHandler.generateWaypoint(start, destination);
    _waypointEventOccurred = false;
    _destinationEventOccurred = false;
    _startReturnEventOccurred = false; // 출발지 복귀 상태 초기화
    _isReturningHome = false; // 초기화
    _waypointQuestion = null;
    _userAnswer = null;
    _photoPath = null;

    // 말풍선 초기화 - 산책 시작 시 첫 번째 상태
    _currentSpeechBubbleState = SpeechBubbleState.toWaypoint;
    _speechBubbleVisible = true;
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

  // 목적지에서 출발지로 돌아가기 시작
  void startReturningHome() {
    _isReturningHome = true;
    _currentSpeechBubbleState = SpeechBubbleState.returning; // "이제 집가자~"
    LogService.walkState(' 이제 출발지로 돌아갑니다.');
    LogService.info('SpeechBubble',
        '출발지 복귀 시작 - 말풍선: ${_currentSpeechBubbleState?.message}');
  }

  // 실시간 위치 업데이트 처리 (Future<String?>으로 변경)
  Future<String?> updateUserLocation(
    LatLng userLocation, {
    bool forceWaypointEvent = false,
    bool forceDestinationEvent = false,
    bool forceStartReturnEvent = false,
  }) async {
    // 누적 이동 거리 갱신
    try {
      if (_lastUserLocation == null) {
        _lastUserLocation = userLocation;
      } else {
        final double segment = Geolocator.distanceBetween(
          _lastUserLocation!.latitude,
          _lastUserLocation!.longitude,
          userLocation.latitude,
          userLocation.longitude,
        );
        if (segment.isFinite && segment > 0) {
          _accumulatedDistanceMeters += segment;
        }
        _lastUserLocation = userLocation;
      }
    } catch (e) {
      LogService.error('WalkState', '누적 거리 계산 실패', e);
    }

    // 말풍선 상태 업데이트
    updateSpeechBubbleState(userLocation);
    // 경유지 이벤트 확인 (아직 발생하지 않았을 때만)
    if (!_waypointEventOccurred) {
      final bool arrived = _waypointHandler.checkWaypointArrival(
        userLocation: userLocation,
        waypointLocation: _waypointLocation,
        forceWaypointEvent: forceWaypointEvent,
      );

      if (arrived) {
        _waypointEventOccurred = true;
        final String? question = await _questionProvider.getQuestionForMate(
          _selectedMate,
          friendGroupType: _friendGroupType,
        );

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
        if (_mode == WalkMode.oneWay) {
          // 편도: 목적지 도착 즉시 종료 처리
          _actualEndTime = DateTime.now();
          LogService.walkState(' 편도 산책 완료! 실제 종료 시간 기록 -> $_actualEndTime');
          return "one_way_completed";
        }
        return "destination_reached";
      }
    }

    // 출발지 복귀 이벤트 확인 (목적지 이벤트가 완료되고, 돌아오는 중일 때만)
    LogService.walkState(
        ' 출발지 복귀 체크 - _destinationEventOccurred: $_destinationEventOccurred');
    LogService.walkState(' 출발지 복귀 체크 - _isReturningHome: $_isReturningHome');
    LogService.walkState(
        ' 출발지 복귀 체크 - _startReturnEventOccurred: $_startReturnEventOccurred');

    if (_mode == WalkMode.roundTrip &&
        _destinationEventOccurred &&
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
    LogService.walkState('출발지: $_startLocation');
    LogService.walkState('경유지: $_waypointLocation');
    LogService.walkState('목적지: $_destinationLocation');
  }

  /// 좌표를 주소로 변환하는 메소드
  Future<String> _convertCoordinateToAddress(LatLng coordinate) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinate.latitude,
        coordinate.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placeMark = placemarks.first;
        // 일부 단말/지역에서 '.' 같은 플레이스홀더가 올 수 있어 필터링 처리
        String safeString(String? v) {
          if (v == null) return '';
          final t = v.trim();
          if (t.isEmpty) return '';
          if (t == '.' || t == '·' || t == '-') return '';
          return t;
        }

        final String region = safeString(placeMark.administrativeArea); // 시/도
        final String cityA = safeString(placeMark.locality); // 시/군/구 (기기별 편차)
        final String cityB =
            safeString(placeMark.subAdministrativeArea); // 시/군/구 보조
        final String district = safeString(placeMark.subLocality); // 동/읍/면
        final String street =
            safeString(placeMark.street); // 도로명 + 번지까지 포함될 수 있음
        final String road = safeString(placeMark.thoroughfare);
        final String number = safeString(placeMark.subThoroughfare);

        final List<String> parts = [];
        if (region.isNotEmpty) parts.add(region);
        if (cityA.isNotEmpty) parts.add(cityA);
        if (cityB.isNotEmpty && cityB != cityA) parts.add(cityB);
        if (district.isNotEmpty) parts.add(district);

        String tail = street;
        if (tail.isEmpty) {
          tail = [road, number].where((e) => e.trim().isNotEmpty).join(' ');
        }
        if (tail.isNotEmpty) parts.add(tail);

        final String address = parts.join(' ').trim();
        return address.isNotEmpty ? address : '알 수 없는 위치';
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
    if (_customStartName != null && _customStartName!.trim().isNotEmpty) {
      return _customStartName!;
    }
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
    return await _convertCoordinateToAddress(_destinationLocation!);
  }

  // --- 말풍선 관련 메서드들 ---

  /// 현재 위치를 기반으로 말풍선 상태를 업데이트합니다.
  void updateSpeechBubbleState(LatLng currentPosition) {
    if (_startLocation == null ||
        _destinationLocation == null ||
        _waypointLocation == null) {
      return;
    }

    final SpeechBubbleState? newState =
        _calculateSpeechBubbleState(currentPosition);

    if (newState != null && newState != _currentSpeechBubbleState) {
      _currentSpeechBubbleState = newState;
      LogService.info('SpeechBubble', '말풍선 상태 변경: ${newState.message}');
    }
  }

  /// 현재 위치를 기반으로 적절한 말풍선 상태를 계산합니다.
  SpeechBubbleState? _calculateSpeechBubbleState(LatLng currentPosition) {
    if (_startLocation == null ||
        _destinationLocation == null ||
        _waypointLocation == null) {
      return null;
    }

    final double distanceToStart = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      _startLocation!.latitude,
      _startLocation!.longitude,
    );

    final double distanceToWaypoint = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      _waypointLocation!.latitude,
      _waypointLocation!.longitude,
    );

    final double distanceToDestination = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );

    // 전체 구간별 거리 계산
    final double startToWaypointDistance = Geolocator.distanceBetween(
      _startLocation!.latitude,
      _startLocation!.longitude,
      _waypointLocation!.latitude,
      _waypointLocation!.longitude,
    );

    final double waypointToDestinationDistance = Geolocator.distanceBetween(
      _waypointLocation!.latitude,
      _waypointLocation!.longitude,
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
    );

    final double destinationToStartDistance = Geolocator.distanceBetween(
      _destinationLocation!.latitude,
      _destinationLocation!.longitude,
      _startLocation!.latitude,
      _startLocation!.longitude,
    );

    // 각 구간별 절반 지점 계산
    final double halfStartToWaypoint = startToWaypointDistance / 2;
    final double halfWaypointToDestination = waypointToDestinationDistance / 2;
    final double halfDestinationToStart = destinationToStartDistance / 2;

    // 출발지 복귀 중인 경우
    if (_isReturningHome) {
      if (distanceToStart <= halfDestinationToStart) {
        return SpeechBubbleState.almostHome; // "거의 다왔다!!"
      } else {
        return SpeechBubbleState.returning; // "이제 집가자~"
      }
    }

    // 목적지 도달 후 아직 복귀하지 않은 경우 (포즈 촬영 중 등)
    if (_destinationEventOccurred && !_isReturningHome) {
      return SpeechBubbleState.returning; // "이제 집가자~"
    }

    // 목적지 근처인 경우
    if (distanceToDestination <= halfWaypointToDestination) {
      return SpeechBubbleState.almostDestination; // "고지가 코앞이다!!"
    }

    // 경유지 이벤트가 완료되었다면 해당 상태 유지 (목적지 근처가 아닌 한)
    if (_currentSpeechBubbleState == SpeechBubbleState.waypointEventCompleted) {
      return SpeechBubbleState.waypointEventCompleted; // "뚜비두밥~♪"
    }

    // 경유지 근처인 경우
    if (distanceToWaypoint <= halfStartToWaypoint) {
      return SpeechBubbleState.almostWaypoint; // "선물.. 선물.. 선물.. "
    }

    // 기본 상태: 출발지에서 경유지로 향하는 중
    return SpeechBubbleState.toWaypoint; // "산책 가보자고~"
  }

  /// 개발자 전용: 말풍선 상태를 강제로 설정합니다. (디버그 모드에서만 작동)
  void setDebugSpeechBubbleState(SpeechBubbleState state) {
    if (kDebugMode) {
      _currentSpeechBubbleState = state;
      LogService.debug('SpeechBubble', 'DEBUG: 말풍선 상태 강제 설정: ${state.message}');
    }
  }

  /// 말풍선 표시 여부를 설정합니다.
  void setSpeechBubbleVisible(bool visible) {
    _speechBubbleVisible = visible;
  }

  /// 경유지 이벤트 확인 후 말풍선 상태를 변경합니다.
  void completeWaypointEvent() {
    if (_currentSpeechBubbleState == SpeechBubbleState.almostWaypoint) {
      _currentSpeechBubbleState = SpeechBubbleState.waypointEventCompleted;
      LogService.info('SpeechBubble',
          '경유지 이벤트 완료 - 말풍선: ${_currentSpeechBubbleState?.message}');
    }
  }
}
