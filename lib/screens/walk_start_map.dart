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
import 'package:walk/screens/select_mate.dart';

/// 산책 시작 전 목적지를 설정하는 지도 화면입니다.
class WalkStartMapScreen extends StatefulWidget {
  const WalkStartMapScreen({super.key});

  @override
  State<WalkStartMapScreen> createState() => _WalkStartMapScreenState();
}

class _WalkStartMapScreenState extends State<WalkStartMapScreen> {
  // --- 지도 및 위치 관련 변수 ---
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  bool _isLoading = true;

  // --- 마커 관련 변수 ---
  Marker? _currentLocationMarker;
  Marker? _destinationMarker;
  LatLng? _selectedDestination;
  String _selectedAddress = "";

  // --- Firebase 및 API 관련 변수 ---
  User? _user;
  final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _determinePosition();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _determinePosition() async {
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _currentLocationMarker = Marker(
        markerId: const MarkerId('current_position'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: '현재 위치'),
      );
      _isLoading = false;
    });
    _updateMarkerWithProfileImage();
  }

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

    final Paint circlePaint = Paint()..color = Colors.white;
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

  void _onMapTap(LatLng position) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 불러오는 중입니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    const double allowedRadius = 1700.0;

    if (distance > allowedRadius) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('목적지는 최대 빨간원까지만 설정할 수 있습니다.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final address = await _getAddressFromLatLng(position);

    setState(() {
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: position,
        infoWindow: InfoWindow(title: address),
      );
      _selectedDestination = position;
      _selectedAddress = address;
    });

    _showDestinationBottomSheet();
  }

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

  void _showDestinationBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedAddress,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  child: const Text('목적지로 설정하기'),
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDestination();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('목적지 설정 완료: $_selectedAddress'),
          duration: const Duration(seconds: 2),
        ),
      ).closed.whenComplete(() {
        // SnackBar가 닫힌 후에 화면 전환
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectMateScreen(
              startLocation: _currentPosition!,
              destinationLocation: _selectedDestination!,
            ),
          ),
        );
      });
    }
  }

  // --- 랜덤 목적지 관련 함수 ---

  /// 두 가지 산책 옵션을 선택하는 다이얼로그를 표시합니다.
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
                const Icon(Icons.explore_outlined,
                    color: Colors.white70, size: 40),
                const SizedBox(height: 16),
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
                    backgroundColor: Colors.green[400],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _findRandomDestination(minDistance: 850, maxDistance: 1700);
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  child: const Text('다음에 할게요',
                      style: TextStyle(color: Colors.white70)),
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
  Future<void> _findRandomDestination(
      {required double minDistance, required double maxDistance}) async {
    if (_currentPosition == null) return;

    final SnackBar snackBar = const SnackBar(content: Text('주변의 멋진 장소를 찾고 있어요...'));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    for (int i = 0; i < 10; i++) { // 최대 10번 시도
      final randomPoint = _calculateRandomPoint(_currentPosition!, minDistance, maxDistance);
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
      const SnackBar(content: Text('추천할 만한 장소를 찾지 못했어요. 다시 시도해주세요.')),
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
    Set<Marker> allMarkers = {};
    if (_currentLocationMarker != null) {
      allMarkers.add(_currentLocationMarker!);
    }
    if (_destinationMarker != null) {
      allMarkers.add(_destinationMarker!);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: const Text(
            '목적지를 설정해주세요',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 14.5,
                  ),
                  onTap: _onMapTap,
                  circles: {
                    Circle(
                      circleId: const CircleId('walk_radius_15min'),
                      center: _currentPosition!,
                      radius: 850,
                      fillColor: Colors.blue.withOpacity(0.1),
                      strokeColor: Colors.blue,
                      strokeWidth: 2,
                    ),
                    Circle(
                      circleId: const CircleId('walk_radius_30min'),
                      center: _currentPosition!,
                      radius: 1700,
                      fillColor: Colors.red.withOpacity(0.1),
                      strokeColor: Colors.red,
                      strokeWidth: 2,
                    ),
                  },
                  markers: allMarkers,
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + kToolbarHeight),
                ),
          if (!_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '파란 원은 보통 도보로 15분, 빨간 원은 30분 정도 걸리는 거리에요. 참고해서 목적지를 정해보세요!'),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_outlined,
                          size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        '이 원은 뭔가요?',
                        style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: const Text(
              '어디 갈지 고민된다면?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _showRandomDestinationDialog,
            tooltip: '랜덤 목적지',
            child: const Icon(Icons.shuffle),
          ),
        ],
      ),
    );
  }
}
