import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:walk/src/features/walk/presentation/screens/select_mate_screen.dart';

/// 이 파일은 사용자가 산책을 시작하기 전에 목적지를 설정하는 지도 화면을 담당합니다.
/// 현재 위치를 기반으로 지도를 표시하고, 사용자가 지도를 탭하여 목적지를 선택하거나
/// 랜덤 목적지 기능을 통해 새로운 산책 경로를 탐색할 수 있도록 합니다.

/// 산책 시작 전 목적지를 설정하는 지도 화면입니다.
class WalkStartMapScreen extends StatefulWidget {
  const WalkStartMapScreen({super.key});

  @override
  State<WalkStartMapScreen> createState() => _WalkStartMapScreenState();
}

class _WalkStartMapScreenState extends State<WalkStartMapScreen> {
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

  // --- Firebase 및 API 관련 변수 ---
  /// 현재 로그인한 Firebase 사용자 정보입니다.
  User? _user;

  /// Google Maps API 키입니다. .env 파일에서 로드됩니다.
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;

  @override
  void initState() {
    super.initState();
    // 현재 사용자 정보를 가져옵니다.
    _user = FirebaseAuth.instance.currentUser;
    // 현재 위치를 결정하고 지도를 초기화합니다.
    _determinePosition();
  }

  /// 지도가 생성될 때 호출되는 콜백 함수입니다.
  /// GoogleMapController를 초기화합니다.
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
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
    // 프로필 이미지를 사용하여 현재 위치 마커를 업데이트합니다.
    _updateMarkerWithProfileImage();
  }

  /// 사용자 프로필 이미지를 사용하여 현재 위치 마커를 업데이트합니다.
  /// Firebase에서 프로필 이미지 URL을 가져와 마커 아이콘으로 사용합니다.
  Future<void> _updateMarkerWithProfileImage() async {
    String? imageUrl;
    if (_user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();
        if (userDoc.exists) {
          imageUrl = userDoc.data()?['profileImageUrl'];
        }
      } catch (e) {
        print("Failed to fetch user data for marker: $e");
      }
    }

    final BitmapDescriptor customMarker =
        await _createCustomMarkerBitmap(imageUrl);

    if (mounted) {
      setState(() {
        _currentLocationMarker = Marker(
          markerId: const MarkerId('current_position'),
          position: _currentPosition!,
          infoWindow: const InfoWindow(title: '현재 위치'),
          icon: customMarker,
          anchor: const Offset(0.5, 1.0),
        );
      });
    }
  }

  /// 주어진 이미지 URL을 사용하여 사용자 정의 마커 비트맵을 생성합니다.
  /// 프로필 이미지가 없으면 기본 회색 원을 표시합니다.
  Future<BitmapDescriptor> _createCustomMarkerBitmap(String? imageUrl) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double pinSize = 150.0;
    const double avatarRadius = 50.0;

    final Paint pinPaint = Paint()..color = Colors.blue;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    final Paint circlePaint = Paint()..color = Colors.black;
    canvas.drawCircle(
        const Offset(pinSize / 2, pinSize / 2), avatarRadius + 5, circlePaint);

    ui.Image? avatarImage;
    if (imageUrl != null) {
      try {
        final Uint8List bytes = (await http.get(Uri.parse(imageUrl))).bodyBytes;
        final ui.Codec codec = await ui.instantiateImageCodec(bytes,
            targetWidth: avatarRadius.toInt() * 2);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        avatarImage = frameInfo.image;
      } catch (e) {
        print('Error loading profile image for marker: $e');
      }
    }

    final Rect avatarRect = Rect.fromCircle(
        center: const Offset(pinSize / 2, pinSize / 2), radius: avatarRadius);
    final Path clipPath = Path()..addOval(avatarRect);
    canvas.clipPath(clipPath);

    if (avatarImage != null) {
      paintImage(
          canvas: canvas,
          rect: avatarRect,
          image: avatarImage,
          fit: BoxFit.cover);
    } else {
      final Paint placeholderPaint = Paint()..color = Colors.grey[300]!;
      canvas.drawCircle(avatarRect.center, avatarRadius, placeholderPaint);
    }

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
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
          content: const Text('현재 위치를 불러오는 중입니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Colors.black.withOpacity(0.6),
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
          content: const Text('목적지는 최대 빨간원까지만 설정할 수 있습니다.'),
          backgroundColor: Colors.black.withOpacity(0.6),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Places API로 근처 건물 검색
    final placeDetails = await _validatePlaceNearby(position);
    String displayName;
    LatLng finalPosition;

    if (placeDetails != null) {
      // 건물이 발견된 경우
      displayName = placeDetails['name'];
      finalPosition = placeDetails['location'];
      print('건물 발견: $displayName');
    } else {
      // 건물이 없는 경우 주소 사용
      displayName = await _getAddressFromLatLng(position);
      finalPosition = position;
      print('건물 없음, 주소 사용: $displayName');
    }

    setState(() {
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: finalPosition,
        infoWindow: InfoWindow(title: displayName),
      );
      _selectedDestination = finalPosition;
      _selectedAddress = displayName;
    });

    _showDestinationBottomSheet();
  }

  /// LatLng 좌표로부터 주소를 가져옵니다.
  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      Placemark place = placemarks[0];
      return "${place.street}";
    } catch (e) {
      return "주소를 찾을 수 없습니다.";
    }
  }

  /// 목적지 설정 확인을 위한 하단 시트를 표시합니다.
  void _showDestinationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0), // 패딩
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7), // 반투명 검정 배경
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white54, width: 1), // 얇은 테두리
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedAddress,
                      style: const TextStyle(
                        fontSize: 18, // 폰트 크기
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // 텍스트 색상
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDestination();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF4A90E2).withOpacity(0.8), // 부드러운 블루
                    foregroundColor: Colors.white, // 텍스트 색상
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25), // 둥근 모서리
                      side: const BorderSide(
                          color: Colors.white54, width: 0.5), // 얇은 테두리
                    ),
                    elevation: 0, // 그림자 제거
                    padding: const EdgeInsets.symmetric(vertical: 14), // 패딩
                  ),
                  child: const Text('이곳으로 산책 떠나기'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 선택된 목적지를 최종 확인하고 다음 화면으로 전환합니다.
  void _confirmDestination() async {
    if (_selectedDestination != null) {
      setState(() {
        _destinationMarker = Marker(
          markerId: const MarkerId('destination'),
          position: _selectedDestination!,
          infoWindow: InfoWindow(title: _selectedAddress),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content: Text(
                '목적지 설정 완료: $_selectedAddress',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          )
          .closed
          .whenComplete(() {
        // SnackBar가 닫힌 후에 화면 전환
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectMateScreen(
              startLocation: _currentPosition!,
              destinationLocation: _selectedDestination!,
              destinationBuildingName: _selectedAddress, // 건물명 또는 주소 전달
            ),
          ),
        );
      });
    }
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
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // const Icon(Icons.favorite_outline,
                //     color: Colors.white70, size: 40),
                // const SizedBox(height: 16),
                const Text(
                  '어떤 산책을 원하세요?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // 15분 산책 버튼
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('가볍게 15분'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF87CEEB).withOpacity(0.9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _findRandomDestination(minDistance: 500, maxDistance: 850);
                  },
                ),
                const SizedBox(height: 12),
                // 30분 산책 버튼
                ElevatedButton.icon(
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('여유롭게 30분'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B9D).withOpacity(0.8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _findRandomDestination(minDistance: 850, maxDistance: 1700);
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  child: const Text('다음에 할게요',
                      style: TextStyle(color: Colors.white70, fontSize: 18)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
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
        '주변 장소를 살펴보는 중이에요...',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.black.withOpacity(0.6),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
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

        setState(() {
          _destinationMarker = Marker(
            markerId: const MarkerId('destination'),
            position: placeLocation,
            infoWindow: InfoWindow(title: placeName),
          );
          _selectedDestination = placeLocation;
          _selectedAddress = placeName;
        });

        mapController.animateCamera(CameraUpdate.newLatLng(placeLocation));
        _showDestinationBottomSheet();
        return; // 성공 시 함수 종료
      }
    }

    // 10번 시도 후에도 실패하면 사용자에게 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '추천할 만한 장소를 찾지 못했어요. 다시 시도해주세요.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.6),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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
      print('Google Places API error: $e');
    }
    return null;
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
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: const Text(
                  '어디로 산책을 떠날까요?',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
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
                  circles: {
                    // 15분 산책 반경을 나타내는 파스텔 블루 원
                    Circle(
                      circleId: const CircleId('walk_radius_15min'),
                      center: _currentPosition!,
                      radius: 850, // 850미터 반경
                      fillColor: const Color(0xFF87CEEB)
                          .withOpacity(0.15), // 스카이 블루 채우기
                      strokeColor: const Color(0xFF4A90E2), // 부드러운 파란색 테두리
                      strokeWidth: 3, // 테두리 두께 약간 증가
                    ),
                    // 30분 산책 반경을 나타내는 파스텔 핑크 원
                    Circle(
                      circleId: const CircleId('walk_radius_30min'),
                      center: _currentPosition!,
                      radius: 1700, // 1700미터 반경
                      fillColor: const Color(0xFFFFB6C1)
                          .withOpacity(0.15), // 라이트 핑크 채우기
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
                      Colors.black.withOpacity(0.15), // 상단 은은한 오버레이
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.1), // 하단 은은한 오버레이
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '파란 원은 15분, 빨간 원은 30분 정도의 여유로운 산책거리에요.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.blue,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline_rounded,
                          size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        '이 원들은 뭐예요?',
                        style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      // 플로팅 액션 버튼: 로딩 중에는 표시하지 않습니다.
      floatingActionButton: _isLoading
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: const Text(
                    '어디 갈지 고민된다면?',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _showRandomDestinationDialog,
                  backgroundColor: const Color(0xFF4A90E2).withOpacity(0.9),
                  tooltip: '랜덤 목적지',
                  child: const Icon(
                    Icons.explore,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}
