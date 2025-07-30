// user_info.dart
import 'package:flutter/material.dart';

class UserInfo extends StatelessWidget {
  final String uid;
  final String nickname;
  final String provider;

  const UserInfo({
    super.key,
    required this.uid,
    required this.nickname,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('회원 정보 입력')),
      body: Center(
        child: Text('여기에 사용자 정보 입력 폼 만들 예정'),
      ),
    );
  }
}
