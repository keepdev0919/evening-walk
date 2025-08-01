import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/screens/walk_in_progress_map.dart';

class SelectMateScreen extends StatelessWidget {
  final LatLng startLocation;
  final LatLng destinationLocation;

  const SelectMateScreen({
    Key? key,
    required this.startLocation,
    required this.destinationLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 메이트 선택'),
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

          // ✅ 반투명 오버레이 (텍스트 및 버튼 가독성용)
          Container(
            color: Colors.black.withOpacity(0.4),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMateButton(context, '혼자', () async {
                  final bool? confirm =
                      await _showConfirmationDialog(context, '혼자');
                  if (confirm == true) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WalkInProgressMapScreen(
                          startLocation: startLocation,
                          destinationLocation: destinationLocation,
                          selectedMate: '혼자',
                        ),
                      ),
                    );
                  }
                }),
                SizedBox(height: 20),
                _buildMateButton(context, '연인', () async {
                  final bool? confirm =
                      await _showConfirmationDialog(context, '연인');
                  if (confirm == true) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WalkInProgressMapScreen(
                          startLocation: startLocation,
                          destinationLocation: destinationLocation,
                          selectedMate: '연인',
                        ),
                      ),
                    );
                  }
                }),
                SizedBox(height: 20),
                _buildMateButton(context, '친구', () async {
                  final bool? confirm =
                      await _showConfirmationDialog(context, '친구');
                  if (confirm == true) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WalkInProgressMapScreen(
                          startLocation: startLocation,
                          destinationLocation: destinationLocation,
                          selectedMate: '친구',
                        ),
                      ),
                    );
                  }
                }),
                SizedBox(height: 40),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    '*산책 메이트에 따라 경유지 이벤트 정보가 달라집니다*',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
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

Future<bool?> _showConfirmationDialog(BuildContext context, String mate) async {
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
          '산책 메이트를 \'$mate\'로 확정하시겠습니까?',
          style: const TextStyle(color: Colors.white70),
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
            child: Text('취소'),
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
            child: const Text('확정'),
          ),
        ],
      );
    },
  );
}

Widget _buildMateButton(
    BuildContext context, String text, VoidCallback onPressed) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white.withOpacity(0.2), // 반투명 흰색 배경
      foregroundColor: Colors.white, // 텍스트 색상
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30), // 둥근 모서리
        side: const BorderSide(color: Colors.white54, width: 1), // 얇은 테두리
      ),
      elevation: 0, // 그림자 제거
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 2, // 글자 간격
      ),
    ),
  );
}
