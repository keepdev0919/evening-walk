import 'package:flutter/material.dart';
import './kakao_login.dart';
import './google_login.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

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
                // const Padding(
                //   padding: EdgeInsets.symmetric(horizontal: 24.0),
                //   child: Text(
                //     'After dinner, in just 30 minutes, a special walk awaits. Leave your own story as you go.',
                //     textAlign: TextAlign.center,
                //     style: TextStyle(
                //       color: Color(0xFF111618),
                //       fontSize: 22,
                //       fontWeight: FontWeight.bold,
                //       height: 1.3,
                //     ),
                //   ),
                // ),
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
                          onTap: () => signInWithKakao(context),
                          child: Image.asset(
                            'assets/images/kakao_login.png',
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => signInWithGoogle(context),
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

            // 소셜 로그인 버튼
            // Padding(
            //   padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            //   child: Column(
            //     children: [
            //       _buildSocialButton("Continue with Kakao"),
            //       const SizedBox(height: 12),
            //       _buildSocialButton("Continue with Google"),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import './kakao_login.dart';
// import './google_login.dart';

// class LoginPage extends StatelessWidget {
//   const LoginPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Padding(
//         padding: EdgeInsets.fromLTRB(30.0, 300.0, 0.0, 0.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('저녁 먹고 30분,',
//                 style: TextStyle(
//                   fontSize: 30,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 1.0,
//                 )),
//             Text('특별한 산책 경험,',
//                 style: TextStyle(
//                   fontSize: 30,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 1.0,
//                 )),
//             Text('그리고 반짝이는 기록,',
//                 style: TextStyle(
//                   fontSize: 30,
//                   fontWeight: FontWeight.bold,
//                   letterSpacing: 1.0,
//                 )),
//             SizedBox(height: 50),
//             Center(
//               child: GestureDetector(
//                 onTap: () => signInWithKakao(context),
//                 child: Image.asset(
//                   'assets/images/kakao_login.png',
//                 ),
//               ),
//             ),
//             SizedBox(height: 20),
//             Center(
//               child: GestureDetector(
//                 onTap: () => signInWithGoogle(context),
//                 child: Image.asset(
//                   'assets/images/google_login.png',
//                   width: 200,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
