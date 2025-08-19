import 'package:flutter/material.dart';
import '../services/kakao_auth_service.dart';
import '../services/google_auth_service.dart';
import 'user_info_screen.dart' as userinfo;
import 'package:walk/src/common/widgets/black_cat_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walk/src/home/home_screen.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> handleLogin(
    BuildContext context,
    Future<bool> Function() loginMethod, //얘는 signInWithGoogle,Kakao를 말함
  ) async {
    showDialog(
      //사용자가 로그인 버튼 누르면 로그인 진행되는 동안 로딩 아이콘이 뜸
      context: context, //뒤의 context는 로그인페이지 context
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
      //(context)의 context는 다이얼로그의 context임
    );

    final success = await loginMethod();

    if (!context.mounted)
      return; // 비동기 작업(await) 후에 위젯이 화면에서 사라졌을 수도 있는 상황에 대비한 안전장치입니다. 이 코드가 없으면 앱이 비정상 종료될 수 있습니다.

    Navigator.pop(context); //로딩창을 닫는 코드

    if (success) {
      // 프로필 존재 여부를 확인하여 분기
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('인증 사용자 정보를 찾을 수 없습니다.');
        }

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final data = doc.data();
        final String nickname = (data?['nickname'] ?? '').toString().trim();
        final bool hasProfile = nickname.isNotEmpty;

        if (hasProfile) {
          // 기존 사용자: 홈으로 직행 (백스택 제거)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          // 신규 사용자: 프로필(온보딩 모드)로 이동
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const userinfo.UserInfo()),
          );
        }
      } catch (e) {
        // 확인 실패 시 안전하게 온보딩 경로로 보냄
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const userinfo.UserInfo()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('로그인에 실패했습니다.'),
          backgroundColor: Colors.black.withValues(alpha: 0.6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '저녁산책',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      //배경이미지 -> 콘텐츠 -> 고양이 캐릭터 순으로 쌓임
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nature_walk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 콘텐츠
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '처음 오신 걸 환영해요! \n저녁 공기를 마시며,\n가볍게 걸어볼까요?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          height: 1.3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.8),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: GestureDetector(
                                  onTap: () =>
                                      handleLogin(context, signInWithKakao),
                                  child: Image.asset(
                                    'assets/images/kakao_login.png',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: GestureDetector(
                                  onTap: () =>
                                      handleLogin(context, signInWithGoogle),
                                  child: Image.asset(
                                    'assets/images/google_login.png',
                                    width: 200,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 하단 검은 고양이 (유지)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenWidth = constraints.maxWidth;
                final double screenHeight = constraints.maxHeight;
                final double catWidth = screenWidth * 0.28 * 2;
                final double bottomPadding = screenHeight * 0.06;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: Transform.translate(
                      offset: Offset(-screenWidth * 0.23, 0),
                      child: BlackCatWidget(
                        width: catWidth,
                        bubbleMaxWidth: catWidth * 0.8,
                        screenType: 'selectMate',
                        defaultText: '어서오라냥~🐾 ',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
