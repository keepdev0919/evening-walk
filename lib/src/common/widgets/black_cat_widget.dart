import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'dart:math';
import 'package:walk/src/core/services/log_service.dart';

/// 공용 검은 고양이 애니메이션 위젯
/// 홈 화면과 산책 메이트 선택 화면에서 재사용
/// 내부에서 날씨별 텍스트와 화남 텍스트를 자동으로 처리
class BlackCatWidget extends StatefulWidget {
  final double width;
  final double bubbleMaxWidth;
  final bool showBubble;
  final bool ignorePointer;

  // 새로운 파라미터들
  final String screenType; // 'home' 또는 'selectMate'
  final String? weatherCondition; // 날씨 조건 (홈 화면용)
  final String? defaultText; // 기본 텍스트 (selectMate용)

  const BlackCatWidget({
    Key? key,
    required this.width,
    required this.bubbleMaxWidth,
    required this.screenType,
    this.weatherCondition,
    this.defaultText,
    this.showBubble = true,
    this.ignorePointer = false,
  }) : super(key: key);

  @override
  State<BlackCatWidget> createState() => _BlackCatWidgetState();
}

class _BlackCatWidgetState extends State<BlackCatWidget>
    with TickerProviderStateMixin {
  late AnimationController _lottieController;

  // 텍스트 상태 관리
  String _currentText = '';
  bool _isAngry = false;
  String _originalText = '';

  @override
  void initState() {
    super.initState();
    // Lottie 애니메이션 컨트롤러 초기화
    _lottieController = AnimationController(vsync: this);
    // 초기 텍스트 설정
    _initializeText();
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

  /// 초기 텍스트 설정
  void _initializeText() {
    _originalText = _getDefaultText();
    _currentText = _originalText;
  }

  /// 화면 타입과 날씨에 따른 기본 텍스트 반환
  String _getDefaultText() {
    if (widget.screenType == 'home') {
      if (widget.weatherCondition != null) {
        return _getCatTextByWeather(widget.weatherCondition!);
      }
      return '같이 산책가는거냥?';
    } else if (widget.screenType == 'selectMate') {
      return widget.defaultText ?? '메이트에 따라 경유지, 목적지 \n이벤트가 달라진다냥 ~';
    } else if (widget.screenType == 'onboarding') {
      return widget.defaultText ?? '저녁 산책에 온걸 환영한다냥!';
    }
    return '같이 산책가는거냥?';
  }

  /// 날씨 상태에 따른 고양이 텍스트 반환
  String _getCatTextByWeather(String weatherCondition) {
    switch (weatherCondition.toLowerCase()) {
      case 'clear':
        return '산책하기 딱 좋은 날이냥!🐾';
      case 'clouds':
      case 'broken clouds':
      case 'overcast clouds':
        return '하늘에 솜사탕 보러가자냥!🐾';
      case 'few clouds':
      case 'scattered clouds':
        return '선선해서 걷기 좋다냥~🐾';
      case 'rain':
      case 'light rain':
      case 'moderate rain':
      case 'drizzle':
        return '비 산책 너무 낭만있다냥..🐾';
      case 'heavy rain':
      case 'extreme rain':
        return '비가 너무 많이 온다냥...🐾';
      case 'thunderstorm':
        return '천둥소리가 무섭다냥...🐾';
      case 'snow':
        return '추워도 눈구경 가자냥!🐾';
      case 'mist':
      case 'fog':
      case 'haze':
        return '신비로운 구름 산책이다냥!🐾';
      default:
        return '같이 산책가는거냥?🐾';
    }
  }

  /// 고양이 클릭 시 랜덤 화남 텍스트 반환
  String _getRandomAngryCatText() {
    final List<String> angryCatTexts = [
      '츄르안줄꺼면 건들지말라냥 !',
      '함부로 만지는 거 아니다냥 !',
      '내 인내심을 시험하지 말라냥!',
      '그 손 좀 치워보라냥 !',
      '간지럽다냥..',
      '자꾸 귀찮게 하면 할퀸다냥..',
      '그루밍 방해하지 말라냥 !!'
    ];

    final random = Random();
    return angryCatTexts[random.nextInt(angryCatTexts.length)];
  }

  /// 고양이 클릭 처리
  void _handleTap() {
    LogService.debug('UI', '고양이 클릭됨! 화면 타입: ${widget.screenType}');
    setState(() {
      _currentText = _getRandomAngryCatText();
      _isAngry = true;
    });
    LogService.debug('UI', '텍스트 변경됨: $_currentText, 화남: $_isAngry');

    // 복구 시간 통일 (모든 화면 2초)
    const duration = Duration(seconds: 2);

    // 원래 상태로 복원
    Future.delayed(duration, () {
      if (mounted) {
        setState(() {
          _originalText = _getDefaultText(); // 최신 기본 텍스트로 업데이트
          _currentText = _originalText;
          _isAngry = false;
        });
        LogService.debug('UI', '텍스트 복원됨: $_currentText, 화남: $_isAngry');
      }
    });
  }

  /// 날씨 조건이 변경되었을 때 텍스트 업데이트
  @override
  void didUpdateWidget(BlackCatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherCondition != widget.weatherCondition && !_isAngry) {
      setState(() {
        _originalText = _getDefaultText();
        _currentText = _originalText;
      });
    }
    // 기본 텍스트가 외부에서 변경되면(특히 온보딩) 즉시 반영
    if (oldWidget.defaultText != widget.defaultText && !_isAngry) {
      setState(() {
        _originalText = _getDefaultText();
        _currentText = _originalText;
      });
    }
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

    // 항상 클릭 가능하도록 GestureDetector로 감싸기
    catAnimation = GestureDetector(
      onTap: () {
        // 애니메이션 초기화 후 내부 클릭 처리 실행
        _restartAnimation();
        _handleTap();
      },
      child: catAnimation,
    );

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
          if (widget.showBubble && _currentText.isNotEmpty) ...[
            _CatBubble(
              text: _currentText,
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
              if (_isAngry)
                const Positioned(
                  top: -3,
                  right: 72,
                  child: Text(
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
              color: Colors.black.withValues(alpha: 0.4),
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
    final fill = Paint()..color = Colors.black.withValues(alpha: 0.4);
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
