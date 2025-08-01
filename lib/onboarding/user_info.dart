import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './onboarding.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({super.key});

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  final _formKey = GlobalKey<FormState>();

  String? _nickname;
  String? _age;
  String? _gender;
  String? _region;

  final List<String> _genderOptions = ['남자', '여자'];
  final List<String> _regionOptions = [
    '서울',
    '부산',
    '인천',
    '대구',
    '광주',
    '대전',
    '울산',
    '세종',
    '경기',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
    '기타'
  ];

  Future<void> _saveUserInfo() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await docRef.set({
      'nickname': _nickname,
      'age': int.tryParse(_age ?? ''),
      'sex': _gender,
      'region': _region,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('회원 정보가 저장되었습니다.'), duration: Duration(seconds: 2)),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Onboarding()),
    );

    // 👉 다음 화면으로 이동하거나 홈으로 보내려면 여기에 코드 추가
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원 정보 입력')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 닉네임
              TextFormField(
                decoration: const InputDecoration(labelText: '닉네임'),
                validator: (value) =>
                    value == null || value.isEmpty ? '닉네임을 입력하세요' : null,
                onSaved: (value) => _nickname = value,
              ),

              const SizedBox(height: 16),

              // 나이
              TextFormField(
                decoration: const InputDecoration(labelText: '나이'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? '나이를 입력하세요' : null,
                onSaved: (value) => _age = value,
              ),

              const SizedBox(height: 16),

              // 성별
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '성별'),
                items: _genderOptions
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                validator: (value) => value == null ? '성별을 선택하세요' : null,
                onChanged: (value) => _gender = value,
              ),

              const SizedBox(height: 16),

              // 지역
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: '지역'),
                items: _regionOptions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                validator: (value) => value == null ? '지역을 선택하세요' : null,
                onChanged: (value) => _region = value,
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saveUserInfo,
                child: const Text('저장하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import '../login/login_page.dart';

// class UserInfo extends StatelessWidget {
//   final String? uid;
//   final String? nickname;
//   final String? provider;

//   const UserInfo({
//     super.key,
//     this.uid,
//     this.nickname,
//     this.provider,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('회원 정보 입력'),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () {
//             // 뒤로가기 누르면 로그인 페이지로 이동
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (context) => const LoginPage()),
//             );
//           },
//         ),
//       ),
//       body: Center(
//         child: Text('여기에 사용자 정보 입력 폼 만들 예정'),
//       ),
//     );
//   }
// }
