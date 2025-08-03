import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/presentation/utils/map_marker_creator.dart';
import 'package:walk/src/features/walk/presentation/utils/walk_event_handler.dart';
import 'package:walk/src/features/walk/presentation/widgets/walk_map_view.dart';

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

  /// 현재 위치를 표시하는 마커입니다.
  Marker? _currentLocationMarker;

  /// 목적지를 표시하는 마커입니다.
  Marker? _destinationMarker;

  /// 경유지를 표시하는 마커입니다.
  Marker? _waypointMarker;

  /// 산책 상태를 관리하는 매니저 인스턴스입니다.
  late WalkStateManager _walkStateManager;

  /// 현재 로그인한 Firebase 사용자 정보입니다.
  User? _user;

  /// 위치 스트림 구독을 관리하는 객체입니다.
  StreamSubscription<Position>? _positionStreamSubscription;

  /// 산책 이벤트 처리를 담당하는 핸들러 인스턴스입니다.
  late WalkEventHandler _walkEventHandler;

  /// 로컬 알림 플러그인 인스턴스입니다.
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  /// 경유지 이벤트 확인 버튼의 가시성을 제어합니다.
  bool _showWaypointEventButton = false;

  /// 마지막으로 발생한 경유지 질문 내용을 저장합니다.
  String? _lastWaypointQuestion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 옵저버 등록
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState; // 초기 상태 설정
    // 현재 사용자 정보를 가져옵니다.
    _user = FirebaseAuth.instance.currentUser;
    // WalkStateManager를 초기화합니다.
    _walkStateManager = WalkStateManager();
    // WalkEventHandler를 초기화합니다.
    _walkEventHandler = WalkEventHandler(
      context: context,
      walkStateManager: _walkStateManager,
    );

    // Local Notifications 초기화
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Android 아이콘 설정

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          debugPrint('notification payload: ${notificationResponse.payload}');
          _walkEventHandler.showQuestionDialog(notificationResponse.payload!);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          debugPrint(
              'background notification payload: ${notificationResponse.payload}');
          _walkEventHandler.showQuestionDialog(notificationResponse.payload!);
        }
      },
    );

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
    final LatLng? waypoint = _walkStateManager!.waypointLocation;

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

      final String? eventSignal = _walkStateManager
          .updateUserLocation(_currentPosition!); // null-safety
      if (eventSignal != null) {
        if (eventSignal == "destination_reached") {
          _positionStreamSubscription?.cancel();
          _walkEventHandler.showDestinationCard();
        } else {
          // 앱 상태에 따라 알림 방식 분기
          if (_lastLifecycleState == AppLifecycleState.resumed) {
            // 앱이 포그라운드일 때 스낵바 표시
            _showWaypointArrivalDialog(eventSignal);
          } else {
            // 앱이 백그라운드일 때 시스템 알림 표시
            _showWaypointNotification(eventSignal);
          }
        }
      }
    });
  }

  Future<void> _showWaypointNotification(String questionPayload) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('waypoint_channel_id', '경유지 알림',
            channelDescription: '경유지 도착 시 질문 알림',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false,
            icon: 'ic_walk_notification');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      '경유지 도착!',
      '경유지에 도착했습니다. 질문을 확인하시려면 탭하세요.',
      notificationDetails,
      payload: questionPayload,
    );
  }

  // 경유지 도착 시 표시할 다이얼로그
  Future<void> _showWaypointArrivalDialog(String questionPayload) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 사용자가 다이얼로그 바깥을 탭하여 닫을 수 없게 함
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.7), // 배경색
          shape: RoundedRectangleBorder(
            // 모양
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          title: const Text(
            '🚩 경유지 도착!', // 제목
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  '경유지에 도착했습니다. 이벤트를 확인하시겠습니까?', // 내용
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              // 버튼
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                setState(() {
                  _showWaypointEventButton = true;
                  _lastWaypointQuestion = questionPayload;
                });
                _walkEventHandler
                    .showQuestionDialog(questionPayload); // 질문 다이얼로그 표시
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // 원하는 색상으로 지정
              ),
              child: const Text('이벤트 확인'),
            ),
          ],
        );
      },
    );
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
                    _walkEventHandler
                        .showQuestionDialog(_lastWaypointQuestion!);
                  }
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
          if (!_isLoading && kDebugMode)
            Positioned(
              bottom: 32,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 경유지 도착 버튼
                  ElevatedButton(
                    onPressed: () {
                      if (_walkStateManager != null &&
                          _currentPosition != null) {
                        // 경유지 도착을 시뮬레이션하고 질문을 강제로 생성합니다.
                        final String? question = _walkStateManager!
                            .updateUserLocation(_currentPosition!,
                                forceWaypointEvent: true); // 강제 생성 옵션 추가
                        if (question != null) {
                          _showWaypointArrivalDialog(question);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    '경유지 질문 생성에 실패했습니다. 경유지가 없거나 다른 이벤트가 발생했습니다.')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'WalkStateManager 또는 현재 위치가 초기화되지 않았습니다.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('경유지 도착', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  // 목적지 도착 버튼
                  ElevatedButton(
                    onPressed: _walkEventHandler.showDestinationCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('목적지 도착', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
