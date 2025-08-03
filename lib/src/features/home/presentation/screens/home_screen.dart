import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walk/src/features/walk/presentation/screens/walk_start_map_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

// 상태 구분용 enum
enum InfoStatus { loading, success, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  Future<DocumentSnapshot>? _userFuture;

  // 날씨 및 위치
  String _location = '';
  String _weather = '';
  final String _apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
  InfoStatus _locationStatus = InfoStatus.loading;
  InfoStatus _weatherStatus = InfoStatus.loading;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    if (_user != null) {
      _userFuture = _firestore.collection('users').doc(_user!.uid).get();
    }
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
        _location = "📍 ${place.locality} ${place.thoroughfare}";
        _locationStatus = InfoStatus.success;
      });
    } catch (e) {
      setState(() {
        _location = "📍 주소를 불러올 수 없어요";
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
          _weather = '🌤 ${data['main']['temp']}°C';
          _weatherStatus = InfoStatus.success;
        });
      } else {
        setState(() {
          _weather = '🌤 날씨 정보를 불러올 수 없어요';
          _weatherStatus = InfoStatus.error;
        });
      }
    } catch (e) {
      setState(() {
        _weather = '🌤 날씨 정보를 가져오는 중 오류 발생';
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
      // AppBar를 투명하게 만들어 배경과 일체감을 줍니다.
      extendBodyBehindAppBar: true, // body를 AppBar 뒤까지 확장
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 배경색 투명
        elevation: 0, // 그림자 제거
        leading: Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: _buildProfileCircle(),
        ),
        title: const Text(
          '저녁산책',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black54,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Profile()),
              ).then((_) {
                // 프로필 화면에서 돌아왔을 때 상태 갱신
                setState(() {
                  if (_user != null) {
                    _userFuture =
                        _firestore.collection('users').doc(_user!.uid).get();
                  }
                });
              });
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

          // 콘텐츠
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Column(
                children: [
                  const SizedBox(height: 10), // AppBar 공간 확보

                  // 위치 및 날씨 정보
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoText(getLocationText()),
                      const SizedBox(width: 16),
                      _buildInfoText(getWeatherText()),
                    ],
                  ),

                  const Spacer(),

                  // 중앙 문구
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
                          blurRadius: 4.0,
                          color: Colors.black87,
                          offset: Offset(1.0, 1.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // 산책하기 버튼
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
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 프로필 사진 CircleAvatar를 빌드하는 위젯
  Widget _buildProfileCircle() {
    // 로그인하지 않은 사용자를 위한 기본 아이콘
    if (_user == null) {
      return const CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white54,
        child: Icon(Icons.person, size: 28, color: Colors.black87),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, snapshot) {
        // 로딩 중일 때
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white54,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black87),
            ),
          );
        }
        // 에러가 있거나 데이터가 없을 때
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white54,
            child: Icon(Icons.person, size: 28, color: Colors.black87),
          );
        }

        // 데이터가 성공적으로 로드되었을 때
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final imageUrl = userData['profileImageUrl'];

        return CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white,
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          child: imageUrl == null
              ? const Icon(Icons.person, size: 28, color: Colors.black87)
              : null,
        );
      },
    );
  }

  /// 위치/날씨 정보 텍스트 스타일을 적용하는 위젯
  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(
            blurRadius: 4.0,
            color: Colors.black54,
            offset: Offset(1.0, 1.0),
          ),
        ],
      ),
    );
  }
}
