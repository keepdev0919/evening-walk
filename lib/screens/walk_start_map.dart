import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:walk/screens/select_mate.dart';

class WalkStartMapScreen extends StatefulWidget {
  const WalkStartMapScreen({super.key});

  @override
  State<WalkStartMapScreen> createState() => _WalkStartMapScreenState();
}

class _WalkStartMapScreenState extends State<WalkStartMapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  bool _isLoading = true;

  Marker? _currentLocationMarker;
  Marker? _destinationMarker;
  LatLng? _selectedDestination;
  String _selectedAddress = "";

  @override
  void initState() {
    super.initState();
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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      _isLoading = false;
    });
  }

  void _onMapTap(LatLng position) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 불러오는 중입니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    // Calculate distance between current position and tapped position
    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    const double allowedRadius = 1700.0; // The radius of the blue circle

    if (distance > allowedRadius) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('목적지는 최대 빨간원까지만 설정할 수 있습니다.'),
          duration: Duration(seconds: 3),
        ),
      );
      return; // Do not proceed with setting destination
    }

    // 1. 탭한 위치의 주소 정보 가져오기
    final address = await _getAddressFromLatLng(position);

    setState(() {
      // 2. 목적지 마커 업데이트
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: position,
        infoWindow: InfoWindow(title: address),
      );
      _selectedDestination = position;
      _selectedAddress = address;
    });

    // 3. 하단 정보 패널(Bottom Sheet) 표시
    _showDestinationBottomSheet();
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      Placemark place = placemarks[0];
      // 예: "대한민국 서울특별시 중구 세종대로 110"
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
                    Navigator.pop(context); // Bottom Sheet 닫기
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
        // 목적지가 확정되었음을 표시 (마커 색상 변경)
        _destinationMarker = Marker(
          markerId: const MarkerId('destination'),
          position: _selectedDestination!,
          infoWindow: InfoWindow(title: _selectedAddress),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('목적지 설정 완료: $_selectedAddress')),
      );

      // SelectMateScreen 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectMateScreen(
            startLocation: _currentPosition!,
            destinationLocation: _selectedDestination!,
          ),
        ),
      );
    }
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
      appBar: AppBar(
        title: const Text('목적지를 설정해주세요'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // 표준 뒤로 가기 아이콘
          onPressed: () {
            Navigator.pop(context); // 이전 화면으로 돌아가기
          },
        ),
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
                  onTap: _onMapTap, // 지도 탭 이벤트 연결
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
                      radius: 1700, // 15분 반경의 2배
                      fillColor: Colors.red.withOpacity(0.1),
                      strokeColor: Colors.red,
                      strokeWidth: 2,
                    ),
                  },
                  markers: allMarkers,
                ),
          // 지도 위에 도움말 아이콘과 텍스트 배치
          if (!_isLoading)
            Positioned(
              top: 10, // AppBar 아래 여백
              left: 10, // 좌측 여백
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8), // 배경색
                  borderRadius: BorderRadius.circular(8),
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
                      const Icon(Icons.help_outline,
                          size: 20, color: Colors.black87),
                      const Text(
                        '이 원은 뭔가요?',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
