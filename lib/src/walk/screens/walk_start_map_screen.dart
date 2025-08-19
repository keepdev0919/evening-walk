import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart' as lottie;
import 'package:walk/src/walk/screens/walk_in_progress_map_screen.dart';
// import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/core/services/log_service.dart';
import 'package:walk/src/walk/utils/heading_controller.dart';
// 진행 화면의 상태 기반 말풍선 대신, 시작 화면은 독립 말풍선을 사용합니다.

/// 이 파일은 사용자가 산책을 시작하기 전에 목적지를 설정하는 지도 화면을 담당합니다.
/// 현재 위치를 기반으로 지도를 표시하고, 사용자가 지도를 탭하여 목적지를 선택하거나
/// 랜덤 목적지 기능을 통해 새로운 산책 경로를 탐색할 수 있도록 합니다.

/// 산책 시작 전 목적지를 설정하는 지도 화면입니다.
class WalkStartMapScreen extends StatefulWidget {
  // 단순화 플로우: 왕복/편도 제거
  const WalkStartMapScreen({super.key, this.preloadedPosition});

  /// 미리 로딩된 위치 정보입니다.
  /// null이면 일반적인 로딩 과정을 거칩니다.
  final LatLng? preloadedPosition;

  @override
  State<WalkStartMapScreen> createState() => _WalkStartMapScreenState();
}

