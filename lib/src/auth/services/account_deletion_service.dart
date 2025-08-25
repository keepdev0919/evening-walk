import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:walk/src/core/services/log_service.dart';

/// 회원탈퇴를 위한 서비스 (싱글톤)
class AccountDeletionService {
  static final AccountDeletionService _instance =
      AccountDeletionService._internal();
  factory AccountDeletionService() => _instance;
  AccountDeletionService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 회원탈퇴 실행 - 모든 사용자 데이터를 완전히 삭제
  Future<AccountDeletionResult> deleteAccount() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return AccountDeletionResult(
          isSuccess: false,
          message: '로그인된 사용자가 없습니다.',
        );
      }

      final String uid = currentUser.uid;
      LogService.debug('AccountDeletion', '회원탈퇴 시작: $uid');

      // 1단계: Firestore 사용자 데이터 삭제
      await _deleteFirestoreData(uid);

      // 2단계: Storage 프로필 이미지 삭제
      await _deleteStorageData(uid);

      // 3단계: Firebase Auth 계정 삭제
      await _deleteAuthAccount(currentUser);

      LogService.debug('AccountDeletion', '회원탈퇴 완료: $uid');

      return AccountDeletionResult(
        isSuccess: true,
        message: '회원탈퇴가 완료되었습니다.',
      );
    } catch (e) {
      LogService.error('AccountDeletion', '회원탈퇴 중 오류 발생: $e');
      return AccountDeletionResult(
        isSuccess: false,
        message: '회원탈퇴 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// Firestore 사용자 데이터 삭제
  Future<void> _deleteFirestoreData(String uid) async {
    try {
      // 사용자 기본 정보 삭제
      await _firestore.collection('users').doc(uid).delete();
      LogService.debug('AccountDeletion', 'Firestore 사용자 데이터 삭제 완료');

      // 산책 기록 데이터 삭제 (walk_sessions 컬렉션)
      await _deleteWalkSessions(uid);

      // 기타 사용자 관련 데이터가 있다면 여기에 추가
    } catch (e) {
      LogService.error('AccountDeletion', 'Firestore 데이터 삭제 실패: $e');
      // Firestore 삭제 실패는 전체 프로세스를 중단하지 않음
    }
  }

  /// 산책 기록 데이터 삭제
  Future<void> _deleteWalkSessions(String uid) async {
    try {
      final QuerySnapshot walkSessions = await _firestore
          .collection('walk_sessions')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in walkSessions.docs) {
        await doc.reference.delete();
      }

      LogService.debug(
          'AccountDeletion', '산책 기록 ${walkSessions.docs.length}개 삭제 완료');
    } catch (e) {
      LogService.error('AccountDeletion', '산책 기록 삭제 실패: $e');
    }
  }

  /// Storage 프로필 이미지 삭제
  Future<void> _deleteStorageData(String uid) async {
    try {
      final storageRef = _storage.ref().child('profile_images').child(uid);
      await storageRef.delete();
      LogService.debug('AccountDeletion', 'Storage 프로필 이미지 삭제 완료');
    } catch (e) {
      LogService.error('AccountDeletion', 'Storage 데이터 삭제 실패: $e');
      // Storage 삭제 실패는 전체 프로세스를 중단하지 않음
    }
  }

  /// Firebase Auth 계정 삭제
  Future<void> _deleteAuthAccount(User user) async {
    try {
      await user.delete();
      LogService.debug('AccountDeletion', 'Firebase Auth 계정 삭제 완료');
    } catch (e) {
      LogService.error('AccountDeletion', 'Firebase Auth 계정 삭제 실패: $e');
      // Auth 계정 삭제 실패 시 전체 프로세스 중단
      throw Exception('계정 삭제에 실패했습니다: $e');
    }
  }
}

/// 회원탈퇴 결과를 담는 클래스
class AccountDeletionResult {
  final bool isSuccess;
  final String message;

  AccountDeletionResult({
    required this.isSuccess,
    required this.message,
  });
}
