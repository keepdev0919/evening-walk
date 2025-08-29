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
  
  // 중복 호출 방지 플래그
  bool _isDeletionInProgress = false;

  /// 회원탈퇴 실행 - 모든 사용자 데이터를 완전히 삭제
  Future<AccountDeletionResult> deleteAccount() async {
    // 중복 호출 방지
    if (_isDeletionInProgress) {
      LogService.warning('AccountDeletion', '회원탈퇴가 이미 진행 중입니다.');
      return AccountDeletionResult(
        isSuccess: false,
        message: '회원탈퇴가 이미 진행 중입니다. 잠시 후 다시 시도해주세요.',
      );
    }
    
    _isDeletionInProgress = true;
    
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

      // 3단계: Storage 데이터 삭제 (Firestore 삭제 전에 실행)
      LogService.info('AccountDeletion', '[단계 2/4] Storage 데이터 삭제 시작');
      await _deleteStorageDataWithRetry(uid);
      completedSteps.add('Storage데이터삭제');
      LogService.info('AccountDeletion', '[단계 2/4] Storage 데이터 삭제 완료');

      // 4단계: Firestore 사용자 데이터 삭제 (Storage 삭제 후 실행)
      LogService.info('AccountDeletion', '[단계 3/4] Firestore 데이터 삭제 시작');
      await _deleteFirestoreDataWithRetry(uid);
      completedSteps.add('Firestore데이터삭제');
      LogService.info('AccountDeletion', '[단계 3/4] Firestore 데이터 삭제 완료');

      // 5단계: Firebase Auth 계정 삭제 (마지막 단계, 재시도 포함)
      LogService.info('AccountDeletion', '[단계 4/4] Firebase Auth 계정 삭제 시작');
      await _deleteAuthAccountWithRetry(currentUser);
      completedSteps.add('Auth계정삭제');
      LogService.info('AccountDeletion', '[단계 4/4] Firebase Auth 계정 삭제 완료');

      LogService.info('AccountDeletion', '====== 회원탈퇴 프로세스 완료 ======');
      LogService.info(
          'AccountDeletion', '완료된 단계: ${completedSteps.join(", ")}');

      return AccountDeletionResult(
        isSuccess: true,
        message: '회원탈퇴가 완료되었습니다.',
      );
    } catch (e) {
      LogService.error('AccountDeletion', '====== 회원탈퇴 프로세스 실패 ======');
      LogService.error(
          'AccountDeletion', '완료된 단계: ${completedSteps.join(", ")}');
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
    } finally {
      // 진행 중 플래그 해제
      _isDeletionInProgress = false;
    }
  }

  /// 실패한 단계를 파악하는 헬퍼 메서드
  String _getFailedStep(List<String> completedSteps) {
    if (!completedSteps.contains('Storage데이터삭제')) {
      return 'Storage 데이터 삭제';
    } else if (!completedSteps.contains('Firestore데이터삭제')) {
      return 'Firestore 데이터 삭제';
    } else if (!completedSteps.contains('Auth계정삭제')) {
      return 'Auth 계정 삭제';
    }
    return '알 수 없음';
  }

  /// Firestore 사용자 데이터 삭제 (재시도 포함)
  Future<void> _deleteFirestoreDataWithRetry(String uid,
      {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        LogService.info(
            'AccountDeletion', 'Firestore 삭제 시도 $attempt/$maxRetries');
        await _deleteFirestoreData(uid);
        return; // 성공 시 종료
      } catch (e) {
        LogService.warning(
            'AccountDeletion', 'Firestore 삭제 시도 $attempt/$maxRetries 실패: $e');
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
  Future<void> _deleteStorageDataWithRetry(String uid,
      {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        LogService.info(
            'AccountDeletion', 'Storage 삭제 시도 $attempt/$maxRetries');

        // Storage 삭제 전 Auth 상태 재확인
        await _verifyAuthStateBeforeStorage(uid);

        await _deleteStorageData(uid);
        return; // 성공 시 종료
      } catch (e) {
        LogService.warning(
            'AccountDeletion', 'Storage 삭제 시도 $attempt/$maxRetries 실패: $e');
        
        // 권한 오류인 경우 더 이상 재시도하지 않고 경고만 남김
        if (e.toString().contains('403') ||
            e.toString().contains('Permission denied') ||
            e.toString().contains('Permission')) {
          LogService.warning('AccountDeletion', 'Storage 권한 오류 발생, 재시도 중단하고 계속 진행: $e');
          return;
        }
        
        if (attempt == maxRetries) {
          // Storage 삭제 실패는 경고로 처리하고 계속 진행
          LogService.warning('AccountDeletion', 'Storage 데이터 삭제 최종 실패하지만 계속 진행: $e');
          return;
        }
        // 재시도 전 더 오래 대기 (Storage 작업은 시간이 걸릴 수 있음)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Storage 삭제 전 Auth 상태 재확인
  Future<void> _verifyAuthStateBeforeStorage(String uid) async {
    try {
      LogService.info('AccountDeletion', 'Storage 삭제 전 Auth 상태 재확인 시작');

      // 현재 사용자 확인
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Auth 상태 확인 실패: 로그인된 사용자 없음');
      }

      // UID 일치 확인
      if (currentUser.uid != uid) {
        throw Exception(
            'Auth 상태 확인 실패: UID 불일치 (현재: ${currentUser.uid}, 요청: $uid)');
      }

      // 토큰 갱신으로 최신 상태 확인
      try {
        final token = await currentUser.getIdToken(true);
        LogService.info('AccountDeletion',
            'Auth 토큰 갱신 성공: ${token?.substring(0, 20) ?? "null"}...');
      } catch (tokenError) {
        LogService.warning('AccountDeletion', 'Auth 토큰 갱신 실패: $tokenError');
        throw Exception('Auth 토큰 갱신 실패: $tokenError');
      }

      LogService.info('AccountDeletion', 'Storage 삭제 전 Auth 상태 재확인 완료');
    } catch (e) {
      LogService.error('AccountDeletion', 'Storage 삭제 전 Auth 상태 재확인 실패: $e');
      throw Exception('Storage 삭제 전 Auth 상태 확인 실패: $e');
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
      
      // 현재 Auth 상태 로깅
      final currentUser = _auth.currentUser;
      LogService.info('AccountDeletion',
          '프로필 이미지 삭제 - 현재 Auth 상태 - UID: ${currentUser?.uid}');

      // listAll()을 사용하여 실제 Storage 폴더에서 모든 파일 삭제
      await _deleteProfileImagesDirectly(uid);
      
      LogService.info('AccountDeletion', 'profile_images/$uid 폴더 삭제 완료');
    } catch (e) {
      LogService.error('AccountDeletion', 'profile_images/$uid 폴더 삭제 실패: $e');

      // 403 에러 처리 - 경고로만 기록하고 계속 진행
      if (e.toString().contains('403') ||
          e.toString().contains('Permission denied') ||
          e.toString().contains('Permission')) {
        final currentUser = _auth.currentUser;
        LogService.warning('AccountDeletion', '프로필 이미지 403 권한 에러 (무시하고 진행):');
        LogService.warning('AccountDeletion', '- 요청 UID: $uid');
        LogService.warning(
            'AccountDeletion', '- 현재 Auth UID: ${currentUser?.uid}');
        LogService.warning('AccountDeletion',
            '- Auth 상태: ${currentUser != null ? "로그인됨" : "로그아웃됨"}');
        
        // 403 에러는 파일이 없을 수도 있으므로 경고만 하고 계속 진행
        LogService.warning('AccountDeletion', 'Storage 권한 에러이지만 계속 진행합니다.');
        return;
      }

      // 다른 에러도 로그만 남기고 계속 진행 (Storage 삭제 실패가 전체 프로세스를 중단하지 않도록)
      LogService.warning('AccountDeletion', 'Storage 프로필 이미지 삭제 실패하지만 계속 진행: $e');
    }
  }

  /// Storage에서 직접 프로필 이미지 폴더 전체 삭제
  Future<void> _deleteProfileImagesDirectly(String uid) async {
    try {
      LogService.info('AccountDeletion', 'profile_images/$uid 폴더에서 직접 파일 검색 시작');

      final profileImagesRef = _storage.ref().child('profile_images').child(uid);
      
      try {
        final ListResult result = await profileImagesRef.listAll();
        
        LogService.info('AccountDeletion', 'profile_images/$uid 폴더에서 ${result.items.length}개 파일 발견');
        
        int deletedCount = 0;
        
        // 모든 파일 순차 삭제 (병렬 처리 방지)
        for (final Reference fileRef in result.items) {
          try {
            await fileRef.delete();
            deletedCount++;
            LogService.info('AccountDeletion', '프로필 이미지 삭제 성공: ${fileRef.name}');
          } catch (e) {
            if (e.toString().contains('object-not-found') || 
                e.toString().contains('404') ||
                e.toString().contains('Not Found')) {
              LogService.debug('AccountDeletion', '프로필 이미지 파일 없음 (정상): ${fileRef.name}');
            } else if (e.toString().contains('403') ||
                       e.toString().contains('Permission denied') ||
                       e.toString().contains('Permission')) {
              LogService.warning('AccountDeletion', '프로필 이미지 권한 오류, 즉시 중단: ${fileRef.name}');
              throw Exception('프로필 이미지 삭제 권한 오류: ${fileRef.name}');
            } else {
              LogService.warning('AccountDeletion', '프로필 이미지 삭제 실패: ${fileRef.name} - $e');
              // 404가 아닌 다른 오류는 계속 진행
            }
          }
        }
        
        // 하위 폴더도 확인 (만약 있다면)
        for (final Reference prefixRef in result.prefixes) {
          try {
            LogService.info('AccountDeletion', '프로필 이미지 하위 폴더 발견: ${prefixRef.name}');
            await _deleteSubfolderFiles(prefixRef);
          } catch (e) {
            LogService.warning('AccountDeletion', '프로필 이미지 하위 폴더 삭제 실패: ${prefixRef.name} - $e');
          }
        }
        
        LogService.info('AccountDeletion', '프로필 이미지 직접 삭제 완료: $deletedCount개 파일 삭제');
        
      } catch (e) {
        if (e.toString().contains('object-not-found') || 
            e.toString().contains('404') ||
            e.toString().contains('Not Found')) {
          LogService.info('AccountDeletion', 'profile_images/$uid 폴더가 존재하지 않음 (정상)');
        } else {
          throw e;
        }
      }
      
    } catch (e) {
      LogService.error('AccountDeletion', '프로필 이미지 직접 삭제 실패: $e');
      throw Exception('프로필 이미지 직접 삭제 실패: $e');
    }
  }

  /// 알려진 프로필 이미지 파일들을 삭제 (백업용)
  Future<void> _deleteKnownProfileImageFiles(String uid) async {
    final profileImageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    final profileImageNames = ['profile', 'avatar', 'user_image'];
    
    int deletedCount = 0;
    
    for (final name in profileImageNames) {
      for (final ext in profileImageExtensions) {
        try {
          final fileRef = _storage.ref().child('profile_images').child(uid).child('$name.$ext');
          await fileRef.delete();
          deletedCount++;
          LogService.info('AccountDeletion', '프로필 파일 삭제 성공: profile_images/$uid/$name.$ext');
        } catch (e) {
          // 파일이 존재하지 않는 경우는 정상적인 상황이므로 debug 레벨로 로그
          if (e.toString().contains('object-not-found') || 
              e.toString().contains('404') ||
              e.toString().contains('Not Found')) {
            LogService.debug('AccountDeletion', '프로필 파일 없음 (정상): profile_images/$uid/$name.$ext');
          } else if (e.toString().contains('403') ||
                     e.toString().contains('Permission denied') ||
                     e.toString().contains('Permission')) {
            LogService.warning('AccountDeletion', '프로필 파일 권한 오류 (무시): profile_images/$uid/$name.$ext');
          } else {
            LogService.warning('AccountDeletion', '프로필 파일 삭제 실패: profile_images/$uid/$name.$ext - $e');
          }
        }
      }
    }
    
    LogService.info('AccountDeletion', '프로필 이미지 삭제 완료: $deletedCount개 파일 삭제');
  }

  /// 사용자 산책 사진 삭제
  Future<void> _deleteUserPhotos(String uid) async {
    try {
      LogService.info('AccountDeletion', 'user_photos/$uid 폴더 삭제 시작');

      // 현재 Auth 상태 로깅
      final currentUser = _auth.currentUser;
      LogService.info('AccountDeletion',
          '현재 Auth 상태 - UID: ${currentUser?.uid}, 이메일: ${currentUser?.email}');

      // listAll()을 사용하여 실제 Storage 폴더에서 모든 파일 삭제
      await _deleteUserPhotosDirectly(uid);
      
      LogService.info('AccountDeletion', 'user_photos/$uid 폴더 삭제 완료');
    } catch (e) {
      LogService.error('AccountDeletion', 'user_photos/$uid 폴더 삭제 실패: $e');

      // 403 에러 처리 - 경고로만 기록하고 계속 진행
      if (e.toString().contains('403') ||
          e.toString().contains('Permission denied') ||
          e.toString().contains('Permission')) {
        final currentUser = _auth.currentUser;
        LogService.warning('AccountDeletion', '산책 사진 403 권한 에러 (무시하고 진행):');
        LogService.warning('AccountDeletion', '- 요청 UID: $uid');
        LogService.warning(
            'AccountDeletion', '- 현재 Auth UID: ${currentUser?.uid}');
        LogService.warning('AccountDeletion',
            '- Auth 상태: ${currentUser != null ? "로그인됨" : "로그아웃됨"}');
        LogService.warning('AccountDeletion', '- 이메일: ${currentUser?.email}');

        // 403 에러는 파일이 없을 수도 있으므로 경고만 하고 계속 진행
        LogService.warning('AccountDeletion', 'Storage 권한 에러이지만 계속 진행합니다.');
        return;
      }

      // 다른 에러도 로그만 남기고 계속 진행 (Storage 삭제 실패가 전체 프로세스를 중단하지 않도록)
      LogService.warning('AccountDeletion', 'Storage 산책 사진 삭제 실패하지만 계속 진행: $e');
    }
  }

  /// Storage에서 직접 사용자 사진 폴더 전체 삭제
  Future<void> _deleteUserPhotosDirectly(String uid) async {
    try {
      LogService.info('AccountDeletion', 'user_photos/$uid 폴더에서 직접 파일 검색 시작');

      final userPhotosRef = _storage.ref().child('user_photos').child(uid);
      
      try {
        final ListResult result = await userPhotosRef.listAll();
        
        LogService.info('AccountDeletion', 'user_photos/$uid 폴더에서 ${result.items.length}개 파일 발견');
        
        int deletedCount = 0;
        
        // 모든 파일 순차 삭제 (병렬 처리 방지)
        for (final Reference fileRef in result.items) {
          try {
            await fileRef.delete();
            deletedCount++;
            LogService.info('AccountDeletion', '산책 사진 삭제 성공: ${fileRef.name}');
          } catch (e) {
            if (e.toString().contains('object-not-found') || 
                e.toString().contains('404') ||
                e.toString().contains('Not Found')) {
              LogService.debug('AccountDeletion', '산책 사진 파일 없음 (정상): ${fileRef.name}');
            } else if (e.toString().contains('403') ||
                       e.toString().contains('Permission denied') ||
                       e.toString().contains('Permission')) {
              LogService.warning('AccountDeletion', '산책 사진 권한 오류, 즉시 중단: ${fileRef.name}');
              throw Exception('산책 사진 삭제 권한 오류: ${fileRef.name}');
            } else {
              LogService.warning('AccountDeletion', '산책 사진 삭제 실패: ${fileRef.name} - $e');
              // 404가 아닌 다른 오류는 계속 진행
            }
          }
        }
        
        // 하위 폴더도 확인 (만약 있다면)
        for (final Reference prefixRef in result.prefixes) {
          try {
            LogService.info('AccountDeletion', '하위 폴더 발견: ${prefixRef.name}');
            await _deleteSubfolderFiles(prefixRef);
          } catch (e) {
            LogService.warning('AccountDeletion', '하위 폴더 삭제 실패: ${prefixRef.name} - $e');
          }
        }
        
        LogService.info('AccountDeletion', '산책 사진 직접 삭제 완료: $deletedCount개 파일 삭제');
        
      } catch (e) {
        if (e.toString().contains('object-not-found') || 
            e.toString().contains('404') ||
            e.toString().contains('Not Found')) {
          LogService.info('AccountDeletion', 'user_photos/$uid 폴더가 존재하지 않음 (정상)');
        } else {
          throw e;
        }
      }
      
    } catch (e) {
      LogService.error('AccountDeletion', '산책 사진 직접 삭제 실패: $e');
      throw Exception('산책 사진 직접 삭제 실패: $e');
    }
  }
  
  /// 하위 폴더의 모든 파일 삭제
  Future<void> _deleteSubfolderFiles(Reference folderRef) async {
    try {
      final ListResult result = await folderRef.listAll();
      
      // 폴더 내 파일 순차 삭제
      for (final Reference fileRef in result.items) {
        try {
          await fileRef.delete();
          LogService.debug('AccountDeletion', '하위 폴더 파일 삭제 성공: ${fileRef.fullPath}');
        } catch (e) {
          if (e.toString().contains('403') ||
              e.toString().contains('Permission denied') ||
              e.toString().contains('Permission')) {
            LogService.warning('AccountDeletion', '하위 폴더 파일 권한 오류, 중단: ${fileRef.fullPath}');
            throw Exception('하위 폴더 파일 삭제 권한 오류: ${fileRef.fullPath}');
          }
          LogService.warning('AccountDeletion', '하위 폴더 파일 삭제 실패: ${fileRef.fullPath} - $e');
        }
      }
      
      // 재귀적으로 더 깊은 하위 폴더 처리
      for (final Reference prefixRef in result.prefixes) {
        await _deleteSubfolderFiles(prefixRef);
      }
    } catch (e) {
      LogService.warning('AccountDeletion', '하위 폴더 처리 실패: ${folderRef.fullPath} - $e');
    }
  }

  /// Firestore 산책 기록을 참조하여 사용자 사진 삭제 (백업용)
  Future<void> _deleteUserPhotosFromFirestore(String uid) async {
    try {
      // 1. 사용자별 산책 기록에서 사진 URL 추출 및 삭제
      final userWalkSessions = await _firestore
          .collection('users')
          .doc(uid)
          .collection('walk_sessions')
          .get();

      int deletedPhotoCount = 0;

      for (final doc in userWalkSessions.docs) {
        final data = doc.data();
        
        // 목적지 사진 삭제
        if (data['destinationPhoto'] != null) {
          await _deletePhotoFromUrl(data['destinationPhoto'], uid);
          deletedPhotoCount++;
        }
        
        // 경유지 사진들 삭제
        if (data['waypointPhotos'] != null && data['waypointPhotos'] is List) {
          for (final photoUrl in data['waypointPhotos']) {
            if (photoUrl != null && photoUrl is String) {
              await _deletePhotoFromUrl(photoUrl, uid);
              deletedPhotoCount++;
            }
          }
        }
        
        // 기타 사진 필드들 확인 및 삭제 (추가 필드가 있다면)
        for (final entry in data.entries) {
          if (entry.key.toLowerCase().contains('photo') && 
              entry.value is String &&
              entry.value.toString().contains('user_photos/$uid')) {
            await _deletePhotoFromUrl(entry.value, uid);
            deletedPhotoCount++;
          }
        }
      }

      // 2. 전역 산책 기록에서도 확인
      final globalWalkSessions = await _firestore
          .collection('walk_sessions')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in globalWalkSessions.docs) {
        final data = doc.data();
        
        // 목적지 사진 삭제
        if (data['destinationPhoto'] != null) {
          await _deletePhotoFromUrl(data['destinationPhoto'], uid);
          deletedPhotoCount++;
        }
        
        // 경유지 사진들 삭제
        if (data['waypointPhotos'] != null && data['waypointPhotos'] is List) {
          for (final photoUrl in data['waypointPhotos']) {
            if (photoUrl != null && photoUrl is String) {
              await _deletePhotoFromUrl(photoUrl, uid);
              deletedPhotoCount++;
            }
          }
        }
      }

      LogService.info('AccountDeletion', '산책 사진 삭제 완료: $deletedPhotoCount개 파일 삭제');
    } catch (e) {
      LogService.error('AccountDeletion', 'Firestore 참조 사진 삭제 실패: $e');
      throw Exception('Firestore 참조 사진 삭제 실패: $e');
    }
  }

  /// URL에서 Storage 파일 삭제
  Future<void> _deletePhotoFromUrl(String photoUrl, String uid) async {
    try {
      // Firebase Storage URL에서 파일 경로 추출
      if (photoUrl.contains('user_photos/$uid')) {
        // URL에서 파일 경로 추출
        final uri = Uri.parse(photoUrl);
        final pathSegments = uri.pathSegments;
        
        // 파일 경로 구성 (예: user_photos/uid/filename.jpg)
        if (pathSegments.length >= 4) {
          final fileName = pathSegments.last.split('?').first; // 쿼리 파라미터 제거
          final fileRef = _storage.ref().child('user_photos').child(uid).child(fileName);
          
          await fileRef.delete();
          LogService.debug('AccountDeletion', '사진 삭제 성공: user_photos/$uid/$fileName');
        }
      }
    } catch (e) {
      if (e.toString().contains('object-not-found') || 
          e.toString().contains('404') ||
          e.toString().contains('Not Found')) {
        LogService.debug('AccountDeletion', '사진 파일 없음 (정상): $photoUrl');
      } else if (e.toString().contains('403') ||
                 e.toString().contains('Permission denied') ||
                 e.toString().contains('Permission')) {
        LogService.warning('AccountDeletion', '사진 파일 권한 오류 (무시): $photoUrl');
      } else {
        LogService.warning('AccountDeletion', '사진 삭제 실패: $photoUrl - $e');
      }
    }
  }

  /// Firebase Auth 계정 삭제 (재시도 포함)
  Future<void> _deleteAuthAccountWithRetry(User user,
      {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        LogService.info(
            'AccountDeletion', 'Auth 계정 삭제 시도 $attempt/$maxRetries');
        await _deleteAuthAccount(user);
        return; // 성공 시 종료
      } catch (e) {
        LogService.warning(
            'AccountDeletion', 'Auth 계정 삭제 시도 $attempt/$maxRetries 실패: $e');
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
