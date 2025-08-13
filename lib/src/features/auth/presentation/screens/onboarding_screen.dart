import 'package:flutter/material.dart';
import 'package:walk/src/shared/widgets/video_background.dart';

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          '저녁산책',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: VideoBackground(
        videoPath: 'assets/videos/walking_video.mp4',
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 콘텐츠
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // 메인 카피
                      Text(
                        '환영합니다!\n저녁 공기를 마시며, 가볍게 걸어볼까요?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
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
                      const SizedBox(height: 24),
                      // 안내 카드
                      _OnboardCard(
                        title: '산책 경로',
                        emoji: '🗺️',
                        description: '출발지 → 경유지 → 목적지를 따라 \n가볍게 다녀오면 끝!',
                      ),
                      const SizedBox(height: 12),
                      _OnboardCard(
                        title: '포즈 추천',
                        emoji: '✨',
                        description: '목적지에서 랜덤 포즈를 추천해드려요. \n사진 촬영으로 추억을 남겨요.',
                      ),
                      const SizedBox(height: 12),
                      _OnboardCard(
                        title: '산책 일기',
                        emoji: '📒',
                        description: '시간과 경로를 기록하고 \n짧은 소감을 남겨보세요.',
                      ),
                      const SizedBox(height: 28),
                      // 시작 버튼 (홈 스타일)
                      GestureDetector(
                        onTap: () => _goHome(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 16),
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
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 온보딩 카드 위젯: 간단한 안내 항목 하나를 표시
class _OnboardCard extends StatelessWidget {
  final String title;
  final String description;
  final String emoji;

  const _OnboardCard({
    required this.title,
    required this.description,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.35,
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