class _WalkStartMapScreenState extends State<WalkStartMapScreen>
    with TickerProviderStateMixin {
  // --- 지도 및 위치 관련 변수 ---
  /// Google Map 컨트롤러. 지도 제어에 사용됩니다.
  late GoogleMapController mapController;

  /// 사용자의 현재 위치를 저장하는 LatLng 객체입니다.
  LatLng? _currentPosition;

  /// 지도 로딩 상태를 나타내는 플래그입니다. true이면 로딩 중, false이면 로딩 완료입니다.
  bool _isLoading = true;

  // --- 마커 관련 변수 ---
  /// 현재 위치를 표시하는 마커입니다.
  Marker? _currentLocationMarker;

  /// 사용자가 선택한 목적지를 표시하는 마커입니다.
  Marker? _destinationMarker;

  /// 사용자가 선택한 목적지의 LatLng 값입니다.
  LatLng? _selectedDestination;

  /// 사용자가 선택한 목적지의 주소 문자열입니다.
  String _selectedAddress = "";
  bool _isManualSelection = false; // 사용자가 직접 선택했는지 여부
  TextEditingController? _destNameController; // 사용자 이름 편집 컨트롤러
  bool _isDestNameFocused = false; // 목적지 이름 입력 포커스 유지 상태

  // --- Firebase 및 API 관련 변수 ---
  /// 현재 로그인한 Firebase 사용자 정보입니다.
  // User? _user; // 현재 사용 안 함

  /// 현재 위치 Lottie 오버레이 좌표 및 크기
  Offset? _userOverlayOffset;
  static const double _overlayWidth = 84;
  static const double _overlayHeight = 84;
  static const double _bubbleWidth = 200;
  static const double _bubbleOffsetY = 56; // 현재 위치 아이콘 위로 띄우는 거리

  /// Google 지도 컨트롤러 (오버레이 위치 계산용)
  GoogleMapController? _googleMapController;

  /// Google Maps API 키입니다. .env 파일에서 로드됩니다.
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;

  // --- 방향(컴퍼스) 관련 ---
  double? _currentHeading; // 현재 각도(도)
  late AnimationController _headingAnimationController;
  late Animation<double> _headingAnimation; // 라디안 단위
  // 컴퍼스 직접 구독 제거. HeadingController를 사용합니다.
  // StreamSubscription<CompassEvent>? _compassSubscription; // deprecated
  HeadingController? _headingController;
  StreamSubscription<double>? _headingSub;
  double _cameraBearing = 0.0;
  StreamSubscription<Position>? _positionStreamSubscription;

  double _normalizeDegrees(double angle) {
    double a = angle % 360.0;
    if (a < 0) a += 360.0;
    return a;
  }

  @override
  void initState() {
    super.initState();

    // 미리 로딩된 위치 정보가 있다면 초기화를 건너뜁니다
    if (widget.preloadedPosition != null) {
      _isLoading = false;
      _currentPosition = widget.preloadedPosition;
      return;
    }

    // 현재 사용자 정보를 가져옵니다.
    // _user = FirebaseAuth.instance.currentUser;
    // 현재 위치를 결정하고 지도를 초기화합니다.
    _headingAnimationController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _headingAnimation = Tween<double>(begin: 0.0, end: 0.0)
        .animate(_headingAnimationController);

    // 통합 헤딩 컨트롤러 시작 및 구독 (지도의 bearing 보정 적용)
    _headingController = HeadingController()..start();
    _headingSub = _headingController!.stream.listen((deg) {
      final double corrected = _normalizeDegrees(deg - _cameraBearing);
      _updateUserHeading(corrected);
    });
    // 위치 스트림 구독: 오버레이 좌표 최신화 및 heading 보조값
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      if (!mounted) return;
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      await _updateOverlayPosition();
      // 위치만 갱신. 방향은 HeadingController로 일원화
    });
    _determinePosition();
  }

  @override
  void dispose() {
    // _compassSubscription?.cancel();
    _headingSub?.cancel();
    _headingController?.dispose();
    _positionStreamSubscription?.cancel();
    _headingAnimationController.dispose();
    super.dispose();
  }

  // --- 방향 보조 함수들 ---
  // 각도 정규화/보간은 현재 로직에서 직접 처리되어 사용하지 않음 (정리)

  // 사용하지 않는 보간 함수는 제거 (경량화)

  void _updateUserHeading(double newHeading) {
    if (_currentHeading == null) {
      _currentHeading = newHeading;
      _headingAnimation = Tween<double>(
        begin: newHeading * (3.14159 / 180),
        end: newHeading * (3.14159 / 180),
      ).animate(_headingAnimationController);
      if (mounted) setState(() {});
      return;
    }

    double angleDiff = (newHeading - _currentHeading!).abs();
    if (angleDiff > 180) angleDiff = 360 - angleDiff;
    if (angleDiff <= 3) return; // 작은 변화 무시

    double fromAngle = _currentHeading! * (3.14159 / 180);
    double toAngle = newHeading * (3.14159 / 180);
    if ((newHeading - _currentHeading!).abs() > 180) {
      if (_currentHeading! > newHeading) {
        toAngle += 2 * 3.14159;
      } else {
        fromAngle += 2 * 3.14159;
      }
    }
    _headingAnimation = Tween<double>(begin: fromAngle, end: toAngle).animate(
      CurvedAnimation(
          parent: _headingAnimationController, curve: Curves.easeInOut),
    );
    _currentHeading = newHeading;
    _headingAnimationController.forward(from: 0.0);
  }

  /// 지도가 생성될 때 호출되는 콜백 함수입니다.
  /// GoogleMapController를 초기화하고 오버레이 위치를 업데이트합니다.
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _googleMapController = controller;
    // 초기 오버레이 위치 계산
    Future.delayed(const Duration(milliseconds: 100), () {
      _updateOverlayPosition();
    });
  }

  /// 사용자의 현재 위치를 비동기적으로 결정합니다.
  /// 위치 권한을 요청하고, 현재 위치를 가져와 지도에 표시합니다.
  Future<void> _determinePosition() async {
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _currentLocationMarker = Marker(
        markerId: const MarkerId('current_position'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: '현재 위치'),
      );
      _isLoading = false; // 로딩 완료
    });
    // Lottie 오버레이 위치 계산
    _updateOverlayPosition();
  }

  /// 현재 위치 Lottie 오버레이 위치를 업데이트합니다.
  Future<void> _updateOverlayPosition() async {
    if (_currentPosition != null && _googleMapController != null) {
      final ScreenCoordinate screenCoordinate =
          await _googleMapController!.getScreenCoordinate(_currentPosition!);

      if (mounted) {
        setState(() {
          final dpr = MediaQuery.of(context).devicePixelRatio;
          _userOverlayOffset = Offset(
            screenCoordinate.x.toDouble() / dpr,
            screenCoordinate.y.toDouble() / dpr,
          );
          // 마커는 null로 설정하여 Lottie로 대체
          _currentLocationMarker = null;
        });
      }
    }
  }

  /// 목적지 마커로 사용할 깃발 아이콘 비트맵을 생성합니다.
  /// 외부 에셋 없이 Canvas로 그려서 즉시 사용 가능합니다.
  Future<BitmapDescriptor> _createFlagMarkerBitmap({
    Color poleColor = Colors.black87,
    Color flagColor = Colors.redAccent,
    double size = 120.0,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // 배경을 투명으로 유지
    final Paint transparentPaint = Paint()..color = Colors.transparent;
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), transparentPaint);

    // 폴(막대)
    final double poleWidth = size * 0.06;
    final double poleHeight = size * 0.78;
    final double poleLeft = size * 0.48;
    final double poleTop = size * 0.12;
    final RRect poleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(poleLeft, poleTop, poleWidth, poleHeight),
      Radius.circular(poleWidth / 2),
    );
    final Paint polePaint = Paint()
      ..color = poleColor
      ..isAntiAlias = true;
    canvas.drawRRect(poleRect, polePaint);

    // 깃발 (삼각형)
    final double flagStartX = poleLeft + poleWidth; // 막대 오른쪽에서 시작
    final double flagStartY = poleTop + poleWidth; // 상단에서 약간 아래
    final double flagWidth = size * 0.36;
    final double flagHeight = size * 0.22;
    final Path flagPath = Path()
      ..moveTo(flagStartX, flagStartY)
      ..lineTo(flagStartX + flagWidth, flagStartY + flagHeight * 0.2)
      ..lineTo(flagStartX, flagStartY + flagHeight)
      ..close();
    final Paint flagPaint = Paint()
      ..color = flagColor
      ..isAntiAlias = true;
    canvas.drawPath(flagPath, flagPaint);

    // 바닥 그림자(말풍선 핀 느낌의 기준점 강조)
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.drawCircle(
        Offset(size * 0.5, size * 0.98), size * 0.06, shadowPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  /// 지도를 탭했을 때 호출되는 함수입니다.
  /// 탭한 위치를 목적지로 설정하고, 현재 위치와의 거리를 계산하여 유효성을 검사합니다.
  /// 유효한 목적지인 경우 하단 시트를 표시합니다.
  void _onMapTap(LatLng position) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('현재 위치를 불러오는 중입니다. 잠시 후 다시 시도해주세요. ✨'),
          backgroundColor: Colors.black.withValues(alpha: 0.6),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    const double allowedRadius = 1700.0; // 1.7km 반경

    if (distance > allowedRadius) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white),
              children: const [
                TextSpan(text: '목적지는 최대 '),
                TextSpan(text: '빨간원', style: TextStyle(color: Colors.red)),
                TextSpan(text: '까지만 설정할 수 있습니다.'),
              ],
            ),
          ),
          backgroundColor: Colors.black.withValues(alpha: 0.6),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    // 사용자가 직접 위치를 선택: 역지오코딩으로 주소 표시, 이름 편집 허용
    final String address = await _reverseGeocode(position);
    final BitmapDescriptor flagIcon = await _createFlagMarkerBitmap();
    setState(() {
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: position,
        infoWindow: InfoWindow(title: address),
        icon: flagIcon,
        anchor: const Offset(0.5, 1.0),
      );
      _selectedDestination = position;
      _selectedAddress = address;
      _isManualSelection = true;
    });

    // 목적지 이름 편집 입력값을 현재 주소로 동기화
    if (_destNameController == null) {
      _destNameController = TextEditingController(text: _selectedAddress);
    } else {
      _destNameController!.text = _selectedAddress;
    }
    _showDestinationBottomSheet();
  }

  // 주소 조회 함수는 현재 사용되지 않아 제거했습니다.

  /// 목적지 설정 확인을 위한 하단 시트를 표시합니다.
  void _showDestinationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final EdgeInsets insets = MediaQuery.of(ctx).viewInsets;
        return StatefulBuilder(builder: (ctx, setInner) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, insets.bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 드래그 핸들
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 목적지 헤더
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF667EEA).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: const Color(0xFF667EEA),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '목적지',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_isManualSelection) ...[
                      const SizedBox(height: 24),
                      const Text(
                        '목적지 이름 수정',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2D3748),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isDestNameFocused
                                ? const Color(0xFF667EEA)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Focus(
                          onFocusChange: (hasFocus) => setInner(() {
                            _isDestNameFocused = hasFocus;
                          }),
                          child: TextField(
                            controller: _destNameController ??=
                                TextEditingController(text: _selectedAddress),
                            maxLength: 300,
                            style: const TextStyle(
                              color: Color(0xFF2D3748),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: '예) 노을 맛집 우리동네 언덕',
                              hintStyle: TextStyle(
                                color: Colors.grey.withValues(alpha: 0.5),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                              contentPadding: const EdgeInsets.all(20),
                              border: InputBorder.none,
                              counterText: '',
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: Colors.grey.withValues(alpha: 0.6),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _destNameController?.clear();
                                  },
                                  tooltip: '텍스트 지우기',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // 액션 버튼
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF667EEA).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _confirmDestination();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_walk_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  '이곳으로 산책 떠나기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  /// 선택된 목적지를 최종 확인하고 다음 화면으로 전환합니다.
  void _confirmDestination() async {
    if (_selectedDestination != null) {
      final BitmapDescriptor flagIcon = await _createFlagMarkerBitmap(
        flagColor: Colors.greenAccent,
        poleColor: Colors.black87,
      );
      final String finalName = _isManualSelection
          ? ((_destNameController?.text.trim().isNotEmpty ?? false)
              ? _destNameController!.text.trim()
              : _selectedAddress)
          : _selectedAddress;
      setState(() {
        _destinationMarker = Marker(
          markerId: const MarkerId('destination'),
          position: _selectedDestination!,
          infoWindow: InfoWindow(title: finalName),
          icon: flagIcon,
          anchor: const Offset(0.5, 1.0),
        );
      });
      // 바로 메이트/방식 통합 시트를 표시 (목적지 설정 완료 스낵바 제거)
      _showMateAndModeSheet(finalName: finalName);
    }
  }

  /// 목적지 확정 후, 메이트 선택 + 산책 방식(왕복/편도)을 한 번에 선택하는 바텀시트
  void _showMateAndModeSheet({required String finalName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _MateSheet(
          finalName: finalName,
          onStart: (selectedMateLabel) {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WalkInProgressMapScreen(
                  startLocation: _currentPosition!,
                  destinationLocation: _selectedDestination!,
                  selectedMate: selectedMateLabel,
                  destinationBuildingName: finalName,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 랜덤 목적지 관련 함수 ---

  /// 두 가지 산책 옵션(15분, 30분)을 선택하는 다이얼로그를 표시합니다.
  void _showRandomDestinationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_walk_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '어떤 산책을 원하세요?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 15분 산책 버튼
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        offset: const Offset(0, 4),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        _findRandomDestination(
                            minDistance: 500, maxDistance: 850);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_walk_rounded,
                              color: const Color(0xFF764ba2),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '가볍게 15분',
                              style: TextStyle(
                                color: Color(0xFF2D3748),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 30분 산책 버튼
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        offset: const Offset(0, 4),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        _findRandomDestination(
                            minDistance: 850, maxDistance: 1700);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: const Color(0xFF764ba2),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '여유롭게 30분',
                              style: TextStyle(
                                color: Color(0xFF2D3748),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              color: Colors.grey.withValues(alpha: 0.7),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '다음에 할게요',
                              style: TextStyle(
                                color: Colors.grey.withValues(alpha: 0.7),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 설정된 거리 내에서 랜덤 목적지 탐색을 시작하는 메인 함수입니다.
  /// Google Places API를 사용하여 유효한 장소를 찾습니다.
  Future<void> _findRandomDestination(
      {required double minDistance, required double maxDistance}) async {
    if (_currentPosition == null) return;

    final SnackBar snackBar = SnackBar(
      content: const Text(
        '주변 장소를 살펴보는 중이에요... ✨',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.black.withValues(alpha: 0.6),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    for (int i = 0; i < 10; i++) {
      // 최대 10번 시도
      final randomPoint =
          _calculateRandomPoint(_currentPosition!, minDistance, maxDistance);
      final placeDetails = await _validatePlaceNearby(randomPoint);

      if (placeDetails != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar(); // 기존 스낵바 숨기기
        final placeName = placeDetails['name'];
        final placeLocation = placeDetails['location'];

        final BitmapDescriptor flagIcon = await _createFlagMarkerBitmap();

        setState(() {
          _destinationMarker = Marker(
            markerId: const MarkerId('destination'),
            position: placeLocation,
            infoWindow: InfoWindow(title: placeName),
            icon: flagIcon,
            anchor: const Offset(0.5, 1.0),
          );
          _selectedDestination = placeLocation;
          _selectedAddress = placeName;
        });

        // 목적지 이름 편집 입력값을 현재 주소로 동기화
        if (_destNameController == null) {
          _destNameController = TextEditingController(text: _selectedAddress);
        } else {
          _destNameController!.text = _selectedAddress;
        }

        mapController.animateCamera(CameraUpdate.newLatLng(placeLocation));
        _showDestinationBottomSheet();
        return; // 성공 시 함수 종료
      }
    }

    // 10번 시도 후에도 실패하면 사용자에게 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '추천할 만한 장소를 찾지 못했어요. 다시 시도해주세요. ✨',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 주어진 중심점에서 특정 반경 내의 랜덤한 좌표를 계산합니다.
  LatLng _calculateRandomPoint(
      LatLng center, double minRadius, double maxRadius) {
    final random = Random();
    final distance = minRadius + random.nextDouble() * (maxRadius - minRadius);
    final bearing = random.nextDouble() * 360.0;

    final double lat1 = center.latitude * pi / 180;
    final double lon1 = center.longitude * pi / 180;
    final double brng = bearing * pi / 180;
    final double d = distance / 6371000; // 지구 반지름 (미터)

    final double lat2 =
        asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng));
    final double lon2 = lon1 +
        atan2(sin(brng) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2));

    return LatLng(lat2 * 180 / pi, lon2 * 180 / pi);
  }

  /// Google Places API를 사용하여 해당 좌표가 유효한 장소인지 검증합니다.
  /// 주변의 관심 지점, 공원, 카페, 식당, 관광 명소를 검색합니다.
  Future<Map<String, dynamic>?> _validatePlaceNearby(LatLng position) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${position.latitude},${position.longitude}&radius=100&key=$_googleApiKey&language=ko&type=point_of_interest|park|cafe|restaurant|tourist_attraction';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          return {
            'name': result['name'],
            'location': LatLng(location['lat'], location['lng']),
          };
        }
      }
    } catch (e) {
      LogService.error('Walk', 'Google Places API error', e);
    }
    return null;
  }

  Future<String> _reverseGeocode(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        String safe(String? v) {
          if (v == null) return '';
          final t = v.trim();
          if (t.isEmpty) return '';
          if (t == '.' || t == '·' || t == '-') return '';
          return t;
        }

        final String country = safe(p.country); // 대한민국 등
        final String region = safe(p.administrativeArea); // 경기도
        final String cityA = safe(p.locality); // 용인시/수원시 등 (시)
        final String cityB = safe(p.subAdministrativeArea); // 기흥구/영통구 등 (구/군)
        final String district = safe(p.subLocality); // 영덕동/영통동 등 (동)
        final String road = safe(p.thoroughfare); // 도로명
        final String number = safe(p.subThoroughfare); // 번지
        final String street = safe(p.street); // 일부 기기에서 상위 행정구역 포함

        // 표시 파츠: 시/도(region) 제외, 시(cityA) + 구/군(cityB) + 동(district)
        final List<String> parts = [];
        if (cityA.isNotEmpty) parts.add(cityA);
        if (cityB.isNotEmpty && cityB != cityA && !cityA.contains(cityB)) {
          parts.add(cityB);
        }
        if (district.isNotEmpty) parts.add(district);

        // 도로명 + 번지 우선. 없으면 street 정리해서 사용
        String tail = '';
        if (road.isNotEmpty) {
          tail = number.isNotEmpty ? '$road $number' : road;
        } else if (street.isNotEmpty) {
          String sanitized = street;
          for (final token in [country, region, cityA, cityB, district]) {
            if (token.isNotEmpty) {
              sanitized = sanitized.replaceAll(token, '');
            }
          }
          sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (sanitized.isNotEmpty &&
              sanitized != cityA &&
              sanitized != cityB &&
              sanitized != district) {
            tail = sanitized;
          }
        }

        if (tail.isNotEmpty) parts.add(tail);

        // 중복 제거 유지
        final List<String> deduped = [];
        for (final p in parts) {
          if (p.isEmpty) continue;
          if (!deduped.contains(p)) deduped.add(p);
        }

        if (deduped.isNotEmpty) return deduped.join(' ');
      }
    } catch (_) {}
    return '주소 미확인 지점';
  }

  @override
  Widget build(BuildContext context) {
    // 모든 마커를 담을 Set을 초기화합니다.
    Set<Marker> allMarkers = {};
    // 현재 위치 마커가 있으면 추가합니다.
    if (_currentLocationMarker != null) {
      allMarkers.add(_currentLocationMarker!);
    }
    // 목적지 마커가 있으면 추가합니다.
    if (_destinationMarker != null) {
      allMarkers.add(_destinationMarker!);
    }

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
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
        // 제목 ("목적지를 설정해주세요"): 로딩 중에는 표시하지 않습니다.
        title: _isLoading
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18.0, vertical: 11.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_walk_rounded,
                      color: Colors.black,
                      size: 24,
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      '어디로 산책을 떠날까요?',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
        centerTitle: true, // 제목을 중앙에 정렬합니다.
      ),
      body: Stack(
        fit: StackFit.expand, // 스택의 자식 위젯들이 가능한 모든 공간을 차지하도록 합니다.
        children: [
          // 로딩 중이면 CircularProgressIndicator를 표시하고, 아니면 GoogleMap을 표시합니다.
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: _onMapCreated, // 지도 생성 시 호출될 콜백 함수
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!, // 초기 카메라 위치는 현재 위치
                    zoom: 14.5, // 초기 줌 레벨
                  ),
                  onTap: _onMapTap, // 지도를 탭했을 때 호출될 콜백 함수
                  onCameraMove: (CameraPosition position) {
                    // 카메라 이동 시 오버레이 위치 업데이트 및 bearing 보정값 유지
                    _cameraBearing = position.bearing;
                    _updateOverlayPosition();
                  },
                  circles: {
                    // 15분 산책 반경을 나타내는 파스텔 블루 원
                    Circle(
                      circleId: const CircleId('walk_radius_15min'),
                      center: _currentPosition!,
                      radius: 850, // 850미터 반경
                      fillColor: const Color(0xFF87CEEB)
                          .withValues(alpha: 0.15), // 스카이 블루 채우기
                      strokeColor: const Color(0xFF4A90E2), // 부드러운 파란색 테두리
                      strokeWidth: 3, // 테두리 두께 약간 증가
                    ),
                    // 30분 산책 반경을 나타내는 파스텔 핑크 원
                    Circle(
                      circleId: const CircleId('walk_radius_30min'),
                      center: _currentPosition!,
                      radius: 1700, // 1700미터 반경
                      fillColor: const Color(0xFFFFB6C1)
                          .withValues(alpha: 0.15), // 라이트 핑크 채우기
                      strokeColor: const Color(0xFFFF6B9D), // 부드러운 핑크 테두리
                      strokeWidth: 3,
                    ),
                  },
                  markers: allMarkers, // 지도에 표시될 모든 마커
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top +
                          kToolbarHeight), // 상단 패딩
                ),
          // 감성적인 그라디언트 오버레이 추가 (터치 이벤트는 지도로 통과하도록 처리)
          if (!_isLoading)
            IgnorePointer(
              ignoring: true,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15), // 상단 은은한 오버레이
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1), // 하단 은은한 오버레이
                    ],
                    stops: const [0.0, 0.2, 0.8, 1.0],
                  ),
                ),
              ),
            ),
          // 로딩이 완료되면 "이 원은 뭔가요?" 텍스트를 표시합니다.
          if (!_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 4),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          backgroundColor: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.95),
                                  Colors.white.withValues(alpha: 0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24.0),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  offset: const Offset(0, 4),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  offset: const Offset(0, 2),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.help_outline_rounded,
                                      color: Colors.black,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      '산책 거리 안내',
                                      style: TextStyle(
                                        color: Color(0xFF2D3748),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF4A90E2)
                                            .withValues(alpha: 0.1),
                                        const Color(0xFF87CEEB)
                                            .withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20.0),
                                    border: Border.all(
                                      color: const Color(0xFF4A90E2)
                                          .withValues(alpha: 0.3),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4A90E2),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF2D3748),
                                              fontWeight: FontWeight.w600,
                                              height: 1.3,
                                            ),
                                            children: [
                                              const TextSpan(text: '파란 원'),
                                              const TextSpan(text: '은 보통 '),
                                              const TextSpan(
                                                text: '15분',
                                                style: TextStyle(
                                                  color: Color(0xFF4A90E2),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const TextSpan(
                                                  text: ' 정도의 산책거리예요'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFFF6B9D)
                                            .withValues(alpha: 0.1),
                                        const Color(0xFFFFB6C1)
                                            .withValues(alpha: 0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20.0),
                                    border: Border.all(
                                      color: const Color(0xFFFF6B9D)
                                          .withValues(alpha: 0.3),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF6B9D),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF2D3748),
                                              fontWeight: FontWeight.w600,
                                              height: 1.3,
                                            ),
                                            children: [
                                              const TextSpan(text: '빨간 원'),
                                              const TextSpan(text: '은 보통 '),
                                              const TextSpan(
                                                text: '30분',
                                                style: TextStyle(
                                                  color: Color(0xFFFF6B9D),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const TextSpan(
                                                  text: ' 정도의 산책거리예요'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop();
                                      },
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              color: Colors.grey
                                                  .withValues(alpha: 0.7),
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '알겠어요',
                                              style: TextStyle(
                                                color: Colors.grey
                                                    .withValues(alpha: 0.7),
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                height: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 20,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 6),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF2D3748),
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          children: [
                            const TextSpan(
                              text: '파란원',
                              style: TextStyle(
                                color: Color(0xFF4A90E2),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: '? '),
                            const TextSpan(
                              text: '빨간원',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: '?'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 현재 위치에 붙는 Lottie 애니메이션 오버레이
          if (!_isLoading && _userOverlayOffset != null)
            Positioned(
              left: _userOverlayOffset!.dx - (_overlayWidth / 2),
              top: _userOverlayOffset!.dy - _overlayHeight,
              child: IgnorePointer(
                ignoring: true,
                child: SizedBox(
                  width: _overlayWidth,
                  height: _overlayHeight,
                  child: lottie.Lottie.asset(
                    'assets/animations/start.json',
                    repeat: true,
                    animate: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          // 방향 화살표 (폰이 바라보는 방향) - 사용자 위치 중심 정렬
          if (!_isLoading &&
              _userOverlayOffset != null &&
              _currentHeading != null)
            Positioned(
              left: _userOverlayOffset!.dx - 12,
              top: _userOverlayOffset!.dy - 12,
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedBuilder(
                  animation: _headingAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      alignment: Alignment.center,
                      angle: _headingAnimation.value,
                      child: Container(
                        width: 24,
                        height: 24,
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
                          size: 16,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // 현재 위치에 붙는 말풍선 오버레이 (시작 화면 전용 텍스트)
          if (!_isLoading && _userOverlayOffset != null)
            Positioned(
              left: _userOverlayOffset!.dx - (_bubbleWidth / 2),
              top:
                  _userOverlayOffset!.dy - _overlayHeight - _bubbleOffsetY + 20,
              child: IgnorePointer(
                ignoring: true,
                child: SizedBox(
                  width: _bubbleWidth,
                  child: _StartBubble(text: '헛둘.. 헛둘..'),
                ),
              ),
            ),
          // 진행 화면 의존 위젯 제거 (독립 텍스트 말풍선만 사용)
        ],
      ),
      // 플로팅 액션 버튼: 로딩 중에는 표시하지 않습니다.
      floatingActionButton: _isLoading
          ? null
          : Container(
              margin: const EdgeInsets.only(left: 30, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 세련된 그라데이션 버튼
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF667eea),
                          Color(0xFF764ba2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667eea).withValues(alpha: 0.4),
                          offset: const Offset(0, 8),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showRandomDestinationDialog,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 개선된 말풍선 디자인
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.95),
                          Colors.white.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          offset: const Offset(0, 4),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: const Color(0xFF764ba2),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '어디 갈지 고민된다면?',
                          style: TextStyle(
                            color: Color(0xFF2D3748),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// 시작 화면 전용 간단 말풍선 위젯 (문자열만 받아 표시)
class _StartBubble extends StatelessWidget {
  final String text;
  const _StartBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        CustomPaint(
            size: const Size(20, 10), painter: _StartBubbleTailPainter()),
      ],
    );
  }
}

class _StartBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white;
    final border = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.7, 0)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 바텀시트 전용 독립 StatefulWidget: 내부 상태 유지(mate, friendGroup, selectedMode)
class _MateSheet extends StatefulWidget {
  final String finalName;
  final void Function(String selectedMateLabel) onStart;
  const _MateSheet({
    required this.finalName,
    required this.onStart,
  });

  @override
  State<_MateSheet> createState() => _MateSheetState();
}

class _MateSheetState extends State<_MateSheet> with TickerProviderStateMixin {
  String? mate; // '혼자' | '연인' | '친구'
  String? friendGroup; // 'two' | 'many'
  AnimationController? _slideController;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));
    _slideController!.forward();
  }

  @override
  void dispose() {
    _slideController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets insets = MediaQuery.of(context).viewInsets;
    final bool canStart = mate != null && (mate != '친구' || friendGroup != null);

    final slideAnimation = _slideAnimation;

    if (slideAnimation == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF0F0F23),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, insets.bottom + 24),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    return SlideTransition(
      position: slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, insets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 드래그 핸들
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 목적지 헤더
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.group_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '함께할 메이트를 선택해주세요',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.finalName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 메이트 선택 카드들
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '산책 메이트',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF2D3748),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 메이트 옵션들
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        {'label': '🌙 혼자', 'value': '혼자', 'desc': '나만의 시간'},
                        {'label': '💕 연인', 'value': '연인', 'desc': '달콤한 산책'},
                        {'label': '👫 친구', 'value': '친구', 'desc': '함께 걸어요'},
                        {'label': '🐕 반려견', 'value': '반려견', 'desc': '댕댕이와'},
                        {
                          'label': '👨‍👩‍👧‍👦 가족',
                          'value': '가족',
                          'desc': '가족과 함께'
                        },
                      ].map((opt) {
                        final String label = opt['label'] as String;
                        final String value = opt['value'] as String;
                        final String desc = opt['desc'] as String;
                        final bool selected = mate == value;

                        return GestureDetector(
                          onTap: () => setState(() {
                            mate = value;
                            if (value != '친구') friendGroup = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2)
                                      ],
                                    )
                                  : null,
                              color: selected
                                  ? null
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Colors.transparent
                                    : const Color(0xFFE5E7EB),
                                width: 2.0,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF667EEA)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Color(0xFF2D3748),
                                    fontSize: 16,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white70
                                        : Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // 친구 선택 시 인원수 옵션
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return SizeTransition(
                          sizeFactor: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: mate == '친구'
                          ? Container(
                              key: const ValueKey('friend_options'),
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '몇 명과 함께 하시나요?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2D3748),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildFriendGroupOption('2명', 'two'),
                                      const SizedBox(width: 12),
                                      _buildFriendGroupOption('여러명', 'many'),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('empty'),
                            ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 액션 버튼들
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: const Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: Color(0xFF2D3748),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: canStart
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2)
                                  ],
                                )
                              : null,
                          color: canStart
                              ? null
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: canStart
                                ? Colors.transparent
                                : const Color(0xFFE5E7EB),
                            width: 2.0,
                          ),
                          boxShadow: canStart
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF667EEA)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canStart
                                ? () {
                                    final String selectedMateLabel = () {
                                      if (mate == '친구') {
                                        return friendGroup == 'two'
                                            ? '친구(2명)'
                                            : '친구(여러명)';
                                      }
                                      return mate!;
                                    }();
                                    widget.onStart(selectedMateLabel);
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_walk_rounded,
                                    color: canStart
                                        ? Colors.white
                                        : Color(0xFF9CA3AF),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '산책 시작하기',
                                    style: TextStyle(
                                      color: canStart
                                          ? Colors.white
                                          : Color(0xFF9CA3AF),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendGroupOption(String label, String value) {
    final bool selected = friendGroup == value;
    return GestureDetector(
      onTap: () => setState(() {
        friendGroup = value;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE5E7EB),
            width: 2.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Color(0xFF2D3748),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
