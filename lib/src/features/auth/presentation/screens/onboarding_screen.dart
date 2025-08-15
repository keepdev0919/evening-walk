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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '저녁산책',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontFamily: 'Cafe24Oneprettynight',
            shadows: [
              Shadow(
                color: Color.fromARGB(153, 0, 0, 0),
                blurRadius: 6,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지만 Stack으로 처리
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nature_walk2.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 모든 UI 요소들을 하나의 Column으로 통합
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 80), // 상단 여백 (AppBar 고려하여 조정)

                  const SizedBox(height: 10),

                  // PageView (슬라이드 콘텐츠)
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          children: [
                            _buildSlide(
                              title: '', // title 제거
                              lines: const [
                                '속은 편안하게, \n마음은 추억으로 \n 기분 좋은 저녁 산책',
                              ],
                              isFirstSlide: true, // 첫 번째 슬라이드 표시
                            ),
                            _buildSlide(
                              title: '1. 목적지 설정 🚩',
                              lines: const [
                                '지도를 탭해 목적지를 고르거나',
                                '랜덤 추천을 통해 목적지를 정해봐요 !',
                              ],
                              boldKeywords: ['지도', '랜덤 추천'],
                            ),
                            _buildSlide(
                              title: '2. 산책 중 이벤트 🚶‍',
                              lines: const [
                                '경유지에서 미션을 즐기며',
                                '목적지에서 사진 찍고 공유해요 !',
                              ],
                              boldKeywords: ['미션', '사진', '공유'],
                            ),
                            _buildSlide(
                              title: '3. 산책 일기 쓰기 📝',
                              lines: const [
                                '오늘의 산책을 기록하고',
                                '나만의 추억을 쌓아보세요',
                              ],
                              boldKeywords: ['나만의 추억'],
                            ),
                            _buildSlide(
                              title: '출발 준비 완료 ✨',
                              lines: const [
                                '이제 산책하러 가볼까요?',
                              ],
                              boldKeywords: ['산책'],
                              cta: _buildStartButton(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 인디케이터와 고양이를 하단에 배치
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double screenWidth = constraints.maxWidth;
                      final double screenHeight =
                          MediaQuery.of(context).size.height;
                      final double catWidth = screenWidth * 0.28 * 2;
                      final double bottomPadding = screenHeight * 0.06;

                      String catText;
                      switch (_currentPage) {
                        case 0:
                          catText = '오른쪽으로 넘겨보라냥 !';
                          break;
                        case 1:
                          catText = '반갑다냥.. 😳';
                          break;
                        case 2:
                          catText = '사진찍는거 나도 좋아한다냥..';
                          break;
                        case 3:
                          catText = '일기에 나도 넣어달라냥 !!!';
                          break;
                        case 4:
                          catText = '이제 산책하러 가는거냥 🐾';
                          break;
                        default:
                          catText = '이제 산책하러 가는거냥 🐾';
                      }

                      return Padding(
                        padding: EdgeInsets.only(bottom: bottomPadding),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 인디케이터 (화면 중앙 정렬)
                            _buildPageIndicator(),
                            const SizedBox(height: 50),
                            // 고양이 (기존 위치 유지)
                            Transform.translate(
                              offset: Offset(-screenWidth * 0.23, 0),
                              child: BlackCatWidget(
                                width: catWidth,
                                bubbleMaxWidth: catWidth * 0.9,
                                screenType: 'onboarding',
                                defaultText: catText,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
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
    bool isFirstSlide = false,
    List<String>? boldKeywords,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 첫 번째 슬라이드가 아닐 때만 title 표시
        if (!isFirstSlide && title.isNotEmpty) ...[
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              height: 1.25,
              fontFamily: 'Cafe24Oneprettynight',
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
        ],
        // 보조 라인(1~2줄) - 첫 번째 슬라이드일 때는 첫 번째 텍스트를 title 크기로
        ...lines.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final text = entry.value;
            final isFirstLine = index == 0;

            // boldKeywords가 있고 첫 번째 슬라이드가 아닐 때만 RichText 사용
            if (boldKeywords != null && !isFirstSlide) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: _buildRichText(
                    text,
                    boldKeywords,
                    fontSize: 18,
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: isFirstSlide && isFirstLine
                      ? 32 // 첫 번째 슬라이드의 첫 번째 텍스트 크기
                      : 18, // 나머지 텍스트 크기
                  fontWeight: isFirstSlide && isFirstLine
                      ? FontWeight.bold
                      : FontWeight.normal,
                  height: 1.35,
                  fontFamily: 'Cafe24Oneprettynight',
                  shadows: isFirstSlide && isFirstLine
                      ? [
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
                        ]
                      : null,
                ),
              ),
            );
          },
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
            fontFamily: 'Cafe24Oneprettynight',
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
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

  /// 텍스트에서 특정 키워드를 굵게 표시하는 RichText를 생성하는 메서드
  TextSpan _buildRichText(String text, List<String> boldKeywords,
      {double fontSize = 18}) {
    final List<TextSpan> spans = [];
    String remainingText = text;
    int lastIndex = 0;

    // 각 키워드를 순서대로 처리
    for (String keyword in boldKeywords) {
      final int index = remainingText.indexOf(keyword, lastIndex);
      if (index != -1) {
        // 키워드 앞의 일반 텍스트
        if (index > lastIndex) {
          spans.add(TextSpan(
            text: remainingText.substring(lastIndex, index),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: fontSize,
              fontWeight: FontWeight.normal,
              height: 1.35,
              fontFamily: 'Cafe24Oneprettynight',
            ),
          ));
        }

        // 굵은 키워드
        spans.add(TextSpan(
          text: keyword,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            height: 1.35,
            fontFamily: 'Cafe24Oneprettynight',
          ),
        ));

        lastIndex = index + keyword.length;
      }
    }

    // 마지막 남은 텍스트 추가
    if (lastIndex < remainingText.length) {
      spans.add(TextSpan(
        text: remainingText.substring(lastIndex),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: fontSize,
          fontWeight: FontWeight.normal,
          height: 1.35,
          fontFamily: 'Cafe24Oneprettynight',
        ),
      ));
    }

    // 만약 아무 키워드도 찾지 못했다면 원본 텍스트를 그대로 반환
    if (spans.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: fontSize,
          fontWeight: FontWeight.normal,
          height: 1.35,
          fontFamily: 'Cafe24Oneprettynight',
        ),
      );
    }

    return TextSpan(children: spans);
  }
}
