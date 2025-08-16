import 'package:flutter/material.dart';
import '../services/walk_state_manager.dart';

/// 말풍선 위젯
/// 출발지 애니메이션 위에 표시되는 동적 말풍선
class SpeechBubbleWidget extends StatefulWidget {
  final SpeechBubbleState? speechBubbleState;
  final bool visible;

  const SpeechBubbleWidget({
    Key? key,
    required this.speechBubbleState,
    this.visible = true,
  }) : super(key: key);

  @override
  State<SpeechBubbleWidget> createState() => _SpeechBubbleWidgetState();
}

class _SpeechBubbleWidgetState extends State<SpeechBubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // 초기 애니메이션 시작
    if (widget.visible && widget.speechBubbleState != null) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(SpeechBubbleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 상태가 변경되었거나 가시성이 변경된 경우
    if (oldWidget.speechBubbleState != widget.speechBubbleState ||
        oldWidget.visible != widget.visible) {
      if (widget.visible && widget.speechBubbleState != null) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.speechBubbleState == null || !widget.visible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: _buildSpeechBubble(),
    );
  }

  Widget _buildSpeechBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 말풍선 본체
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              widget.speechBubbleState!.message,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // 말풍선 꼬리
          CustomPaint(
            size: const Size(20, 10),
            painter: SpeechBubbleTailPainter(),
          ),
        ],
      ),
    );
  }
}

/// 말풍선 꼬리를 그리는 CustomPainter
class SpeechBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final Path path = Path();

    // 말풍선 꼬리 삼각형 모양
    path.moveTo(size.width * 0.5, size.height); // 아래쪽 중앙 (뾰족한 부분)
    path.lineTo(size.width * 0.3, 0); // 왼쪽 위
    path.lineTo(size.width * 0.7, 0); // 오른쪽 위
    path.close();

    // 채우기
    canvas.drawPath(path, paint);

    // 테두리
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
