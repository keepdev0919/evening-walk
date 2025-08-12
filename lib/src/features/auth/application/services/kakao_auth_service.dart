import 'package:firebase_auth/firebase_auth.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> signInWithKakao() async {
  try {
    OAuthToken token;
    // 1. 카카오톡 앱이 설치되어 있으면 그걸로 로그인 시도
    if (await isKakaoTalkInstalled()) {
      token = await UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await UserApi.instance.loginWithKakaoAccount(); // 없으면 웹뷰로
    }

    // 2. 카카오 사용자 정보 가져오기
    final kakaoUser = await UserApi.instance.me();
    final email = kakaoUser.kakaoAccount?.email ?? '';
    final profileImage = kakaoUser.kakaoAccount?.profile?.profileImageUrl ?? '';

    //1.provider 만들기
    var provider = OAuthProvider("oidc.todaywalk");

    //2. Credential 만들기
    var credential = provider.credential(
      idToken: token.idToken,
      accessToken: token.accessToken,
    );

    // 3. 파베 로그인하기
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return false;

    // 4. Firestore에 사용자 정보 저장 (legacy profileImage → profileImageUrl 마이그레이션 포함)
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    // 기존 문서 조회하여 legacy 필드 보정
    final existing = await userDoc.get();
    String finalProfileUrl = profileImage;
    if ((finalProfileUrl.isEmpty) && existing.exists) {
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
      'email': email,
      'provider': 'kakao',
      'profileImageUrl': finalProfileUrl,
      // 더 이상 사용하지 않는 legacy 키 정리
      'profileImage': FieldValue.delete(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // 중복 로그인 대비

    return true;
  } catch (e) {
    print('❌ 카카오 로그인 실패: $e');
    return false;
  }
}
