import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
// import 'package:firebase_app_check/firebase_app_check.dart'; // 이 줄 추가
import 'src/features/auth/presentation/screens/login_page_screen.dart';
import 'src/features/home/presentation/screens/home_screen.dart';
import 'src/features/walk/presentation/screens/walk_history_screen.dart';
import 'src/common/providers/upload_provider.dart';
import 'src/common/services/toast_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/.env');
  await Firebase.initializeApp();

  // 한국어 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);

  // // Firebase App Check 초기화 (디버그 공급자 사용)
  // await FirebaseAppCheck.instance.activate(
  //   androidProvider: AndroidProvider.debug, // Android 에뮬레이터/디바이스용
  //   appleProvider: AppleProvider.debug, // iOS 시뮬레이터/디바이스용
  // );

  // await FirebaseAuth.instance.signOut();

  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '',
  );

  runApp(const MyApp()); //이렇게 쓸수 있게 해주는게 아래 {super.key} 때문
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> authCheck() async {
    final user = FirebaseAuth.instance.currentUser;

    // return const LoginPage();
    if (user == null) {
      return const LoginPage(); // 로그인 안되어 있으면 로그인 화면
    } else {
      // 사용자 문서 존재 여부 확인 (콘솔에서 삭제된 경우 대응)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!doc.exists) {
          await FirebaseAuth.instance.signOut();
          return const LoginPage();
        }
      } catch (_) {
        await FirebaseAuth.instance.signOut();
        return const LoginPage();
      }
      return const HomeScreen(); // 로그인 + 사용자 문서 존재 시 홈 화면
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UploadProvider(),
      child: MaterialApp(
          title: '산책 앱',
          scaffoldMessengerKey: ToastService.scaffoldMessengerKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
            useMaterial3: false,
            fontFamily: 'Cafe24Oneprettynight',
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                // 전역 버튼 폰트/크기/굵기 설정
                textStyle: const TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              behavior: SnackBarBehavior.floating,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: const BorderSide(color: Colors.white, width: 1.5),
              ),
              contentTextStyle: const TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          home: FutureBuilder(
            future: authCheck(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body:
                        Center(child: CircularProgressIndicator())); // 로딩 중일 때
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
          routes: {
            '/login': (context) => const LoginPage(),
            '/homescreen': (context) => const HomeScreen(),
            '/walk_history': (context) => const WalkHistoryScreen(),
          }),
    );
  }
}
