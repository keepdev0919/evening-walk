import 'package:flutter/material.dart';

class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('온보딩'),
        automaticallyImplyLeading: false, // 뒤로가기 버튼 제거 (원한다면 유지 가능)
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '환영합니다!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '이제 산책을 시작할 준비가 되었어요.\n앱 사용법을 간단히 알려드릴게요.',
              style: TextStyle(fontSize: 18),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 홈 화면 또는 다음 페이지로 이동
                  // Navigator.pushReplacementNamed(context, '/homescreen');
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/homescreen',
                    (route) => false,
                  );
                },
                child: const Text('시작하기'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
