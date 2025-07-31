import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import './login/login_page.dart';
import './screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/.env');
  await Firebase.initializeApp();

  // await FirebaseAuth.instance.signOut();

  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
  );

  runApp(const MyApp()); //이렇게 쓸수 있게 해주는게 아래 {super.key} 때문
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> authCheck() async {
    // final user = FirebaseAuth.instance.currentUser;

    return const LoginPage();
    // if (user == null) {
    //   return const LoginPage(); // 로그인 안되어 있으면 로그인 화면
    // } else {
    //   return const HomeScreen(); // 로그인 되어있으면 홈 화면
    // } 이부분은 온보딩페이지 전부 완성하고 서비스할때 추가해야함. 왜냐하면 개발중에는 온보딩페이지 지속적으로 확인해야하므로
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '산책 앱',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: authCheck(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator())); // 로딩 중일 때
          } else if (snapshot.hasData) {
            return snapshot.data!;
            // 로그인 상태에 따라 MainLogin 또는 HomeScreen 반환
            // if 조건에서 무조건 존재하기때문에 snapshot.data는 nullable이였는데 절대 null이 아님을 의미하는 !를 붙여 dart에게 확신줌.
          } else {
            return const Scaffold(
                body: Center(child: Text("문제가 발생했습니다."))); // 에러 발생 시
          }
        },
      ),
    );
  }
}
