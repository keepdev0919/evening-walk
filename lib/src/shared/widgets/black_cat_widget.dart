import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' as lottie;

/// 공용 검은 고양이 애니메이션 위젯
/// 홈 화면과 산책 메이트 선택 화면에서 재사용
class BlackCatWidget extends StatefulWidget {
  final double width;
  final String bubbleText;
  final double bubbleMaxWidth;
  final VoidCallback? onTap;
  final bool showBubble;
  final bool ignorePointer;
  final bool showAngryEmoji;

  const BlackCatWidget({
    Key? key,
    required this.width,
    this.bubbleText = '',
    required this.bubbleMaxWidth,
    this.onTap,
    this.showBubble = true,
    this.ignorePointer = false,
    this.showAngryEmoji = false,
  }) : super(key: key);

  @override
  State<BlackCatWidget> createState() => _BlackCatWidgetState();
}

class _BlackCatWidgetState extends State<BlackCatWidget> 
    with TickerProviderStateMixin {
  late AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    // Lottie 애니메이션 컨트롤러 초기화
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  void _restartAnimation() {
    // 애니메이션을 처음부터 다시 시작
    _lottieController.reset();
    _lottieController.forward();
  }

  @override
  Widget build(BuildContext context) {
    // 기존 blackCat.json 하나만 사용 (컨트롤러 연결)
    Widget catAnimation = lottie.Lottie.asset(
      'assets/animations/blackCat.json',
      controller: _lottieController,
      repeat: true,
      animate: true,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        // 애니메이션이 로드되면 컨트롤러 설정
        _lottieController.duration = composition.duration;
        _lottieController.forward();
      },
    );

    // 클릭 가능한 경우 GestureDetector로 감싸기
    if (widget.onTap != null) {
      catAnimation = GestureDetector(
        onTap: () {
          // 애니메이션 초기화 후 사용자 onTap 실행
          _restartAnimation();
          widget.onTap!();
        },
        child: catAnimation,
      );
    }

    // IgnorePointer가 필요한 경우 적용
    if (widget.ignorePointer) {
      catAnimation = IgnorePointer(
        ignoring: true,
        child: catAnimation,
      );
    }

    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 말풍선 (필요한 경우에만 표시)
          if (widget.showBubble && widget.bubbleText.isNotEmpty) ...[
            _CatBubble(
              text: widget.bubbleText,
              maxWidth: widget.bubbleMaxWidth,
            ),
            const SizedBox(height: 2),
          ],
          // 고양이 애니메이션과 화남 이모지를 Stack으로 겹치기
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 고양이 애니메이션
              catAnimation,
              // 화남 이모지 (우측 상단에 위치)
              if (widget.showAngryEmoji)
                Positioned(
                  top: -3,
                  right: 72,
                  child: const Text(
                    '💢',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 고양이 말풍선 위젯
class _CatBubble extends StatelessWidget {
  final String text;
  final double maxWidth;

  const _CatBubble({
    required this.text,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 0),
          // 말풍선 꼬리
          CustomPaint(
            size: const Size(18, 7),
            painter: _CatBubbleTailPainter(),
          ),
        ],
      ),
    );
  }
}

/// 말풍선 꼬리를 그리는 CustomPainter
class _CatBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.black.withOpacity(0.4);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(size.width * 0.6, size.height)
      ..lineTo(size.width * 0.35, 0)
      ..lineTo(size.width * 0.65, 0)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
