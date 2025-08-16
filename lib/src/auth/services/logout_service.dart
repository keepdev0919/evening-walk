import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

/// 로그아웃 관련 기능을 담당하는 서비스
///
/// 역할:
/// - FirebaseAuth 세션 종료
/// - Google / Kakao 등 소셜 세션도 가능하면 함께 종료 (에러는 무시하고 진행)
class AuthLogoutService {
  /// 현재 로그인된 사용자를 모든 지원되는 공급자에서 로그아웃합니다.
  ///
  /// - Google: GoogleSignIn.signOut 시도
  /// - Kakao: UserApi.instance.logout 시도
  /// - Firebase: FirebaseAuth.instance.signOut 필수 실행
  static Future<void> signOut() async {
    // Google 세션 종료 (있으면)
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {
      // 무시: 공급자에 따라 실패할 수 있음
    }

    // Kakao 세션 종료 (있으면)
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 무시: 카카오가 아닌 세션일 수 있음
    }

    // Firebase 인증 세션 종료 (항상 시도)
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // 무시: 네트워크 오류 등
    }
  }
}
