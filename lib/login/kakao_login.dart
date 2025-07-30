import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

Future<void> signInWithKakao(BuildContext context) async {
  try {
    // 1. 카카오톡 앱이 설치되어 있으면 그걸로 로그인 시도
    if (await isKakaoTalkInstalled()) {
      await UserApi.instance.loginWithKakaoTalk();
    } else {
      await UserApi.instance.loginWithKakaoAccount(); // 없으면 웹뷰로
    }

    // // 2. 로그인 성공 후 사용자 정보 가져오기
    // User user = await UserApi.instance.me();

    // final uid = user.id.toString(); // 카카오 ID → 문자열 UID로 사용
    // final nickname = user.kakaoAccount?.profile?.nickname ?? '사용자';

    // // 3. 공통 로그인 후처리 흐름으로 넘기기
    // await handleLoginFlow(
    //   context: context,
    //   uid: uid,
    //   nickname: nickname,
    //   provider: 'kakao',
    // );

    var provider = OAuthProvider("oidc.todaywalk"); //1.provider 만들기

    OAuthToken token =
        await UserApi.instance.loginWithKakaoAccount(); //2. Credential 만들기
    var credential = provider.credential(
      idToken: token.idToken,
      accessToken: token.accessToken,
    );

    FirebaseAuth.instance.signInWithCredential(credential); // 3. 파베 로그인하기
  } catch (e) {
    print('❌ 카카오 로그인 실패: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('카카오 로그인에 실패했습니다. 다시 시도해주세요.')),
    );
  }
}
