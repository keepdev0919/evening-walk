import 'package:flutter/material.dart';
import '../../application/services/kakao_auth_service.dart';
import '../../application/services/google_auth_service.dart';
import 'user_info_screen.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> handleLogin(
    BuildContext context,
    Future<bool> Function() loginMethod, //얘는 signInWithGoogle,Kakao를 말함
  ) async {
    showDialog(
      context: context, //뒤의 context는 로그인페이지 context
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
      //(context)의 context는 다이얼로그의 context임
    );

    final success = await loginMethod();

    if (!context.mounted) return; // ✅ context 유효성 체크

    Navigator.pop(context);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserInfo()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 상단 이미지 카드
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 240,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            "https://lh3.googleusercontent.com/aida-public/AB6AXuB0oRtqbouYEyEAiCl3x_NDoS6bLnt9DxxfDWGNQe91pwP43CnnPq_7xzVLmJ5dSDzflTVYUnmWEBB6FetbNqmsqSqFnXnJKpkZJNXSpcB4B8Kl9Y_zi8tir2kFyzM96Ei9Xl9yH7sf5fI1KXOI9D0CXKYL7xslqijPJ3di1yFFLfAs9WxV4Mpwtj-K4gYmMJznOPWDFoUfZOJHQZnRrE1YTe_erw1dW43PiNNI7YVYvUqH79Z5YV5rfTPj0C8foqEPvrOn5NOvWSGm",
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(30.0, 30.0, 0.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('저녁 먹고 30분,',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          )),
                      Text('특별한 산책 경험,',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          )),
                      Text('그리고 반짝이는 기록,',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          )),
                      SizedBox(height: 50),
                      Center(
                        child: GestureDetector(
                          onTap: () => handleLogin(context, signInWithKakao),
                          child: Image.asset(
                            'assets/images/kakao_login.png',
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => handleLogin(context, signInWithGoogle),
                          child: Image.asset(
                            'assets/images/google_login.png',
                            width: 200,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
