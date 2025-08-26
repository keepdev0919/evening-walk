import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walk/src/core/services/log_service.dart';
import 'package:walk/src/core/services/analytics_service.dart';

/// Apple 로그인 서비스
/// iOS에서 Apple 로그인을 처리하고 Firebase 인증을 수행합니다.
class AppleAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Apple 로그인 실행
  static Future<bool> signInWithApple() async {
    try {
      // Apple 로그인 요청
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          // AppleIDAuthorizationScopes.email, // 이메일 스코프 제거
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Firebase 인증
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      if (userCredential.user != null) {
        // Firebase Analytics 로그인 이벤트 기록
        await AnalyticsService().logLogin('apple');

        // Firestore에 사용자 정보 저장
        await _saveUserToFirestore(userCredential.user!);
        return true;
      }

      return false;
    } catch (e) {
      LogService.error('Auth', 'Apple 로그인 실패', e);
      return false;
    }
  }

  /// 사용자 정보를 Firestore에 저장
  static Future<void> _saveUserToFirestore(User user) async {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      // 기존 문서 조회하여 legacy 필드 보정
      final existing = await userDoc.get();
      String finalProfileUrl = user.photoURL ?? '';

      if (finalProfileUrl.isEmpty && existing.exists) {
        final data = existing.data();
        if (data != null) {
          final legacy = data['profileImage']?.toString() ?? '';
          if (legacy.isNotEmpty) {
            finalProfileUrl = legacy;
          }
        }
      }

      await userDoc.set({
        'uid': user.uid,
        // 'email': user.email ?? '', // 이메일 필드 제거
        'provider': 'apple',
        'profileImageUrl': finalProfileUrl,
        // 더 이상 사용하지 않는 legacy 키 정리
        'profileImage': FieldValue.delete(),
        'email': FieldValue.delete(), // 기존 이메일 필드도 삭제
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 신규 사용자인 경우 회원가입 이벤트 기록
      if (user.metadata.creationTime == user.metadata.lastSignInTime) {
        await AnalyticsService().logSignUp('apple');
      }
    } catch (e) {
      LogService.error('Auth', 'Firestore 사용자 정보 저장 실패', e);
    }
  }
}
