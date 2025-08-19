import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/map_loading_service.dart';
import 'walk_start_map_screen.dart';

/// 말풍선 꼬리를 그리는 커스텀 페인터
class SpeechBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 말풍선 꼬리 경로 생성
    final Path path = Path();
    path.moveTo(size.width / 2 - 8, 0); // 왼쪽 시작점
    path.lineTo(size.width / 2, size.height); // 아래쪽 끝점
    path.lineTo(size.width / 2 + 8, 0); // 오른쪽 시작점
    path.close();

    // 그림자 효과를 위한 path (약간 아래쪽으로 오프셋)
    final Path shadowPath = Path();
    shadowPath.moveTo(size.width / 2 - 8, 2);
    shadowPath.lineTo(size.width / 2, size.height + 2);
    shadowPath.lineTo(size.width / 2 + 8, 2);
    shadowPath.close();

    // 그림자 그리기
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shadowPath, shadowPaint);

    // 꼬리 그리기
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// 산책 시작 전 로딩 화면입니다.
/// start.json 애니메이션과 "조금만 기다려줘..." 말풍선을 표시하고,
/// 실제 맵 로딩이 완료되면 자동으로 맵 화면으로 이동합니다.
class WalkLoadingScreen extends StatefulWidget {
  const WalkLoadingScreen({super.key});

  @override
  State<WalkLoadingScreen> createState() => _WalkLoadingScreenState();
}

class _WalkLoadingScreenState extends State<WalkLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _prepareMap();
  }

  /// 애니메이션을 초기화합니다
  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  /// 맵 준비를 시작하고 로딩이 완료되면 화면을 전환합니다
  Future<void> _prepareMap() async {
    try {
      // 최소 1초는 애니메이션을 보여줍니다
      await Future.delayed(const Duration(seconds: 1));

      // 실제 맵 로딩 상태를 확인합니다 (더 정확한 렌더링 상태까지 확인)
      final result = await MapLoadingService.instance.isMapRenderingComplete();
      bool isMapReady = result['success'] == true;

      if (mounted) {
        if (isMapReady) {
          // 맵이 완전히 로딩된 경우 위치 정보와 함께 이동
          _navigateToMap(result['position'] as LatLng);
        } else {
          // 타임아웃 발생 시에도 이동 (사용자 경험을 위해)
          _navigateToMap(null);
        }
      }
    } catch (e) {
      // 오류 발생 시 최소 2초 후 이동
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _navigateToMap(null);
      }
    }
  }

  /// 맵 화면으로 이동합니다
  void _navigateToMap(LatLng? preloadedPosition) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WalkStartMapScreen(preloadedPosition: preloadedPosition),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 배경 이미지 (기존 nature_walk.jpg 사용)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nature_walk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 어두운 오버레이 (투명도 조정)
          Container(
            color: Colors.black.withValues(alpha: 0.2),
          ),

          // 메인 콘텐츠
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 애니메이션과 말풍선을 포함한 스택
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final animationSize = screenHeight * 0.25; // 화면 높이의 25%
                      final bubbleOffset = -(animationSize * 0.2); // 애니메이션 크기의 20% 위쪽
                      
                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // start.json 애니메이션
                          Container(
                            width: animationSize,
                            height: animationSize,
                            child: Lottie.asset(
                              'assets/animations/start.json',
                              fit: BoxFit.contain,
                              repeat: true,
                            ),
                          ),

                          // 말풍선 (애니메이션 위에 오버레이)
                          Positioned(
                            top: bubbleOffset,
                            child: Column(
                              children: [
                                // 말풍선 텍스트 부분
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenHeight * 0.025,
                                    vertical: screenHeight * 0.015,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '지도 정보를 가져오고 있어요..!',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: screenHeight * 0.02,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // 말풍선 꼬리 (아래쪽을 가리킴)
                                CustomPaint(
                                  size: Size(screenHeight * 0.025, screenHeight * 0.012),
                                  painter: SpeechBubbleTailPainter(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 80),

                  // 로딩 인디케이터
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
