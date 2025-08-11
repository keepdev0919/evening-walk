import 'dart:async';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
// import 'package:walk/src/features/walk/presentation/utils/map_marker_creator.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:walk/src/features/walk/presentation/widgets/walk_map_view.dart';
import 'package:walk/src/features/walk/presentation/widgets/waypointDialog.dart';
import 'package:walk/src/features/walk/presentation/widgets/debugmode_button.dart';
import 'package:walk/src/features/walk/presentation/widgets/destinationDialog.dart';
import 'package:walk/src/features/walk/presentation/widgets/speech_bubble_widget.dart';
import 'package:walk/src/features/walk/presentation/screens/pose_recommendation_screen.dart';
import 'package:walk/src/features/walk/presentation/screens/walk_diary_screen.dart';
import 'package:walk/src/features/walk/presentation/widgets/walk_completion_dialog.dart';
import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:walk/src/core/services/log_service.dart';

/// 이 파일은 산책이 진행 중일 때 지도를 표시하고 사용자 위치를 추적하며,
/// 경유지 및 목적지 도착 이벤트를 처리하는 화면을 담당합니다.
/// 사용자의 현재 위치, 목적지, 경유지를 지도에 마커로 표시하고,
/// 특정 지점에 도달했을 때 관련 이벤트를 발생시킵니다.

class WalkInProgressMapScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng destinationLocation;
  final String selectedMate;
  final String? destinationBuildingName;

  const WalkInProgressMapScreen({
    Key? key,
    required this.startLocation,
    required this.destinationLocation,
    required this.selectedMate,
    this.destinationBuildingName,
  }) : super(key: key);

  @override
  State<WalkInProgressMapScreen> createState() =>
      _WalkInProgressMapScreenState();
}

