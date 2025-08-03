import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> signInWithGoogle() async {
  try {
    final GoogleSignIn signIn = GoogleSignIn();

    // ✅ 기존에 로그인된 계정이 있다면 로그아웃 → 계정 선택 팝업 유도
    await signIn.signOut();

    // 로그인 시도
    final GoogleSignInAccount? googleUser = await signIn.signIn();

    if (googleUser == null) {
      // 로그인 취소됨
      print('❌ 로그인 취소됨');
      return false;
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

    if (user == null) return false;

    print('✅ 로그인 성공: ${user.displayName}');

    // ✅ Firestore에 저장
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userDoc.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'provider': 'google',
      'profileImage': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // merge: true → 중복 로그인 시 덮어쓰기 방지

    return true;
  } catch (e) {
    print('🔥 Google 로그인 중 오류 발생: $e');
    return false;
  }
}
