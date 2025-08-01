import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';

import 'package:walk/screens/walk_start_map.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _location = '위치 정보 없음';
  String _weather = '날씨 정보 없음';
  final String _apiKey = dotenv.env['OPENWEATHER_API_KEY']!;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _location = '위치 서비스가 비활성화되었습니다.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _location = '위치 권한이 거부되었습니다.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _location = '위치 권한이 영구적으로 거부되었습니다.';
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    _getAddressFromLatLng(position);
    _getWeather(position.latitude, position.longitude);
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];
      setState(() {
        _location = "${place.locality} ${place.thoroughfare}";
      });
    } catch (e) {
      setState(() {
        _location = "주소를 불러올 수 없습니다.";
      });
    }
  }

  Future<void> _getWeather(double lat, double lon) async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=kr'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _weather =
              '${data['main']['temp']}°C, ${data['weather'][0]['description']}';
        });
      } else {
        setState(() {
          _weather = '날씨 정보를 불러올 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _weather = '날씨 정보를 불러오는 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ 자연 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/nature_walk.jpg'), // 📸 직접 넣은 배경 이미지 경로
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ✅ 반투명 오버레이 (텍스트 가독성용)
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

          // ✅ 내용
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _location,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _weather,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  '오늘 하루도 수고했어요\n\n가볍게 걸어볼까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WalkStartMapScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '산책하기',
                    style: TextStyle(fontSize: 18),
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