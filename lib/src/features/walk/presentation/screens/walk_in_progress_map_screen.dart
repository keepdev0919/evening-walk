import 'dart:async';
import 'dart:convert'; // Add this import
import 'package:flutter/services.dart'; // Add this import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/presentation/utils/map_marker_creator.dart';
import 'package:walk/src/features/walk/presentation/widgets/walk_map_view.dart';
import 'package:walk/src/features/walk/presentation/widgets/waypointDialog.dart';
import 'package:walk/src/features/walk/presentation/widgets/debugmode_button.dart';
import 'package:walk/src/features/walk/presentation/utils/notification_service.dart';
import 'package:walk/src/features/walk/presentation/widgets/destinationDialog.dart';

/// 이 파일은 산책이 진행 중일 때 지도를 표시하고 사용자 위치를 추적하며,
/// 경유지 및 목적지 도착 이벤트를 처리하는 화면을 담당합니다.
/// 사용자의 현재 위치, 목적지, 경유지를 지도에 마커로 표시하고,
/// 특정 지점에 도달했을 때 관련 이벤트를 발생시킵니다.

class WalkInProgressMapScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng destinationLocation;
  final String selectedMate;

  const WalkInProgressMapScreen({
    Key? key,
    required this.startLocation,
    required this.destinationLocation,
    required this.selectedMate,
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
  User? _user;

  /// 위치 스트림 구독을 관리하는 객체입니다.
  StreamSubscription<Position>? _positionStreamSubscription;

  late NotificationService _notificationService;

  /// 경유지 이벤트 확인 버튼의 가시성을 제어합니다.
  bool _showWaypointEventButton = false;
  bool _showDestinationEventButton = false;

  /// 마지막으로 발생한 경유지 질문 내용을 저장합니다.
  String? _lastWaypointQuestion;
  String? _currentDestinationPoseImageUrl;
  String? _currentDestinationTakenPhotoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 옵저버 등록
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState; // 초기 상태 설정
    // 현재 사용자 정보를 가져옵니다.
    _user = FirebaseAuth.instance.currentUser;
    // WalkStateManager를 초기화합니다.
    _walkStateManager = WalkStateManager();

    _notificationService =
        NotificationService(FlutterLocalNotificationsPlugin());
    _notificationService.initialize(context);

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
  }

  /// 산책 관련 데이터를 초기화하고 지도에 마커를 설정합니다.
  /// 사용자 프로필, 선물 상자, 깃발 마커를 생성하고 위치 추적을 시작합니다.
  Future<void> _initializeWalk() async {
    final profileMarker =
        await MapMarkerCreator.createCustomProfileMarkerBitmap(_user);
    final giftBoxMarker = await MapMarkerCreator.createGiftBoxMarkerBitmap();
    final flagMarker = await MapMarkerCreator.createDestinationMarkerBitmap();

    _walkStateManager.startWalk(
      start: widget.startLocation,
      destination: widget.destinationLocation,
      mate: widget.selectedMate,
    );
    final LatLng? waypoint = _walkStateManager.waypointLocation;

    setState(() {
      _currentPosition = widget.startLocation;
      _currentLocationMarker = Marker(
        markerId: const MarkerId('current_position'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: '현재 위치'),
        icon: profileMarker,
        anchor: const Offset(0.5, 1.0),
      );
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: widget.destinationLocation,
        infoWindow: const InfoWindow(title: '목적지'),
        icon: flagMarker,
        anchor: const Offset(0.5, 1.0),
      );
      if (waypoint != null) {
        _waypointMarker = Marker(
          markerId: const MarkerId('waypoint'),
          position: waypoint,
          infoWindow: const InfoWindow(title: '경유지'),
          icon: giftBoxMarker,
          anchor: const Offset(0.5, 1.0),
        );
      }
      _isLoading = false; // 로딩 완료
    });

    _startLocationTracking();
  }

  /// 사용자의 위치 추적을 시작합니다.
  /// Geolocator를 사용하여 실시간 위치 업데이트를 받고 지도에 반영합니다.
  Future<void> _startLocationTracking() async {
    // ... (Permission checks are correct)

    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    )).listen((Position position) {
      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _currentLocationMarker = _currentLocationMarker?.copyWith(
          positionParam: _currentPosition,
        );
      });

      // updateUserLocation이 Future를 반환하므로 .then()으로 결과를 처리합니다.
      _walkStateManager
          .updateUserLocation(_currentPosition!)
          .then((eventSignal) {
        if (!mounted) return; // 결과를 처리하기 전에 위젯이 여전히 마운트 상태인지 확인

        if (eventSignal != null) {
          if (eventSignal == "destination_reached") {
            _positionStreamSubscription?.cancel();
            DestinationDialog.showDestinationArrivalDialog(
              context: context,
              walkStateManager: _walkStateManager,
              selectedMate: widget.selectedMate,
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
            );
          } else {
            // 앱 상태에 따라 알림 방식 분기
            if (_lastLifecycleState == AppLifecycleState.resumed) {
              // 앱이 포그라운드일 때 스낵바 표시
              WaypointDialogs.showWaypointArrivalDialog(
                context: context,
                questionPayload: eventSignal,
                updateWaypointEventState: (show, question) {
                  setState(() {
                    _showWaypointEventButton = show;
                    _lastWaypointQuestion = question;
                  });
                },
              );
            } else {
              // 앱이 백그라운드일 때 시스템 알림 표시
              _notificationService.showWaypointNotification(eventSignal);
            }
          }
        }
      });
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
                  color: Colors.black.withOpacity(0.6),
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
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: const Text(
                  '산책 중',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
        centerTitle: true,
        actions: [
          if (_showWaypointEventButton)
            Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.card_giftcard, color: Colors.orange),
                onPressed: () {
                  if (_lastWaypointQuestion != null) {
                    WaypointDialogs.showQuestionDialog(
                        context, _lastWaypointQuestion!);
                  }
                },
              ),
            ),
          if (_showDestinationEventButton)
            Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.flag, color: Colors.red),
                onPressed: () {
                  DestinationDialog.showPoseRecommendationDialog(
                    context: context,
                    walkStateManager: _walkStateManager,
                    selectedMate: widget.selectedMate,
                    updateDestinationEventState: (show) {
                      setState(() {
                        _showDestinationEventButton = show;
                      });
                    },
                    initialPoseImageUrl: _currentDestinationPoseImageUrl,
                    initialTakenPhotoPath: _currentDestinationTakenPhotoPath,
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
                ),
          // 디버그 모드일 때만 경유지/목적지 도착 버튼을 표시합니다. 로딩 중에는 표시하지 않습니다.
          DebugModeButtons(
            isLoading: _isLoading,
            currentPosition: _currentPosition,
            walkStateManager: _walkStateManager,
            selectedMate: widget.selectedMate,
            updateWaypointEventState: (show, question) {
              setState(() {
                _showWaypointEventButton = show;
                _lastWaypointQuestion = question;
              });
            },
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
          ),
        ],
      ),
    );
  }
}
