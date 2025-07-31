import 'package:flutter/material.dart';
import '../login/login_page.dart';

class UserInfo extends StatelessWidget {
  final String? uid;
  final String? nickname;
  final String? provider;

  const UserInfo({
    super.key,
    this.uid,
    this.nickname,
    this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('회원 정보 입력'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // 뒤로가기 누르면 로그인 페이지로 이동
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        ),
      ),
      body: Center(
        child: Text('여기에 사용자 정보 입력 폼 만들 예정'),
      ),
    );
  }
}
