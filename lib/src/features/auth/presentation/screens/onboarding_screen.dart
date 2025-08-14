import 'package:flutter/material.dart';
import '../../../../common/widgets/black_cat_widget.dart';

/// 온보딩 화면 (4장 슬라이드)
/// 역할: 첫 로그인 후 간단한 안내를 4개의 페이지로 제공하고 마지막에 홈으로 진입시키는 화면
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/homescreen',
      (route) => false,
    );
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() => _currentPage = index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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

          // 콘텐츠: 상단 환영 문구 + 슬라이드
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                  top: 0, left: 24, right: 24, bottom: 40),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double pagerHeight = constraints.maxHeight * 0.6;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '저녁산책에 오신걸 \n 환영해요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            height: 1.25,
                            shadows: [
                              Shadow(
                                color: Color.fromARGB(204, 0, 0, 0),
                                blurRadius: 8,
                                offset: Offset(2, 2),
                              ),
                              Shadow(
                                color: Color.fromARGB(102, 0, 0, 0),
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: pagerHeight,
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            children: [
                              _buildSlide(
                                title: '1. 목적지 설정 🚩',
                                lines: const [
                                  '지도를 탭해 목적지를 고르거나',
                                  '랜덤 추천을 통해 목적지를 정해봐요 !',
                                ],
                              ),
                              _buildSlide(
                                title: '2. 산책 중 이벤트 🚶‍',
                                lines: const [
                                  '경유지에서 미션을 즐기며',
                                  '목적지에서 사진 찍고 공유해요 !',
                                ],
                              ),
                              _buildSlide(
                                title: '3. 산책 일기 쓰기 📝',
                                lines: const [
                                  '오늘 산책을 기록하고',
                                  '나만의 일기로 예쁘게 모아보세요',
                                ],
                              ),
                              _buildSlide(
                                title: '출발 준비 완료 ✨',
                                lines: const [
                                  '이제 산책하러 가볼까요?',
                                ],
                                cta: _buildStartButton(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 하단 BlackCat 애니메이션 (홈과 동일 비율) + 슬라이드별 텍스트 변경 + 인디케이터 말풍선 위 배치
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = constraints.maxWidth;
                final double screenHeight = constraints.maxHeight;
                final double catWidth = screenWidth * 0.28 * 2;
                final double bottomPadding = screenHeight * 0.06;

                String catText;
                switch (_currentPage) {
                  case 0:
                    catText = '오른쪽으로 넘겨보라냥 !';
                    break;
                  case 1:
                    catText = '사진찍는거 나도 좋아한다냥..';
                    break;
                  case 2:
                    catText = '일기에 나도 넣어달라냥 !!!';
                    break;
                  case 3:
                    catText = '이제 산책하러 가는거냥 🐾';
                    break;
                  default:
                    catText = '이제 산책하러 가는거냥 🐾';
                }

                // 고양이 위젯과 인디케이터를 세로로 정렬
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: Transform.translate(
                      offset: Offset(-screenWidth * 0.23, 0),
                      child: SizedBox(
                        width: catWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 인디케이터를 고양이 말풍선 위에, 화면 중앙 정렬로 배치
                            Transform.translate(
                              offset:
                                  Offset(screenWidth * 0.23, 0), // 부모 좌측 이동 상쇄
                              child: _buildPageIndicator(),
                            ),
                            const SizedBox(height: 50),
                            BlackCatWidget(
                              width: catWidth,
                              bubbleMaxWidth: catWidth * 0.8,
                              screenType: 'onboarding',
                              defaultText: catText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide({
    required String title,
    required List<String> lines,
    Widget? tail,
    Widget? cta,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 헤드라인
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            height: 1.25,
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
        const SizedBox(height: 16),
        // 보조 라인(1~2줄)
        ...lines.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              t,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 18,
                height: 1.35,
              ),
            ),
          ),
        ),
        if (tail != null) ...[
          const SizedBox(height: 4),
          tail,
        ],
        const SizedBox(height: 14),
        if (cta != null) ...[
          cta,
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: _goHome,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Text(
          '시작하기',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final bool active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: active ? 22 : 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.95 : 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.8), width: 0.6),
          ),
        );
      }),
    );
  }
}
