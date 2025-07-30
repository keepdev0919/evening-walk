import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈 화면'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '산책 앱에 오신 것을 환영합니다!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
