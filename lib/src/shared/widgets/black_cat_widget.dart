import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' as lottie;

/// 공용 검은 고양이 애니메이션 위젯
/// 홈 화면과 산책 메이트 선택 화면에서 재사용
class BlackCatWidget extends StatelessWidget {
  final double width;
  final String bubbleText;
  final double bubbleMaxWidth;
  final VoidCallback? onTap;
  final bool showBubble;
  final bool ignorePointer;

  const BlackCatWidget({
    Key? key,
    required this.width,
    this.bubbleText = '',
    required this.bubbleMaxWidth,
    this.onTap,
    this.showBubble = true,
    this.ignorePointer = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget catAnimation = lottie.Lottie.asset(
      'assets/animations/blackCat.json',
      repeat: true,
      animate: true,
      fit: BoxFit.contain,
    );

    // 클릭 가능한 경우 GestureDetector로 감싸기
    if (onTap != null) {
      catAnimation = GestureDetector(
        onTap: onTap,
        child: catAnimation,
      );
    }

    // IgnorePointer가 필요한 경우 적용
    if (ignorePointer) {
      catAnimation = IgnorePointer(
        ignoring: true,
        child: catAnimation,
      );
    }

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 말풍선 (필요한 경우에만 표시)
          if (showBubble && bubbleText.isNotEmpty) ...[
            _CatBubble(
              text: bubbleText,
              maxWidth: bubbleMaxWidth,
            ),
            const SizedBox(height: 2),
          ],
          // 고양이 애니메이션
          catAnimation,
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