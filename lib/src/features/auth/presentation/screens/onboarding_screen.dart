import 'package:flutter/material.dart';
import 'package:walk/src/common/widgets/video_background.dart';

/// 온보딩 화면
/// 역할: 첫 로그인 후 간단한 안내를 보여주고 홈으로 진입시키는 화면
class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/homescreen',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: VideoBackground(
        videoPath: 'assets/videos/walking_video.mp4',
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 콘텐츠
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 상단 여백
                    const Spacer(flex: 3),
                    
                    // 메인 카피
                    Text(
                      '저녁 산책에 오신 것을 \n환영합니다!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
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
                    const SizedBox(height: 16),
                    
                    // 서브 타이틀
                    Text(
                      '간단한 3단계로 특별한 산책을 시작해보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // StepCard들 (간격 최소화)
                    _StepCard(
                      step: '1',
                      title: '목적지 선택',
                      icon: '🚩',
                      description: '목적지를 직접 고르거나, 추천 받아보세요',
                    ),
                    const SizedBox(height: 12),
                    _StepCard(
                      step: '2',
                      title: '산책 설정',
                      icon: '🚶‍♂️',
                      description: '산책 메이트와 왕복/편도를 선택하세요',
                    ),
                    const SizedBox(height: 12),
                    _StepCard(
                      step: '3',
                      title: '미션 & 기록',
                      icon: '📝',
                      description: '경유지 미션을 하고 목적지에서 사진 촬영!',
                    ),
                    const SizedBox(height: 24),

                    // 시작 버튼
                    GestureDetector(
                      onTap: () => _goHome(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white, width: 0.8),
                        ),
                        child: const Text(
                          '첫 산책 시작하기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                    // 하단 여백
                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 단계별 안내 카드 위젯
class _StepCard extends StatelessWidget {
  final String step;
  final String icon;
  final String title;
  final String description;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 단계 번호 원형 배지
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 0.7),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 텍스트 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 1),
                    fontSize: 14,
                    height: 1.3,
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
