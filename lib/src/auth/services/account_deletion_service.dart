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
    User? currentUser;
    String? uid;
    final List<String> completedSteps = [];

    try {
      // 1단계: 현재 사용자 정보 확인 및 백업
      LogService.info('AccountDeletion', '====== 회원탈퇴 프로세스 시작 ======');
      currentUser = _auth.currentUser;
      if (currentUser == null) {
        LogService.warning('AccountDeletion', '회원탈퇴 실패: 로그인된 사용자 없음');
        return AccountDeletionResult(
          isSuccess: false,
          message: '로그인된 사용자가 없습니다.',
        );
      }

      uid = currentUser.uid;
      LogService.info('AccountDeletion', '회원탈퇴 대상 사용자: $uid');

      // 2단계: 사용자 토큰 갱신 (최신 상태 확인)
      try {
        LogService.info('AccountDeletion', '[단계 1/4] 사용자 토큰 갱신 시작');
        await currentUser.getIdToken(true);
        completedSteps.add('토큰갱신');
        LogService.info('AccountDeletion', '[단계 1/4] 사용자 토큰 갱신 완료');
      } catch (e) {
        LogService.warning('AccountDeletion', '[단계 1/4] 토큰 갱신 실패하지만 계속 진행: $e');
      }

      // 3단계: Firestore 사용자 데이터 삭제 (재시도 포함)
      LogService.info('AccountDeletion', '[단계 2/4] Firestore 데이터 삭제 시작');
      await _deleteFirestoreDataWithRetry(uid);
      completedSteps.add('Firestore데이터삭제');
      LogService.info('AccountDeletion', '[단계 2/4] Firestore 데이터 삭제 완료');

      // 4단계: Storage 데이터 삭제 (재시도 포함)
      LogService.info('AccountDeletion', '[단계 3/4] Storage 데이터 삭제 시작');
      await _deleteStorageDataWithRetry(uid);
      completedSteps.add('Storage데이터삭제');
      LogService.info('AccountDeletion', '[단계 3/4] Storage 데이터 삭제 완료');

      // 5단계: Firebase Auth 계정 삭제 (마지막 단계, 재시도 포함)
      LogService.info('AccountDeletion', '[단계 4/4] Firebase Auth 계정 삭제 시작');
      await _deleteAuthAccountWithRetry(currentUser);
      completedSteps.add('Auth계정삭제');
      LogService.info('AccountDeletion', '[단계 4/4] Firebase Auth 계정 삭제 완료');

      LogService.info('AccountDeletion', '====== 회원탈퇴 프로세스 완료 ======');
      LogService.info('AccountDeletion', '완료된 단계: ${completedSteps.join(", ")}');

      return AccountDeletionResult(
        isSuccess: true,
        message: '회원탈퇴가 완료되었습니다.',
      );
    } catch (e) {
      LogService.error('AccountDeletion', '====== 회원탈퇴 프로세스 실패 ======');
      LogService.error('AccountDeletion', '완료된 단계: ${completedSteps.join(", ")}');
      LogService.error('AccountDeletion', '실패 원인: $e');

      // 오류 발생 시 부분적으로 삭제된 데이터 정리 시도
      if (uid != null) {
        LogService.info('AccountDeletion', '부분 삭제 데이터 정리 시작');
        await _cleanupPartialDeletion(uid);
      }

      return AccountDeletionResult(
        isSuccess: false,
        message: '회원탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
        failedStep: _getFailedStep(completedSteps),
      );
    }
  }

  /// 실패한 단계를 파악하는 헬퍼 메서드
  String _getFailedStep(List<String> completedSteps) {
    if (!completedSteps.contains('Firestore데이터삭제')) {
      return 'Firestore 데이터 삭제';
    } else if (!completedSteps.contains('Storage데이터삭제')) {
      return 'Storage 데이터 삭제';
    } else if (!completedSteps.contains('Auth계정삭제')) {
      return 'Auth 계정 삭제';
    }
    return '알 수 없음';
  }

  /// Firestore 사용자 데이터 삭제 (재시도 포함)
  Future<void> _deleteFirestoreDataWithRetry(String uid, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        LogService.info('AccountDeletion', 'Firestore 삭제 시도 $attempt/$maxRetries');
        await _deleteFirestoreData(uid);
        return; // 성공 시 종료
      } catch (e) {
        LogService.warning('AccountDeletion', 'Firestore 삭제 시도 $attempt/$maxRetries 실패: $e');
        if (attempt == maxRetries) {
          throw Exception('Firestore 데이터 삭제 최종 실패 ($maxRetries회 시도): $e');
        }
        // 재시도 전 잠시 대기
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Firestore 사용자 데이터 삭제
  Future<void> _deleteFirestoreData(String uid) async {
    try {
      // 1. 사용자별 산책 기록 서브컬렉션 삭제 (users/{uid}/walk_sessions)
      await _deleteUserWalkSessions(uid);

      // 2. 전역 산책 기록 데이터 삭제 (walk_sessions 컬렉션)
      await _deleteWalkSessions(uid);

      // 3. 사용자 기본 정보 삭제 (users/{uid} 문서)
      await _deleteUserDocument(uid);

    } catch (e) {
      LogService.error('AccountDeletion', 'Firestore 데이터 삭제 실패: $e');
      throw Exception('Firestore 데이터 삭제 실패: $e');
    }
  }

  /// 사용자별 산책 기록 서브컬렉션 삭제 (users/{uid}/walk_sessions)
  Future<void> _deleteUserWalkSessions(String uid) async {
    try {
      final QuerySnapshot userWalkSessions = await _firestore
          .collection('users')
          .doc(uid)
          .collection('walk_sessions')
          .get();

      final List<Future<void>> deleteOperations =
          userWalkSessions.docs.map((doc) => doc.reference.delete()).toList();

      await Future.wait(deleteOperations);

      LogService.debug('AccountDeletion',
          '사용자별 산책 기록 ${userWalkSessions.docs.length}개 삭제 완료');
    } catch (e) {
      LogService.error('AccountDeletion', '사용자별 산책 기록 삭제 실패: $e');
      throw e;
    }
  }

  /// 전역 산책 기록 데이터 삭제 (walk_sessions 컬렉션)
  Future<void> _deleteWalkSessions(String uid) async {
    try {
      final QuerySnapshot walkSessions = await _firestore
          .collection('walk_sessions')
          .where('userId', isEqualTo: uid)
          .get();

      final List<Future<void>> deleteOperations =
          walkSessions.docs.map((doc) => doc.reference.delete()).toList();

      await Future.wait(deleteOperations);

      LogService.debug(
          'AccountDeletion', '전역 산책 기록 ${walkSessions.docs.length}개 삭제 완료');
    } catch (e) {
      LogService.error('AccountDeletion', '전역 산책 기록 삭제 실패: $e');
      throw e;
    }
  }

  /// 사용자 기본 정보 문서 삭제
  Future<void> _deleteUserDocument(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      LogService.debug('AccountDeletion', 'Firestore 사용자 기본 정보 삭제 완료');
    } catch (e) {
      LogService.error('AccountDeletion', 'Firestore 사용자 기본 정보 삭제 실패: $e');
      throw e;
    }
  }

  /// Storage 데이터 삭제 (재시도 포함)
  Future<void> _deleteStorageDataWithRetry(String uid, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        LogService.info('AccountDeletion', 'Storage 삭제 시도 $attempt/$maxRetries');
        await _deleteStorageData(uid);
        return; // 성공 시 종료
      } catch (e) {
        LogService.warning('AccountDeletion', 'Storage 삭제 시도 $attempt/$maxRetries 실패: $e');
        if (attempt == maxRetries) {
          // Storage 삭제 실패도 이제 예외를 던져서 전체 프로세스가 실패로 처리되도록 함
          LogService.error('AccountDeletion', 'Storage 데이터 삭제 최종 실패: $e');
          throw Exception('Storage 데이터 삭제 최종 실패 ($maxRetries회 시도): $e');
        }
        // 재시도 전 더 오래 대기 (Storage 작업은 시간이 걸릴 수 있음)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Storage 데이터 삭제
  Future<void> _deleteStorageData(String uid) async {
    try {
      // 1. 사용자 프로필 이미지 삭제
      await _deleteProfileImages(uid);

      // 2. 사용자 산책 사진 삭제
      await _deleteUserPhotos(uid);

    } catch (e) {
      LogService.error('AccountDeletion', 'Storage 데이터 삭제 실패: $e');
      throw Exception('Storage 데이터 삭제 실패: $e');
    }
  }

  /// 프로필 이미지 삭제
  Future<void> _deleteProfileImages(String uid) async {
    try {
      LogService.info('AccountDeletion', 'profile_images/$uid 폴더 삭제 시작');
      final userFolderRef = _storage.ref().child('profile_images').child(uid);
      final ListResult result = await userFolderRef.listAll();

      LogService.info('AccountDeletion', 'profile_images/$uid에서 ${result.items.length}개 파일 발견');

      if (result.items.isNotEmpty) {
        // 각 파일을 개별적으로 삭제하여 더 자세한 로그 출력
        for (int i = 0; i < result.items.length; i++) {
          final fileRef = result.items[i];
          try {
            LogService.info('AccountDeletion', '프로필 파일 삭제 중 (${i + 1}/${result.items.length}): ${fileRef.fullPath}');
            await fileRef.delete();
            LogService.info('AccountDeletion', '프로필 파일 삭제 성공: ${fileRef.fullPath}');
          } catch (fileError) {
            LogService.error('AccountDeletion', '개별 프로필 파일 삭제 실패: ${fileRef.fullPath} - $fileError');
            throw Exception('Storage 프로필 파일 삭제 실패: ${fileRef.fullPath} - $fileError');
          }
        }

        LogService.info('AccountDeletion', 'profile_images/$uid 폴더의 모든 파일 삭제 완료 (${result.items.length}개)');
      } else {
        LogService.info('AccountDeletion', 'profile_images/$uid 폴더에 삭제할 파일이 없음');
      }
    } catch (e) {
      LogService.error('AccountDeletion', 'profile_images/$uid 폴더 삭제 실패: $e');
      throw Exception('Storage 프로필 이미지 삭제 실패: $e');
    }
  }

  /// 사용자 산책 사진 삭제
  Future<void> _deleteUserPhotos(String uid) async {
    try {
      LogService.info('AccountDeletion', 'user_photos/$uid 폴더 삭제 시작');
      final userPhotosRef = _storage.ref().child('user_photos').child(uid);
      final ListResult result = await userPhotosRef.listAll();

      LogService.info('AccountDeletion', 'user_photos/$uid에서 ${result.items.length}개 파일 발견');

      if (result.items.isNotEmpty) {
        // 각 파일을 개별적으로 삭제하여 더 자세한 로그 출력
        for (int i = 0; i < result.items.length; i++) {
          final fileRef = result.items[i];
          try {
            LogService.info('AccountDeletion', '파일 삭제 중 (${i + 1}/${result.items.length}): ${fileRef.fullPath}');
            await fileRef.delete();
            LogService.info('AccountDeletion', '파일 삭제 성공: ${fileRef.fullPath}');
          } catch (fileError) {
            LogService.error('AccountDeletion', '개별 파일 삭제 실패: ${fileRef.fullPath} - $fileError');
            throw Exception('Storage 파일 삭제 실패: ${fileRef.fullPath} - $fileError');
          }
        }

        LogService.info('AccountDeletion', 'user_photos/$uid 폴더의 모든 파일 삭제 완료 (${result.items.length}개)');
      } else {
        LogService.info('AccountDeletion', 'user_photos/$uid 폴더에 삭제할 파일이 없음');
      }

      // 폴더가 비어있는지 재확인
      final verificationResult = await userPhotosRef.listAll();
      if (verificationResult.items.isNotEmpty) {
        LogService.warning('AccountDeletion', '삭제 후에도 user_photos/$uid에 ${verificationResult.items.length}개 파일이 남아있음');
        throw Exception('Storage 폴더 삭제 검증 실패: 여전히 ${verificationResult.items.length}개 파일이 남아있음');
      } else {
        LogService.info('AccountDeletion', 'user_photos/$uid 폴더 삭제 검증 완료');
      }
    } catch (e) {
      LogService.error('AccountDeletion', 'user_photos/$uid 폴더 삭제 실패: $e');
      // 이제 예외를 다시 던져서 전체 프로세스가 실패로 처리되도록 함
      throw Exception('Storage 산책 사진 삭제 실패: $e');
    }
  }

  /// Firebase Auth 계정 삭제 (재시도 포함)
  Future<void> _deleteAuthAccountWithRetry(User user, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        LogService.info('AccountDeletion', 'Auth 계정 삭제 시도 $attempt/$maxRetries');
        await _deleteAuthAccount(user);
        return; // 성공 시 종료
      } catch (e) {
        LogService.warning('AccountDeletion', 'Auth 계정 삭제 시도 $attempt/$maxRetries 실패: $e');
        if (attempt == maxRetries) {
          throw Exception('Firebase Auth 계정 삭제 최종 실패 ($maxRetries회 시도): $e');
        }
        // 재시도 전 토큰 갱신 및 대기
        try {
          await user.getIdToken(true);
          LogService.info('AccountDeletion', 'Auth 재시도를 위한 토큰 갱신 완료');
        } catch (tokenError) {
          LogService.warning('AccountDeletion', '토큰 갱신 실패: $tokenError');
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Firebase Auth 계정 삭제 (마지막 단계)
  Future<void> _deleteAuthAccount(User user) async {
    try {
      // 계정 삭제 전 최종 확인
      if (user.isAnonymous) {
        throw Exception('익명 사용자는 삭제할 수 없습니다.');
      }

      await user.delete();
    } catch (e) {
      LogService.error('AccountDeletion', 'Firebase Auth 계정 삭제 실패: $e');
      throw Exception('계정 삭제에 실패했습니다: $e');
    }
  }

  /// 부분 삭제된 데이터 정리 (오류 발생 시)
  Future<void> _cleanupPartialDeletion(String uid) async {
    try {
      LogService.debug('AccountDeletion', '부분 삭제된 데이터 정리 시작');

      // Firestore 데이터 정리 시도
      try {
        await _firestore.collection('users').doc(uid).delete();
        LogService.debug('AccountDeletion', '부분 삭제된 사용자 문서 정리 완료');
      } catch (e) {
        LogService.debug('AccountDeletion', '부분 삭제된 사용자 문서 정리 실패: $e');
      }

      // Storage 데이터 정리 시도
      try {
        // 프로필 이미지 정리
        final profileFolderRef =
            _storage.ref().child('profile_images').child(uid);
        final profileResult = await profileFolderRef.listAll();

        for (final Reference fileRef in profileResult.items) {
          try {
            await fileRef.delete();
          } catch (e) {
            LogService.debug(
                'AccountDeletion', '프로필 이미지 정리 실패: ${fileRef.fullPath} - $e');
          }
        }

        // 산책 사진 정리
        final photosFolderRef = _storage.ref().child('user_photos').child(uid);
        final photosResult = await photosFolderRef.listAll();

        for (final Reference fileRef in photosResult.items) {
          try {
            await fileRef.delete();
          } catch (e) {
            LogService.debug(
                'AccountDeletion', '산책 사진 정리 실패: ${fileRef.fullPath} - $e');
          }
        }

        LogService.debug('AccountDeletion', '부분 삭제된 Storage 파일 정리 완료');
      } catch (e) {
        LogService.debug('AccountDeletion', 'Storage 정리 실패: $e');
      }
    } catch (e) {
      LogService.error('AccountDeletion', '부분 삭제 데이터 정리 실패: $e');
    }
  }
}

/// 회원탈퇴 결과를 담는 클래스
class AccountDeletionResult {
  final bool isSuccess;
  final String message;
  final String? failedStep; // 실패한 단계 정보 추가

  AccountDeletionResult({
    required this.isSuccess,
    required this.message,
    this.failedStep,
  });
}
