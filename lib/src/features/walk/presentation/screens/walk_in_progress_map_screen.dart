import 'dart:async';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
// import 'package:walk/src/features/walk/presentation/utils/map_marker_creator.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:walk/src/features/walk/presentation/widgets/walk_map_view.dart';
import 'package:walk/src/features/walk/presentation/utils/map_marker_creator.dart';
// import 'package:flutter_compass/flutter_compass.dart';
import 'package:walk/src/features/walk/presentation/widgets/waypointDialog.dart';
import 'package:walk/src/features/walk/presentation/widgets/debugmode_button.dart';
import 'package:walk/src/features/walk/presentation/widgets/destinationDialog.dart';
import 'package:walk/src/features/walk/presentation/widgets/speech_bubble_widget.dart';
import 'package:walk/src/features/walk/presentation/screens/pose_recommendation_screen.dart';
import 'package:walk/src/features/walk/presentation/screens/walk_diary_screen.dart';
import 'package:walk/src/features/walk/presentation/widgets/walk_completion_dialog.dart';
import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:walk/src/core/services/log_service.dart';
// import 'package:walk/src/features/walk/application/services/route_snapshot_service.dart';
// import 'package:walk/src/features/walk/application/services/in_app_map_snapshot_service.dart';
// import 'dart:typed_data';
// import 'dart:math' as math;
import 'package:walk/src/features/walk/presentation/utils/heading_controller.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  AppLifecycleState? _lastLifecycleState;

  /// Google Map 컨트롤러. 지도 제어에 사용됩니다.
  late GoogleMapController mapController;
  double _cameraBearing = 0.0; // 지도가 회전할 때 화살표 보정을 위한 값

  /// 사용자의 현재 위치를 저장하는 LatLng 객체입니다.
  LatLng? _currentPosition;

  /// 지도 로딩 상태를 나타내는 플래그입니다. true이면 로딩 중, false이면 로딩 완료입니다.
  bool _isLoading = true;

  /// 현재위치 & 목적지 & 경유지를 표시하는 마커입니다.
  Marker? _currentLocationMarker;
  Marker? _destinationMarker;
  Marker? _waypointMarker;
  // 사용자의 이동 경로에 남길 발자국(🐾) 마커들
  final List<Marker> _footprintMarkers = [];
  BitmapDescriptor? _footprintIcon;
  BitmapDescriptor? _dotIcon;
  LatLng? _lastFootprintPosition;

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

  /// 경유지 이벤트 이후, 목적지로 유도하는 말풍선("얼른와..!") 표시 여부
  bool _showDestinationTeaseBubble = false;

  /// 마지막으로 발생한 경유지 질문 내용을 저장합니다.
  String? _lastWaypointQuestion;
  String? _lastWaypointUserAnswer;
  String? _currentDestinationPoseImageUrl;
  String? _currentDestinationTakenPhotoPath;
  // 목적지/경유지/출발지 Lottie 오버레이 좌표 및 크기
  Offset? _destinationOverlayOffset;
  Offset? _waypointOverlayOffset;
  Offset? _startOverlayOffset;
  static const double _destinationOverlayWidth = 50;
  static const double _destinationOverlayHeight = 50;
  static const double _overlayBottomTrim = 12.0; // Lottie 하단 여백 보정
  // 경유지 표시: 출발지/목적지와 동일하게 width/height로만 제어
  static const double _waypointOverlayWidth = 50;
  static const double _waypointOverlayHeight = 50;
  // 출발지 표시
  static const double _startOverlayWidth = 40;
  static const double _startOverlayHeight = 40;

  /// 현재 위치 Lottie 오버레이 좌표 및 크기
  Offset? _userOverlayOffset;
  static const double _overlayWidth = 80;
  static const double _overlayHeight = 80;

  /// 사용자 방향 관련 변수
  double? _currentHeading; // 현재 방향 (도 단위)
  late AnimationController _headingAnimationController;
  late Animation<double> _headingAnimation;
  HeadingController? _headingController;
  StreamSubscription<double>? _headingSub;
  // 디바이스 자기 센서(컴퍼스)에서 읽은 각도 (0~360)
  // HeadingController로 대체 (남아있는 참조 제거)
  // double? _deviceCompassHeading;
  // StreamSubscription<CompassEvent>? _compassSubscription;

  /// 이동 방향 계산 및 소스 스위칭을 위한 보조 상태값
  // Position? _lastPositionForCourse; // 이전 GPS 위치 (HeadingController로 대체)

  /// 보조 함수: 각도를 0~360도로 정규화합니다.
  double _normalizeDegrees(double angle) {
    double a = angle % 360.0;
    if (a < 0) a += 360.0;
    return a;
  }

  /// 산책 메이트에 따른 이모지를 반환합니다.
  String _getMateEmoji(String mate) {
    if (mate == '혼자') return '🌙';
    if (mate == '연인') return '💕';
    if (mate.startsWith('친구')) return '👫';
    return '🚶'; // 기본값
  }

  /// 산책 메이트에 따른 색상을 반환합니다.
  Color _getMateColor(String mate) {
    if (mate == '혼자') return Colors.blue;
    if (mate == '연인') return Colors.pink;
    if (mate.startsWith('친구')) return Colors.green;
    return Colors.green; // 기본값
  }

  // 진행방향 계산 로직은 HeadingController로 이동

  /// 보조 함수: 최단 회전 경로로 각도를 보간합니다. 반환값은 도 단위입니다.
  // HeadingController 사용으로 미사용
  // double _lerpAngleShortestDegrees(double fromDeg, double toDeg, double t) { ... }

  /// 속도에 따른 보간 민감도. 빠를수록 더 민감하게 반응.
  // HeadingController 사용으로 미사용
  // double _alphaBySpeed(double speedMetersPerSecond) { ... }

  /// 사용자의 이동 경로에 발자국(🐾)/점(.) 마커를 추가합니다.
  /// - 발자국: 10m 간격
  /// - 점: 2m 간격으로 보조 시각화
  void _maybeAddFootprint(LatLng current) {
    if (_footprintIcon == null) return; // 아이콘이 아직 준비되지 않은 경우

    const double footprintDistance = 10.0;
    const double dotDistance = 2.0;
    if (_lastFootprintPosition != null) {
      final double d = Geolocator.distanceBetween(
        _lastFootprintPosition!.latitude,
        _lastFootprintPosition!.longitude,
        current.latitude,
        current.longitude,
      );
      // 2m 이상 이동했으면 작은 점을 찍어 경로 보조
      if (d >= dotDistance) {
        _addDotMarker(current);
      }
      // 10m 이상일 때만 발자국을 추가
      if (d < footprintDistance) return;
    }

    _lastFootprintPosition = current;
    final String markerId =
        'footprint_${DateTime.now().millisecondsSinceEpoch}';
    _footprintMarkers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: current,
        icon: _footprintIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 1.0,
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  /// 2m 간격 보조용 점(.) 마커를 추가합니다.
  Future<void> _ensureDotIcon() async {
    if (_dotIcon != null) return;
    _dotIcon = await MapMarkerCreator.createDotMarkerBitmap(
      diameter: 10.0,
      color: Colors.white,
      alpha: 0.85,
      borderColor: Colors.black45,
      borderWidth: 1.0,
    );
  }

  void _addDotMarker(LatLng position) async {
    await _ensureDotIcon();
    if (_dotIcon == null) return;
    final String markerId = 'dot_${DateTime.now().millisecondsSinceEpoch}';
    _footprintMarkers.add(
      Marker(
        markerId: MarkerId(markerId),
        position: position,
        icon: _dotIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 0.9,
      ),
    );
  }

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

  // 목적지 스냅샷 저장 로직은 현재 플로우에서 사용하지 않음

  void _handleWaypointEventState(bool show, String? question, String? answer) {
    setState(() {
      _showWaypointEventButton = show;
      _lastWaypointQuestion = question;
      _lastWaypointUserAnswer = answer;
      // 경유지 이벤트가 시작되면 목적지 유도 말풍선을 활성화
      if (show) {
        _showDestinationTeaseBubble = true;
      }
    });
    // 좌표 즉시 갱신하여 말풍선이 바로 보이도록 보장
    _updateOverlayPositions();
    // 선택/결정된 경유지 질문을 상태 매니저에 저장하여 공유/일기 화면에서 표시되도록 함
    if (question != null && question.trim().isNotEmpty) {
      _walkStateManager.setWaypointQuestion(question.trim());
    }
    // 사용자가 경유지 질문에 답변을 제출한 경우, 매니저에 즉시 저장하여 일기에서 보이도록 함
    if (answer != null && answer.trim().isNotEmpty) {
      _walkStateManager.saveAnswerAndPhoto(answer: answer.trim());
    }

    // 경유지 이벤트가 시작되면 (나중에 버튼이든 이벤트 확인이든) 말풍선 상태 변경
    if (show) {
      _walkStateManager.completeWaypointEvent();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 옵저버 등록
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState; // 초기 상태 설정

    // 방향 애니메이션 컨트롤러 초기화
    _headingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _headingAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _headingAnimationController, curve: Curves.easeInOut),
    );

    // 컴퍼스 직접 구독 제거 (HeadingController 스트림으로 일원화)

    // 현재 사용자 정보를 가져옵니다.
    // _user = FirebaseAuth.instance.currentUser;
    // WalkStateManager를 초기화합니다.
    _walkStateManager = WalkStateManager();

    // 산책 초기화를 시작합니다.
    _initializeWalk();

    // HeadingController 시작 및 구독
    _headingController = HeadingController()..start();
    _headingSub = _headingController!.stream.listen((deg) {
      final double corrected = _normalizeDegrees(deg - _cameraBearing);
      _updateUserHeading(corrected);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 옵저버 해제
    // 위젯이 dispose될 때 위치 스트림 구독을 취소하여 리소스 누수를 방지합니다.
    _positionStreamSubscription?.cancel();
    // 방향 애니메이션 컨트롤러 해제
    _headingSub?.cancel();
    _headingController?.dispose();
    _headingAnimationController.dispose();
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

    // 목적지 위치 계산
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

    // 경유지 위치 계산
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

    // 출발지 위치 계산 (편도/왕복 모드 모두)
    try {
      final startScreen =
          await mapController.getScreenCoordinate(widget.startLocation);
      setState(() {
        _startOverlayOffset = Offset(
          startScreen.x.toDouble() / dpr,
          startScreen.y.toDouble() / dpr,
        );
      });
    } catch (_) {}
  }

  /// 사용자 방향 업데이트 및 애니메이션 처리
  void _updateUserHeading(double newHeading) {
    // debug print suppressed

    if (_currentHeading == null) {
      // 첫 방향 설정
      // debug print suppressed
      _currentHeading = newHeading;
      _headingAnimation = Tween<double>(
        begin: newHeading * (3.14159 / 180), // 도를 라디안으로 변환
        end: newHeading * (3.14159 / 180),
      ).animate(_headingAnimationController);
      setState(() {}); // UI 업데이트 강제
    } else {
      // 방향 변화가 5도 이상일 때만 업데이트 (테스트를 위해 임계값 낮춤)
      double angleDiff = (newHeading - _currentHeading!).abs();
      if (angleDiff > 180) angleDiff = 360 - angleDiff; // 최단 각도 계산

      // debug print suppressed

      if (angleDiff > 5) {
        // 15도 -> 5도로 낮춤 (테스트용)
        // debug print suppressed

        double fromAngle = _currentHeading! * (3.14159 / 180);
        double toAngle = newHeading * (3.14159 / 180);

        // 360도 경계 처리 (최단 경로로 회전)
        if ((newHeading - _currentHeading!).abs() > 180) {
          if (_currentHeading! > newHeading) {
            toAngle += 2 * 3.14159;
          } else {
            fromAngle += 2 * 3.14159;
          }
        }

        _headingAnimation = Tween<double>(
          begin: fromAngle,
          end: toAngle,
        ).animate(CurvedAnimation(
          parent: _headingAnimationController,
          curve: Curves.easeInOut,
        ));

        _currentHeading = newHeading;
        _headingAnimationController.forward(from: 0.0);
        // debug print suppressed
      } else {
        // debug print suppressed
      }
    }
  }

  /// 산책 관련 데이터를 초기화하고 지도에 마커를 설정합니다.
  /// 사용자 프로필, 선물 상자, 깃발 마커를 생성하고 위치 추적을 시작합니다.
  Future<void> _initializeWalk() async {
    // 프로필/경유지/목적지 마커는 사용하지 않고, 오버레이 Lottie로 대체합니다.

    _walkStateManager.startWalk(
      start: widget.startLocation,
      destination: widget.destinationLocation,
      mate: widget.selectedMate,
      friendGroupType: widget.selectedMate.startsWith('친구(')
          ? (widget.selectedMate.contains('2명') ? 'two' : 'many')
          : null,
    );

    // 목적지 건물명이 있으면 WalkStateManager에 저장
    if (widget.destinationBuildingName != null) {
      _walkStateManager
          .setDestinationBuildingName(widget.destinationBuildingName);
    }
    // final LatLng? waypoint = _walkStateManager.waypointLocation;

    // 발자국 아이콘 프리로드
    _footprintIcon ??= await MapMarkerCreator.createFootprintMarkerBitmap(
      canvasSize: 56.0,
      emojiSize: 40.0,
    );

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
      distanceFilter: 5,
    )).listen((Position position) async {
      if (!mounted || _isProcessingEvent) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      // 발자국 추가: 일정 거리 이상 이동했을 때만 마커를 추가하여 과도한 표시 방지
      _maybeAddFootprint(_currentPosition!);

      // --- 방향 스위칭 + 보정 로직 ---
      // 방향 계산은 HeadingController로 일원화 (여기서는 오버레이/이벤트만 처리)

      // 진행방향 계산은 HeadingController에서 처리하므로 여기서는 저장 불필요

      await _updateOverlayPosition();
      await _updateOverlayPositions();

      final eventSignal =
          await _walkStateManager.updateUserLocation(_currentPosition!);

      if (!mounted || eventSignal == null) return;

      setState(() {
        _isProcessingEvent = true;
      });

      switch (eventSignal) {
        case "one_way_completed":
          // 단순화 플로우에서는 별도 처리 없음
          break;
        case "destination_reached":
          final bool? wantsToSeeEvent =
              await DestinationDialog.showDestinationArrivalDialog(
            context: context,
          );

          if (mounted) {
            setState(() {
              _showDestinationTeaseBubble = false;
            });
          }

          if (wantsToSeeEvent == true && context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PoseRecommendationScreen(
                  walkStateManager: _walkStateManager,
                ),
              ),
            );
          }
          break;

        case "start_returned":
          _positionStreamSubscription?.cancel();

          // 1. 기존 세션에 완료 시간/총 시간/총 거리 업데이트
          if (_walkStateManager.savedSessionId != null) {
            final walkSessionService = WalkSessionService();
            await walkSessionService.updateWalkSession(
              _walkStateManager.savedSessionId!,
              {
                'endTime': DateTime.now().toIso8601String(),
                'totalDuration': _walkStateManager.actualDurationInMinutes,
                'totalDistance': _walkStateManager.accumulatedDistanceKm,
              },
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
              selectedMate: widget.selectedMate,
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
    // 발자국(🐾) 마커들을 추가합니다.
    allMarkers.addAll(_footprintMarkers);

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
                  onCameraMove: (cam) {
                    _cameraBearing = cam.bearing;
                    _updateOverlayPosition();
                    _updateOverlayPositions();
                  },
                ),
          // 산책 모드 및 메이트 정보 표시 (AppBar 바로 아래)
          if (!_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 5, left: 20, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 산책 메이트 정보 표시
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: _getMateColor(widget.selectedMate),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getMateEmoji(widget.selectedMate),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.selectedMate,
                              style: TextStyle(
                                  color: _getMateColor(widget.selectedMate),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 단순화: 산책 모드 배지 제거
                    ],
                  ),
                ),
              ),
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
            hideDestinationTeaseBubble: () {
              if (mounted) {
                setState(() {
                  _showDestinationTeaseBubble = false;
                });
              }
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
            // 단순화: 모드 전달 제거
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
          // 경유지 Lottie 애니메이션 오버레이 (경유지 이벤트 발생 전까지만 표시)
          if (!_isLoading &&
              _waypointOverlayOffset != null &&
              !_walkStateManager.waypointEventOccurred)
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
          // 목적지 유도 말풍선: 경유지 이벤트(나중에/확인)가 발생한 뒤 목적지 도착 전까지 표시
          if (!_isLoading &&
              _destinationOverlayOffset != null &&
              _showDestinationTeaseBubble)
            Positioned(
              left: _destinationOverlayOffset!.dx - 40,
              top: _destinationOverlayOffset!.dy -
                  _destinationOverlayHeight -
                  22,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Text(
                          '얼른와..!',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      CustomPaint(
                        size: const Size(20, 10),
                        painter: SpeechBubbleTailPainter(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 경유지 말풍선: 경유지 도착 알림 전까지만 표시
          if (!_isLoading &&
              _waypointOverlayOffset != null &&
              !_walkStateManager.waypointEventOccurred)
            Positioned(
              left: _waypointOverlayOffset!.dx - 50,
              top: _waypointOverlayOffset!.dy - _waypointOverlayHeight - 22,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Text(
                          '어떤 선물이..?',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      CustomPaint(
                        size: const Size(20, 10),
                        painter: SpeechBubbleTailPainter(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 출발지 말풍선 제거
          // 출발지 Lottie 애니메이션 오버레이 (편도/왕복 모드 모두 표시)
          if (!_isLoading && _startOverlayOffset != null)
            Positioned(
              left: _startOverlayOffset!.dx - (_startOverlayWidth / 2),
              top: _startOverlayOffset!.dy -
                  _startOverlayHeight +
                  _overlayBottomTrim,
              child: IgnorePointer(
                ignoring: true,
                child: SizedBox(
                  width: _startOverlayWidth,
                  height: _startOverlayHeight,
                  child: lottie.Lottie.asset(
                    'assets/animations/house.json',
                    repeat: true,
                    animate: true,
                    alignment: Alignment.bottomCenter,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          // 현재 위치에 붙는 Lottie 애니메이션 오버레이 (최상위로 배치)
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
          // 현재 위치 말풍선 오버레이 (최상위로 배치)
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
          // 방향 화살표 (파란 세모) - 최상위로 배치
          if (!_isLoading &&
              _userOverlayOffset != null &&
              _currentHeading != null)
            Positioned(
              left: _userOverlayOffset!.dx +
                  (_overlayWidth / 2) -
                  20, // start.json 오른쪽
              top: _userOverlayOffset!.dy -
                  (_overlayHeight / 2) -
                  8, // start.json 중간 높이
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedBuilder(
                  animation: _headingAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      alignment: Alignment.center, // 중심점 고정
                      angle: _headingAnimation.value,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withValues(alpha: 0.9),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
