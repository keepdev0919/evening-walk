import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/src/features/walk/presentation/screens/walk_in_progress_map_screen.dart';
import '../../../../shared/widgets/black_cat_widget.dart';

class SelectMateScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng destinationLocation;
  final String? destinationBuildingName;

  const SelectMateScreen({
    Key? key,
    required this.startLocation,
    required this.destinationLocation,
    this.destinationBuildingName,
  }) : super(key: key);

  @override
  State<SelectMateScreen> createState() => _SelectMateScreenState();
}

class _SelectMateScreenState extends State<SelectMateScreen> {
  Future<bool?> _showConfirmationDialog(
      BuildContext context, String mate) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.7), // 반투명 검정 배경
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 둥근 모서리
            side: const BorderSide(color: Colors.white54, width: 1), // 얇은 테두리
          ),
          title: const Text(
            '산책 메이트 확정',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '산책 메이트를 \'$mate\'로 \n확정하시겠습니까?',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false), // 취소
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1), // 반투명 흰색 배경
                foregroundColor: Colors.white, // 텍스트 색상
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white54, width: 0.5),
                ),
                elevation: 0,
              ),
              child: const Text(
                '취소',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // 확정
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2), // 반투명 흰색 배경
                foregroundColor: Colors.white, // 텍스트 색상
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white54, width: 0.5),
                ),
                elevation: 0,
              ),
              child: const Text(
                '확정',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMateButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isNarrow = MediaQuery.of(context).size.width < 360;
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(0.4),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 24 : 60,
              vertical: isNarrow ? 12 : 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: const BorderSide(color: Colors.white, width: 1.5),
            ),
            elevation: 0,
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 메이트 선택',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true, // AppBar 뒤로 배경이 확장되도록
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ✅ AI 생성 배경 디자인을 위한 플레이스홀더
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/mate_background.jpg'), // 📸 AI 생성 배경 이미지 경로 (나중에 교체)
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 하단 Lottie 애니메이션 (홈의 blackCat과 동일한 반응형 규칙)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = constraints.maxWidth;
                final double screenHeight = constraints.maxHeight;
                // 홈 화면 규칙과 동일한 비율/오프셋
                final double catWidth = screenWidth * 0.28 * 2;
                final double bottomPadding = screenHeight * 0.03;
                return IgnorePointer(
                  ignoring: true,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: Transform.translate(
                        // 말풍선을 고양이 머리쪽으로 조금 더 우측 이동
                        offset: Offset(-screenWidth * 0.15, 0),
                        child: BlackCatWidget(
                          width: catWidth,
                          bubbleText: '메이트에 따라 경유지, 목적지 \n이벤트가 달라진다냥 ~',
                          bubbleMaxWidth: catWidth * 0.8,
                          ignorePointer: true, // 터치 이벤트 무시
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...['혼자', '연인', '친구'].map((mate) => Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: _buildMateButton(context, mate, () async {
                        final bool? confirm =
                            await _showConfirmationDialog(context, mate);
                        if (confirm == true) {
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WalkInProgressMapScreen(
                                startLocation: widget.startLocation,
                                destinationLocation: widget.destinationLocation,
                                selectedMate: mate,
                                destinationBuildingName:
                                    widget.destinationBuildingName,
                              ),
                            ),
                          );
                        }
                      }),
                    )),
                const SizedBox(height: 40),
                // const Padding(
                //   padding: EdgeInsets.symmetric(horizontal: 20.0),
                //   child: Text.rich(
                //     TextSpan(
                //       style: TextStyle(
                //         color: Colors.white,
                //         fontStyle: FontStyle.italic,
                //         fontSize: 20,
                //         fontWeight: FontWeight.bold,
                //         shadows: <Shadow>[
                //           Shadow(
                //             offset: Offset(0, 1),
                //             blurRadius: 4,
                //             color: Colors.black54,
                //           ),
                //         ],
                //       ),
                //       children: <TextSpan>[
                //         TextSpan(text: '산책 메이트에 따라 '),
                //         TextSpan(
                //           text: '경유지 이벤트 ',
                //           style: TextStyle(color: Colors.orangeAccent),
                //         ),
                //         TextSpan(text: '\n정보가 달라집니다'),
                //       ],
                //     ),
                //     textAlign: TextAlign.center,
                //   ),
                // ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

