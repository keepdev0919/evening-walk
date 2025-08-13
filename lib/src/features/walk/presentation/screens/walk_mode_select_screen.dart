import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/presentation/screens/walk_start_map_screen.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/shared/widgets/black_cat_widget.dart';

/// 산책 방식 선택 화면
/// - 사용자에게 "왕복" / "편도" 중 하나를 선택하게 합니다.
class WalkModeSelectScreen extends StatelessWidget {
  const WalkModeSelectScreen({super.key});

  Future<void> _confirmAndGo(BuildContext context, String mode) async {
    final isRoundTrip = mode == 'round_trip';
    // 다이얼로그 문구를 카드 문구와 통일
    final title = isRoundTrip ? '왕복' : '편도';
    final desc = isRoundTrip
        ? '"출발지 → 목적지 → 출발지"\n돌아오면 산책이 완료돼요'
        : '"출발지 → 목적지" 도착하면 \n바로 산책이 완료돼요';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          desc,
          style: const TextStyle(
            color: Colors.white,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withValues(alpha: 0.9),
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 다음 화면으로 WalkMode를 전달합니다.
      final walkMode = isRoundTrip ? WalkMode.roundTrip : WalkMode.oneWay;
      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WalkStartMapScreen(mode: walkMode)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '산책 방식 선택',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지 (홈과 동일)
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
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 50),
                  const Text(
                    '어떤 방식으로 걸어볼까요?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ModeCard(
                    emoji: '↩️',
                    title: '왕복',
                    desc: '"출발지 → 목적지 → 출발지"\n돌아오면 산책이 완료돼요',
                    onTap: () => _confirmAndGo(context, 'round_trip'),
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    emoji: '➡️',
                    title: '편도',
                    desc: '"출발지 → 목적지" 도착하면 \n바로 산책이 완료돼요',
                    onTap: () => _confirmAndGo(context, 'one_way'),
                  ),
                ],
              ),
            ),
          ),
          // 하단 블랙캣
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = constraints.maxWidth;
                final double screenHeight = constraints.maxHeight;
                final double catWidth = screenWidth * 0.28 * 2;
                final double bottomPadding = screenHeight * 0.06;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: Transform.translate(
                      offset: Offset(-screenWidth * 0.23, 0),
                      child: BlackCatWidget(
                        width: catWidth,
                        bubbleMaxWidth: catWidth * 0.8,
                        screenType: 'selectMate',
                        defaultText: '기분 좋은 선택이냥! 🐾',
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
}

class _ModeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
