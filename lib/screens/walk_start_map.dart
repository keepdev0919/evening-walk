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

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _onMapTap(LatLng position) async {
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  child: const Text('목적지로 설정하기'),
                  onPressed: () {
                    _confirmDestination();
                    Navigator.pop(context); // Bottom Sheet 닫기
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SelectMateScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDestination() {
    if (_selectedDestination != null) {
      setState(() {
        // 목적지가 확정되었음을 표시 (마커 색상 변경)
        _destinationMarker = Marker(
          markerId: const MarkerId('destination'),
          position: _selectedDestination!,
          infoWindow: InfoWindow(title: _selectedAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('목적지 설정 완료: $_selectedAddress')),
      );
      // TODO: 이후 경로 탐색 등 다음 작업으로 연결
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SelectMateScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> allMarkers = {};
    if (_currentLocationMarker != null) {
      allMarkers.add(_currentLocationMarker!);}
    if (_destinationMarker != null) {
      allMarkers.add(_destinationMarker!);}

    return Scaffold(
      appBar: AppBar(
        title: const Text('목표 지점 선택'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 15.0,
              ),
              onTap: _onMapTap, // 지도 탭 이벤트 연결
              circles: {
                Circle(
                  circleId: const CircleId('walk_radius'),
                  center: _currentPosition!,
                  radius: 1200,
                  fillColor: Colors.blue.withOpacity(0.1),
                  strokeColor: Colors.blue,
                  strokeWidth: 2,
                ),
              },
              markers: allMarkers,
            ),
    );
  }
}
