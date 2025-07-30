import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> signInWithGoogle(BuildContext context) async {
  try {
    final GoogleSignIn signIn = GoogleSignIn();

    // 로그인 시도
    final GoogleSignInAccount? googleUser = await signIn.signIn();

    if (googleUser == null) {
      // 로그인 취소됨
      print('❌ 로그인 취소됨');
      return;
    }

    // 인증 정보 가져오기
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Firebase용 credential 생성
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    // Firebase에 로그인
    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);

    final user = userCredential.user;
    if (user != null) {
      print('✅ 로그인 성공: ${user.displayName}');
    }
  } catch (e) {
    print('🔥 Google 로그인 중 오류 발생: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google 로그인 실패')),
    );
  }
}
