import 'package:flutter/material.dart';
// 기존 단독 회원정보 입력 로직은 사용하지 않습니다.
import 'package:walk/src/profile/screens/profile_screen.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({super.key});

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  @override
  Widget build(BuildContext context) {
    // 회원정보 입력 전용 UI를 별도로 두지 않고, 프로필 화면을
    // 온보딩 모드로 재사용합니다.
    return const Profile(isOnboarding: true);
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
