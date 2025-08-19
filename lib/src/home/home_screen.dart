import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';

import 'package:walk/src/walk/screens/walk_start_map_screen.dart';
import 'package:walk/src/walk/screens/walk_loading_screen.dart';
import 'package:walk/src/walk/screens/walk_history_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../common/widgets/black_cat_widget.dart';
import 'package:walk/src/core/services/log_service.dart';
import 'package:walk/src/core/services/analytics_service.dart';

// 상태 구분용 enum
enum InfoStatus { loading, success, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 날씨 및 위치
  String _location = '';
  String _weather = '';

  // 날씨 상태 저장 (고양이 텍스트용)
  String? _weatherCondition;

  final String _apiKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';
  InfoStatus _locationStatus = InfoStatus.loading;
  InfoStatus _weatherStatus = InfoStatus.loading;

  // 스낵바 중복 표시 방지
  bool _hasShownSnackBar = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 스낵바 메시지가 있는지 확인하고 표시 (중복 방지)
    if (!_hasShownSnackBar) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final successMessage = args['showSuccessMessage'] as String?;
        if (successMessage != null) {
          _hasShownSnackBar = true;
          // 다음 프레임에서 스낵바 표시 (빌드 완료 후)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(successMessage),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });
        }
      }
    }
  }

  // 위치 정보 재시도 메서드
  Future<void> _retryLocationRequest() async {
    setState(() {
      _locationStatus = InfoStatus.loading;
      _weatherStatus = InfoStatus.loading;
    });
    await _determinePosition();
  }

  // 위치 권한 및 날씨 정보 가져오기
  Future<void> _determinePosition() async {
    try {
      LogService.info('UI', 'HomeScreen: 위치 권한 확인 시작');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LogService.debug('UI', 'HomeScreen: 위치 서비스 활성화 상태: $serviceEnabled');

      if (!serviceEnabled) {
        LogService.warning('UI', 'HomeScreen: 위치 서비스가 비활성화됨');
        setState(() {
          _location = '위치 서비스 꺼짐';
          _locationStatus = InfoStatus.error;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      LogService.debug('UI', 'HomeScreen: 현재 위치 권한 상태: $permission');

      if (permission == LocationPermission.denied) {
        LogService.info('UI', 'HomeScreen: 위치 권한 요청 중...');
        permission = await Geolocator.requestPermission();
        LogService.debug('UI', 'HomeScreen: 위치 권한 요청 결과: $permission');

        if (permission == LocationPermission.denied) {
          setState(() {
            _location = '위치 권한 거부됨';
            _locationStatus = InfoStatus.error;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        LogService.warning('UI', 'HomeScreen: 위치 권한이 영구적으로 거부됨');
        setState(() {
          _location = '위치 권한 영구 거부';
          _locationStatus = InfoStatus.error;
        });
        return;
      }
    } catch (e) {
      LogService.error('UI', 'HomeScreen: 위치 권한 확인 중 오류 발생', e);
      setState(() {
        _location = '권한 확인 오류';
        _locationStatus = InfoStatus.error;
      });
      return;
    }

    try {
      LogService.info('UI', 'HomeScreen: GPS 위치 요청 시작');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // 정확도 조정으로 속도 향상
        timeLimit: const Duration(seconds: 15), // GPS 타임아웃 설정
      );

      LogService.info('UI',
          'HomeScreen: GPS 위치 획득 완료 - lat: ${position.latitude}, lon: ${position.longitude}');

      // 위치 정보와 날씨 정보를 병렬로 처리 (더 빠른 로딩)
      await Future.wait([
        _getAddressFromLatLng(position),
        _getWeather(position.latitude, position.longitude),
      ]);
    } catch (e) {
      LogService.error('UI', 'HomeScreen: 위치/날씨 정보 가져오기 실패', e);
      setState(() {
        if (_locationStatus == InfoStatus.loading) {
          _location = '위치 정보 오류';
          _locationStatus = InfoStatus.error;
        }
        if (_weatherStatus == InfoStatus.loading) {
          _weather = '🌤️ 날씨 정보 오류';
          _weatherStatus = InfoStatus.error;
        }
      });
    }
  }

  // 위도경도로 주소 가져오기
  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      LogService.debug('UI',
          'HomeScreen: 위치 정보 요청 시작 - lat: ${position.latitude}, lon: ${position.longitude}');

      // Timeout 설정으로 무한 대기 방지
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          LogService.warning('UI', 'HomeScreen: Geocoding API 타임아웃');
          throw Exception('위치 정보 요청 시간 초과');
        },
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        LogService.info('UI',
            'HomeScreen: 위치 정보 성공 - locality: ${place.locality}, subLocality: ${place.subLocality}');

        // locality와 subLocality 조합으로 더 구체적인 위치 정보 제공
        List<String> locationParts = [];

        // locality 먼저 추가 (시/구 - 예: 수원시)
        if (place.locality != null && place.locality!.isNotEmpty) {
          locationParts.add(place.locality!);
        }

        // subLocality 나중에 추가 (더 구체적인 지역 - 예: 영통구)
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          locationParts.add(place.subLocality!);
        }

        // 둘 다 없으면 상위 행정구역 사용
        if (locationParts.isEmpty) {
          if (place.subAdministrativeArea != null &&
              place.subAdministrativeArea!.isNotEmpty) {
            locationParts.add(place.subAdministrativeArea!);
          } else if (place.administrativeArea != null &&
              place.administrativeArea!.isNotEmpty) {
            locationParts.add(place.administrativeArea!);
          }
        }

        String locationText =
            locationParts.isNotEmpty ? locationParts.join(' ') : '위치 정보';

        setState(() {
          _location = locationText;
          _locationStatus = InfoStatus.success;
        });
      } else {
        LogService.warning('UI', 'HomeScreen: Geocoding 결과가 비어있음');
        setState(() {
          _location = '위치 정보 없음';
          _locationStatus = InfoStatus.error;
        });
      }
    } catch (e) {
      LogService.error('UI', 'HomeScreen: 위치 정보 가져오기 실패', e);
      setState(() {
        _location = '위치 정보 오류';
        _locationStatus = InfoStatus.error;
      });
    }
  }

  // 날씨 API 호출
  Future<void> _getWeather(double lat, double lon) async {
    try {
      LogService.info('UI', 'HomeScreen: 날씨 API 호출 시작 - lat: $lat, lon: $lon');
      LogService.debug(
          'UI', 'HomeScreen: API Key 존재 여부: ${_apiKey.isNotEmpty}');

      if (_apiKey.isEmpty) {
        LogService.warning('UI', 'HomeScreen: OpenWeather API 키가 설정되지 않음');
        setState(() {
          _weather = '🌤️ API 키 없음';
          _weatherStatus = InfoStatus.error;
        });
        return;
      }

      final response = await http
          .get(Uri.parse(
              'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=kr'))
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          LogService.warning('UI', 'HomeScreen: 날씨 API 타임아웃');
          throw Exception('날씨 API 요청 시간 초과');
        },
      );

      LogService.debug(
          'UI', 'HomeScreen: 날씨 API 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        LogService.info('UI', 'HomeScreen: 날씨 API 응답 성공');

        if (data['weather'] != null &&
            data['weather'].isNotEmpty &&
            data['main'] != null) {
          final weatherMain = data['weather'][0]['main']; // 날씨 상태
          final temperature = data['main']['temp'].round(); // 온도

          LogService.info('UI',
              'HomeScreen: 날씨 정보 파싱 성공 - 상태: $weatherMain, 온도: ${temperature}°C');

          setState(() {
            _weather = '${_getWeatherEmoji(weatherMain)} ${temperature}°C';
            _weatherStatus = InfoStatus.success;
            _weatherCondition = weatherMain; // 날씨 상태 저장
          });
        } else {
          LogService.error('UI', 'HomeScreen: 날씨 API 응답 데이터 형식 오류');
          setState(() {
            _weather = '🌤️ 날씨 데이터 오류';
            _weatherStatus = InfoStatus.error;
          });
        }
      } else {
        LogService.error('UI',
            'HomeScreen: 날씨 API HTTP 오류 - 상태 코드: ${response.statusCode}, 응답: ${response.body}');
        setState(() {
          _weather = '🌤️ API 오류';
          _weatherStatus = InfoStatus.error;
        });
      }
    } catch (e) {
      LogService.error('UI', 'HomeScreen: 날씨 정보 가져오기 실패', e);
      setState(() {
        _weather = '🌤️ 날씨 오류';
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

  // 날씨 상태에 따른 이모지 반환
  String _getWeatherEmoji(String weatherCondition) {
    switch (weatherCondition.toLowerCase()) {
      case 'clear':
        return '☀️'; // 맑음
      case 'clouds':
        return '☁️'; // 흐림
      case 'few clouds':
      case 'scattered clouds':
        return '⛅'; // 구름 조금
      case 'broken clouds':
      case 'overcast clouds':
        return '☁️'; // 흐림
      case 'rain':
      case 'light rain':
      case 'moderate rain':
        return '🌧️'; // 비
      case 'heavy rain':
      case 'extreme rain':
        return '🌧️'; // 폭우
      case 'drizzle':
        return '🌦️'; // 이슬비
      case 'thunderstorm':
        return '⛈️'; // 천둥번개
      case 'snow':
        return '❄️'; // 눈
      case 'mist':
      case 'fog':
      case 'haze':
        return '🌫️'; // 안개
      default:
        return '🌤️'; // 기본값
    }
  }

  // 날씨 텍스트 상태별 분기
  String getWeatherText() {
    switch (_weatherStatus) {
      case InfoStatus.loading:
        return '🌤️ 날씨 확인 중...';
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
        leadingWidth: 140, // leading 영역 너비 증가 (subLocality + locality 표시용)
        leading: Padding(
          padding: const EdgeInsets.only(left: 15.0),
          child: GestureDetector(
            onTap: () {
              // 위치 정보가 오류 상태일 때만 재시도
              if (_locationStatus == InfoStatus.error ||
                  _weatherStatus == InfoStatus.error) {
                _retryLocationRequest();
              }
            },
            child: _buildLocationWeatherInfo(),
          ),
        ),
        title: Text(
          '저녁산책',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 6,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 3,
                offset: const Offset(0.5, 0.5),
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
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLocationAndWeather,
        color: Colors.white,
        backgroundColor: Colors.blue.withValues(alpha: 0.8),
        child: Stack(
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

            // 콘텐츠를 스크롤 가능하게 만들기 (RefreshIndicator 작동을 위해)
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // 항상 스크롤 가능
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height - 100, // 충분한 높이 확보
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10), // AppBar 공간 확보

                        // 중앙 문구 - 감성적인 폰트와 그림자 효과
                        Text(
                          '저녁 공기를 마시며,\n가볍게 걸어볼까요?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 8,
                                offset: const Offset(2, 2),
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40), // AppBar 공간 확보

                        // 버튼 영역
                        Column(
                          children: [
                            // 산책하기 버튼 - 반투명 스타일
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const WalkLoadingScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 60,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Text(
                                  '산책 하기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // 산책 기록 버튼 - 반투명 스타일
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const WalkHistoryScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 60,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Text(
                                  '산책 기록',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 하단 Lottie 애니메이션과 말풍선 (디바이스 크기 비율 기반 위치/크기)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double screenWidth = constraints.maxWidth;
                  final double screenHeight = constraints.maxHeight;
                  // 크기 15% 증가
                  final double catWidth =
                      screenWidth * 0.28 * 2; // 화면 너비의 28% * 1.15
                  final double bottomPadding = screenHeight * 0.06; // 화면 높이의 6%
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: Transform.translate(
                        // 위치를 화면 너비의 15%만큼 왼쪽으로 이동
                        offset: Offset(-screenWidth * 0.23, 0),
                        child: BlackCatWidget(
                          width: catWidth,
                          bubbleMaxWidth: catWidth * 0.8,
                          screenType: 'home',
                          weatherCondition: _weatherCondition,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 위치와 날씨 정보를 2열로 표시하는 위젯
  Widget _buildLocationWeatherInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1열: 위치 정보
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on,
              size: 14,
              color: Colors.red,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                _getLocationDisplayText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      blurRadius: 2.0,
                      color: Colors.black54,
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        // 2열: 날씨 정보
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _getWeatherDisplayText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      blurRadius: 2.0,
                      color: Colors.black54,
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 위치 정보 간단 표시용 (AppBar용)
  String _getLocationDisplayText() {
    switch (_locationStatus) {
      case InfoStatus.loading:
        return '확인 중...';
      case InfoStatus.success:
        // 너무 길면 적절히 자르기 (subLocality + locality 조합 고려)
        if (_location.length > 12) {
          return _location.substring(0, 12);
        }
        return _location;
      case InfoStatus.error:
        return '오류';
    }
  }

  // 날씨 정보 간단 표시용 (AppBar용)
  String _getWeatherDisplayText() {
    switch (_weatherStatus) {
      case InfoStatus.loading:
        return '🌤️ 확인 중...';
      case InfoStatus.success:
        return _weather;
      case InfoStatus.error:
        return '🌤️ 오류';
    }
  }

  // Pull-to-Refresh 기능 - 위치와 날씨 정보 새로고침
  Future<void> _refreshLocationAndWeather() async {
    LogService.info('UI', 'HomeScreen: Pull-to-refresh 시작');

    setState(() {
      _locationStatus = InfoStatus.loading;
      _weatherStatus = InfoStatus.loading;
    });

    try {
      await _determinePosition();
      LogService.info('UI', 'HomeScreen: Pull-to-refresh 완료');
    } catch (e) {
      LogService.error('UI', 'HomeScreen: Pull-to-refresh 실패', e);
    }
  }
}
