import 'package:flutter/material.dart';

class SelectMateScreen extends StatelessWidget {
  const SelectMateScreen({super.key});

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
                image: AssetImage('assets/images/mate_background.jpg'), // 📸 AI 생성 배경 이미지 경로 (나중에 교체)
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
                _buildMateButton(context, '혼자', () {
                  // TODO: 혼자 산책 선택 시 로직
                  Navigator.pop(context); // 일단 이전 화면으로 돌아가기
                }),
                const SizedBox(height: 20),
                _buildMateButton(context, '연인', () {
                  // TODO: 연인 산책 선택 시 로직
                  Navigator.pop(context); // 일단 이전 화면으로 돌아가기
                }),
                const SizedBox(height: 20),
                _buildMateButton(context, '친구', () {
                  // TODO: 친구 산책 선택 시 로직
                  Navigator.pop(context); // 일단 이전 화면으로 돌아가기
                }),
                const SizedBox(height: 40),
                const Padding(
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

  Widget _buildMateButton(BuildContext context, String text, VoidCallback onPressed) {
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
}