class _WalkInProgressMapScreenState extends State<WalkInProgressMapScreen>
    with WidgetsBindingObserver {
  AppLifecycleState? _lastLifecycleState;

  /// Google Map 컨트롤러. 지도 제어에 사용됩니다.
  late GoogleMapController mapController;

  /// 사용자의 현재 위치를 저장하는 LatLng 객체입니다.
  LatLng? _currentPosition;

  /// 지도 로딩 상태를 나타내는 플래그입니다. true이면 로딩 중, false이면 로딩 완료입니다.
  bool _isLoading = true;

  /// 현재위치 & 목적지 & 경유지를 표시하는 마커입니다.
  Marker? _currentLocationMarker;
  Marker? _destinationMarker;
  Marker? _waypointMarker;

  /// 산책 상태를 관리하는 매니저 인스턴스입니다.
  late WalkStateManager _walkStateManager;

  /// 현재 로그인한 Firebase 사용자 정보입니다.
  // User? _user; // Lottie로 대체되어 현재 미사용

  /// 위치 스트림 구독을 관리하는 객체입니다.
  StreamSubscription<Position>? _positionStreamSubscription;

  /// 이벤트(경유지, 목적지) 다이얼로그가 활성화 상태인지 확인하는 플래그입니다.
  bool _isProcessingEvent = false;

  // late NotificationService _notificationService;

  /// 경유지 이벤트 확인 버튼의 가시성을 제어합니다.
  bool _showWaypointEventButton = false;
  bool _showDestinationEventButton = false;

  /// 마지막으로 발생한 경유지 질문 내용을 저장합니다.
  String? _lastWaypointQuestion;
  String? _lastWaypointUserAnswer;
  String? _currentDestinationPoseImageUrl;
  String? _currentDestinationTakenPhotoPath;
  // 목적지/경유지 Lottie 오버레이 좌표 및 크기
  Offset? _destinationOverlayOffset;
  Offset? _waypointOverlayOffset;
  static const double _destinationOverlayWidth = 50;
  static const double _destinationOverlayHeight = 50;
  static const double _overlayBottomTrim = 12.0; // Lottie 하단 여백 보정
  // 경유지 표시: 출발지/목적지와 동일하게 width/height로만 제어
  static const double _waypointOverlayWidth = 50;
  static const double _waypointOverlayHeight = 50;

  /// 현재 위치 Lottie 오버레이 좌표 및 크기
  Offset? _userOverlayOffset;
  static const double _overlayWidth = 80;
  static const double _overlayHeight = 80;

  Future<void> _updateOverlayPosition() async {
    if (_currentPosition == null) return;
    try {
      final screen = await mapController.getScreenCoordinate(_currentPosition!);
      final dpr = MediaQuery.of(context).devicePixelRatio;
      setState(() {
        _userOverlayOffset = Offset(
          screen.x.toDouble() / dpr,
          screen.y.toDouble() / dpr,
        );
      });
    } catch (_) {}
  }

  void _handleWaypointEventState(bool show, String? question, String? answer) {
    setState(() {
      _showWaypointEventButton = show;
      _lastWaypointQuestion = question;
      _lastWaypointUserAnswer = answer;
    });
    // 사용자가 경유지 질문에 답변을 제출한 경우, 매니저에 즉시 저장하여 일기에서 보이도록 함
    if (answer != null && answer.trim().isNotEmpty) {
      _walkStateManager.saveAnswerAndPhoto(answer: answer.trim());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 옵저버 등록
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState; // 초기 상태 설정
    // 현재 사용자 정보를 가져옵니다.
    // _user = FirebaseAuth.instance.currentUser;
    // WalkStateManager를 초기화합니다.
    _walkStateManager = WalkStateManager();

    // 산책 초기화를 시작합니다.
    _initializeWalk();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 옵저버 해제
    // 위젯이 dispose될 때 위치 스트림 구독을 취소하여 리소스 누수를 방지합니다.

    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _lastLifecycleState = state;
    });
  }

  /// 지도가 생성될 때 호출되는 콜백 함수입니다.
  /// GoogleMapController를 초기화합니다.
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _updateOverlayPosition();
    _updateOverlayPositions();
  }

  Future<void> _updateOverlayPositions() async {
    if (!mounted) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    try {
      final destScreen =
          await mapController.getScreenCoordinate(widget.destinationLocation);
      setState(() {
        _destinationOverlayOffset = Offset(
          destScreen.x.toDouble() / dpr,
          destScreen.y.toDouble() / dpr,
        );
      });
    } catch (_) {}

    try {
      final waypoint = _walkStateManager.waypointLocation;
      if (waypoint != null) {
        final wpScreen = await mapController.getScreenCoordinate(waypoint);
        setState(() {
          _waypointOverlayOffset = Offset(
            wpScreen.x.toDouble() / dpr,
            wpScreen.y.toDouble() / dpr,
          );
        });
      } else {
        setState(() {
          _waypointOverlayOffset = null;
        });
      }
    } catch (_) {}
  }

  /// 산책 관련 데이터를 초기화하고 지도에 마커를 설정합니다.
  /// 사용자 프로필, 선물 상자, 깃발 마커를 생성하고 위치 추적을 시작합니다.
  Future<void> _initializeWalk() async {
    // 프로필/경유지/목적지 마커는 사용하지 않고, 오버레이 Lottie로 대체합니다.

    _walkStateManager.startWalk(
      start: widget.startLocation,
      destination: widget.destinationLocation,
      mate: widget.selectedMate,
    );

    // 목적지 건물명이 있으면 WalkStateManager에 저장
    if (widget.destinationBuildingName != null) {
      _walkStateManager
          .setDestinationBuildingName(widget.destinationBuildingName);
    }
    // final LatLng? waypoint = _walkStateManager.waypointLocation;

    setState(() {
      _currentPosition = widget.startLocation;
      _currentLocationMarker = null; // Lottie로 대체
      _destinationMarker = null; // Lottie로 대체
      _waypointMarker = null; // Lottie로 대체
      _isLoading = false; // 로딩 완료
    });

    _startLocationTracking();
    // 초기 오버레이 위치 계산
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOverlayPosition();
      _updateOverlayPositions();
    });
  }

  /// 사용자의 위치 추적을 시작합니다.
  /// Geolocator를 사용하여 실시간 위치 업데이트를 받고 지도에 반영합니다.
  void _startLocationTracking() {
    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    )).listen((Position position) async {
      if (!mounted || _isProcessingEvent) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      await _updateOverlayPosition();
      await _updateOverlayPositions();

      final eventSignal =
          await _walkStateManager.updateUserLocation(_currentPosition!);

      if (!mounted || eventSignal == null) return;

      setState(() {
        _isProcessingEvent = true;
      });

      switch (eventSignal) {
        case "destination_reached":
          final bool? wantsToSeeEvent =
              await DestinationDialog.showDestinationArrivalDialog(
            context: context,
          );

          if (wantsToSeeEvent == true) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PoseRecommendationScreen(
                  walkStateManager: _walkStateManager,
                ),
              ),
            );
          } else {
            // 나중에 버튼 선택 시에도 출발지 복귀 감지 시작
            _walkStateManager.startReturningHome();

            if (mounted) {
              setState(() {
                _showDestinationEventButton = true;
              });
            }
          }
          break;

        case "start_returned":
          _positionStreamSubscription?.cancel();

          // 1. 기존 세션에 완료 시간 업데이트
          if (_walkStateManager.savedSessionId != null) {
            final walkSessionService = WalkSessionService();
            await walkSessionService.updateWalkSession(
              _walkStateManager.savedSessionId!,
              {'endTime': DateTime.now().toIso8601String()},
            );
            LogService.info('WalkProgress', '출발지 복귀 완료 시간 업데이트 완료');
          }

          // 2. 산책 완료 알림 다이얼로그 표시
          final bool? shouldShowDiary =
              await WalkCompletionDialog.showWalkCompletionDialog(
            context: context,
            savedSessionId: _walkStateManager.savedSessionId ?? '',
          );

          // 3. 사용자가 '일기 작성'을 선택한 경우에만 산책 일기 페이지로 이동
          if (shouldShowDiary == true && context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WalkDiaryScreen(
                  walkStateManager: _walkStateManager,
                  sessionId: _walkStateManager.savedSessionId, // 기존 세션 ID 전달
                  onWalkCompleted: (completed) {
                    LogService.info('WalkProgress', '산책이 완전히 완료되었습니다!');
                  },
                ),
              ),
            );
          } else if (shouldShowDiary == false && context.mounted) {
            // 4. '나중에' 선택 시 홈으로 이동
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          }
          break;

        default: // 경유지 이벤트
          if (_lastLifecycleState == AppLifecycleState.resumed) {
            await WaypointDialogs.showWaypointArrivalDialog(
              context: context,
              questionPayload: eventSignal,
              updateWaypointEventState: _handleWaypointEventState,
            );
          }
          break;
      }

      if (mounted) {
        setState(() {
          _isProcessingEvent = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 모든 마커를 담을 Set을 초기화합니다.
    Set<Marker> allMarkers = {};
    // 현재 위치 마커가 있으면 추가합니다.
    if (_currentLocationMarker != null) allMarkers.add(_currentLocationMarker!);
    // 목적지 마커가 있으면 추가합니다.
    if (_destinationMarker != null) allMarkers.add(_destinationMarker!);
    // 경유지 마커가 있으면 추가합니다.
    if (_waypointMarker != null) allMarkers.add(_waypointMarker!);

    return Scaffold(
      // AppBar 영역까지 body를 확장합니다.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 투명한 배경
        elevation: 0, // 그림자 제거
        // 뒤로가기 버튼: 로딩 중에는 표시하지 않습니다.
        leading: _isLoading
            ? null
            : Container(
                margin: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
        // 제목 ("산책 중"): 로딩 중에는 표시하지 않습니다.
        title: _isLoading
            ? null
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: const Text(
                  '산책 중 ...',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ),
        centerTitle: true,
        actions: [
          if (_showWaypointEventButton)
            Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.card_giftcard, color: Colors.orange),
                onPressed: () {
                  if (_lastWaypointQuestion != null) {
                    WaypointDialogs.showQuestionDialog(
                        context,
                        _lastWaypointQuestion!,
                        _handleWaypointEventState,
                        _lastWaypointUserAnswer);
                  }
                },
              ),
            ),
          if (_showDestinationEventButton)
            Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.flag, color: Colors.red),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PoseRecommendationScreen(
                        walkStateManager: _walkStateManager,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 로딩 중이면 CircularProgressIndicator를 표시하고, 아니면 GoogleMap을 표시합니다.
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : WalkMapView(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition ?? widget.startLocation,
                    zoom: 15.0,
                  ),
                  markers: allMarkers,
                  onCameraMove: (_) {
                    _updateOverlayPosition();
                    _updateOverlayPositions();
                  },
                ),
          // 디버그 모드일 때만 경유지/목적지 도착 버튼을 표시합니다. 로딩 중에는 표시하지 않습니다.
          DebugModeButtons(
            isLoading: _isLoading,
            currentPosition: _currentPosition,
            walkStateManager: _walkStateManager,
            selectedMate: widget.selectedMate,
            updateWaypointEventState: _handleWaypointEventState,
            updateDestinationEventState: (show) {
              setState(() {
                _showDestinationEventButton = show;
              });
            },
            onPoseImageGenerated: (imageUrl) {
              setState(() {
                _currentDestinationPoseImageUrl = imageUrl;
              });
            },
            onPhotoTaken: (photoPath) {
              setState(() {
                _currentDestinationTakenPhotoPath = photoPath;
              });
            },
            initialPoseImageUrl: _currentDestinationPoseImageUrl,
            initialTakenPhotoPath: _currentDestinationTakenPhotoPath,
          ),
          // 현재 위치에 붙는 Lottie 애니메이션 오버레이
          if (!_isLoading && _userOverlayOffset != null)
            Positioned(
              left: _userOverlayOffset!.dx - (_overlayWidth / 2),
              top: _userOverlayOffset!.dy - _overlayHeight + _overlayBottomTrim,
              child: IgnorePointer(
                ignoring: true,
                child: SizedBox(
                  width: _overlayWidth,
                  height: _overlayHeight,
                  child: lottie.Lottie.asset(
                    'assets/animations/start.json',
                    repeat: true,
                    animate: true,
                    alignment: Alignment.bottomCenter,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          // 현재 위치 말풍선 오버레이
          if (!_isLoading && _userOverlayOffset != null)
            Positioned(
              left:
                  _userOverlayOffset!.dx - 60, // 말풍선 중앙 정렬 (말풍선 최대 너비 200의 절반)
              top: _userOverlayOffset!.dy - _overlayHeight - 20, // 애니메이션 위쪽에 표시
              child: IgnorePointer(
                ignoring: true,
                child: SpeechBubbleWidget(
                  speechBubbleState: _walkStateManager.currentSpeechBubbleState,
                  visible: _walkStateManager.speechBubbleVisible,
                ),
              ),
            ),
          // 목적지 Lottie 애니메이션 오버레이
          if (!_isLoading && _destinationOverlayOffset != null)
            Positioned(
              left: _destinationOverlayOffset!.dx -
                  (_destinationOverlayWidth / 2),
              top: _destinationOverlayOffset!.dy -
                  _destinationOverlayHeight +
                  _overlayBottomTrim,
              child: IgnorePointer(
                ignoring: true,
                child: SizedBox(
                  width: _destinationOverlayWidth,
                  height: _destinationOverlayHeight,
                  child: lottie.Lottie.asset(
                    'assets/animations/destination.json',
                    repeat: true,
                    animate: true,
                    alignment: Alignment.bottomCenter,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          // 경유지 Lottie 애니메이션 오버레이 (width/height로만 제어)
          if (!_isLoading && _waypointOverlayOffset != null)
            Positioned(
              left: _waypointOverlayOffset!.dx - (_waypointOverlayWidth / 2),
              top: _waypointOverlayOffset!.dy -
                  _waypointOverlayHeight +
                  _overlayBottomTrim,
              child: IgnorePointer(
                ignoring: true,
                child: SizedBox(
                  width: _waypointOverlayWidth,
                  height: _waypointOverlayHeight,
                  child: lottie.Lottie.asset(
                    'assets/animations/waypoint.json',
                    repeat: true,
                    animate: true,
                    alignment: Alignment.bottomCenter,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
