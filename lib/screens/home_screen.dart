import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';

import 'package:walk/screens/walk_start_map.dart';
import './profile.dart';

// 상태 구분용 enum
enum InfoStatus { loading, success, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _location = '';
  String _weather = '';
  final String _apiKey = dotenv.env['OPENWEATHER_API_KEY']!;

  InfoStatus _locationStatus = InfoStatus.loading;
  InfoStatus _weatherStatus = InfoStatus.loading;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // 위치 권한 및 날씨 정보 가져오기
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _location = '위치 서비스가 꺼져 있어요';
        _locationStatus = InfoStatus.error;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _location = '위치 권한이 거부되었어요';
          _locationStatus = InfoStatus.error;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _location = '위치 권한이 영구적으로 거부되었어요';
        _locationStatus = InfoStatus.error;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      await _getAddressFromLatLng(position);
      await _getWeather(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _location = '위치를 가져오는 중 오류가 발생했어요';
        _locationStatus = InfoStatus.error;
        _weather = '날씨 정보를 불러올 수 없어요';
        _weatherStatus = InfoStatus.error;
      });
    }
  }

  // 위도경도로 주소 가져오기
  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      Placemark place = placemarks[0];
      setState(() {
        _location = "${place.locality} ${place.thoroughfare}";
        _locationStatus = InfoStatus.success;
      });
    } catch (e) {
      setState(() {
        _location = "주소를 불러올 수 없어요";
        _locationStatus = InfoStatus.error;
      });
    }
  }

  // 날씨 API 호출
  Future<void> _getWeather(double lat, double lon) async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=kr'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _weather = '${data['main']['temp']}°C';
          _weatherStatus = InfoStatus.success;
        });
      } else {
        setState(() {
          _weather = '날씨 정보를 불러올 수 없어요';
          _weatherStatus = InfoStatus.error;
        });
      }
    } catch (e) {
      setState(() {
        _weather = '날씨 정보를 가져오는 중 오류 발생';
        _weatherStatus = InfoStatus.error;
      });
    }
  }

  // 위치 텍스트 상태별 분기
  String getLocationText() {
    switch (_locationStatus) {
      case InfoStatus.loading:
        return '📍 위치 불러오는 중...';
      case InfoStatus.success:
        return _location;
      case InfoStatus.error:
        return _location;
    }
  }

  // 날씨 텍스트 상태별 분기
  String getWeatherText() {
    switch (_weatherStatus) {
      case InfoStatus.loading:
        return '🌤 날씨 확인 중...';
      case InfoStatus.success:
        return _weather;
      case InfoStatus.error:
        return _weather;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '저녁산책',
        ),
        backgroundColor: Color(0xFF2C3E50),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Profile()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nature_walk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 어둡게 오버레이
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          // 위치 + 날씨 정보
          Positioned(
            top: 10,
            left: 25,
            right: 25,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getLocationText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    shadows: [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black54,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  getWeatherText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    shadows: [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black54,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 중앙 문구 + 산책 버튼
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '오늘 하루도 수고했어요\n가볍게 걸어볼까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black87,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const WalkStartMapScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 18,
                    ),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    '산책하기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
