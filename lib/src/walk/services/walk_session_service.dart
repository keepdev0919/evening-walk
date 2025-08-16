import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walk/src/features/walk/domain/models/walk_session.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/core/services/log_service.dart';
// import 'package:walk/src/features/walk/application/services/photo_upload_service.dart';

/// 산책 세션 관리를 위한 Firebase 연동 서비스
class WalkSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final PhotoUploadService _photoUploadService = PhotoUploadService(); // 미사용

  /// 산책 세션을 Firebase에 저장
  Future<String?> saveWalkSession({
    required WalkStateManager walkStateManager,
    String? walkReflection,
    String? locationName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LogService.warning('Walk', 'WalkSessionService: 사용자가 로그인되지 않음');
        return null;
      }

      if (walkStateManager.startLocation == null ||
          walkStateManager.waypointLocation == null) {
        LogService.warning('Walk', 'WalkSessionService: 필수 위치 정보가 누락됨');
        return null;
      }

      // 서브컬렉션에서 고유 ID 생성
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('walk_sessions')
          .doc();

      // // 사진이 있으면 Firebase Storage에 업로드
      // String? uploadedPhotoUrl;
      // if (walkStateManager.photoPath != null) {
      //   LogService.info('Walk', 'WalkSessionService: 사진 업로드 시작');
      //   uploadedPhotoUrl = await _photoUploadService.uploadDestinationPhoto(
      //     filePath: walkStateManager.photoPath!,
      //     sessionId: docRef.id,
      //   );

      //   if (uploadedPhotoUrl != null) {
      //     LogService.info('Walk', 'WalkSessionService: 사진 업로드 완료 - $uploadedPhotoUrl');
      //   } else {
      //     LogService.info('Walk', 'WalkSessionService: 사진 업로드 실패');
      //   }
      // }

      // WalkSession 객체 생성
      final walkSession = WalkSession.fromWalkStateManager(
        id: docRef.id,
        userId: user.uid,
        startTime: walkStateManager.actualStartTime ??
            DateTime.now().subtract(const Duration(hours: 1)), // 실제 시작 시간 사용
        startLocation: walkStateManager.startLocation!,
        // 목적지 좌표는 실제 목적지로 저장
        destinationLocation: walkStateManager.destinationLocation!,
        waypointLocation: walkStateManager.waypointLocation!,
        selectedMate: walkStateManager.selectedMate ?? '혼자',
        waypointQuestion: walkStateManager.waypointQuestion,
        waypointAnswer: walkStateManager.userAnswer,
        poseImageUrl: walkStateManager.poseImageUrl, // 추천 포즈 URL 저장
        takenPhotoPath: walkStateManager.photoPath, // 업로드된 Storage URL 사용
        walkReflection: walkReflection,
        locationName: locationName,
        endTime: walkStateManager.actualEndTime, // 실제 종료 시간 설정
        totalDuration: walkStateManager.actualDurationInMinutes, // 실제 소요 시간 설정
        totalDistance: walkStateManager.accumulatedDistanceKm, // 누적 이동 거리(km)
        customStartName: walkStateManager.customStartName,
      );

      // Firestore에 저장 전 디버깅
      LogService.debug('Walk', 'WalkSessionService: 저장할 데이터 확인');
      LogService.debug('Walk', '사용자 ID: ${user.uid}');
      LogService.debug('Walk', '문서 ID: ${docRef.id}');

      final firestoreData = walkSession.toFirestore();
      LogService.info('Walk', '저장할 데이터: $firestoreData');

      await docRef.set(firestoreData);

      LogService.info(
          'Walk', 'WalkSessionService: 산책 세션 저장 완료 - ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      LogService.error('Walk', 'WalkSessionService: 산책 세션 저장 중 오류 발생', e);
      return null;
    }
  }

  /// 사용자의 모든 산책 세션 목록을 최신순으로 가져오기
  ///
  /// Firebase 인덱스 필요:
  /// Collection: users/{userId}/walk_sessions
  /// Fields: startTime (Descending)
  Future<List<WalkSession>> getUserWalkSessions({int? limit}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LogService.warning('Walk', 'WalkSessionService: 사용자가 로그인되지 않음');
        return [];
      }

      // 서브컬렉션에서 최신순으로 정렬해서 가져오기 (서버사이드 정렬)
      Query query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('walk_sessions')
          .orderBy('startTime', descending: true); // 최신순 정렬

      // limit이 지정된 경우에만 적용
      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();

      final walkSessions = querySnapshot.docs
          .map((doc) => WalkSession.fromFirestore(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      LogService.info('Walk',
          'WalkSessionService: ${walkSessions.length}개의 산책 세션을 Firebase에서 최신순으로 가져왔습니다.');
      return walkSessions;
    } catch (e) {
      LogService.error('Walk', 'WalkSessionService: 산책 세션 목록 가져오기 중 오류 발생', e);
      return [];
    }
  }

  /// 실시간 산책 세션 목록 스트림 (홈화면에서 실시간 업데이트용)
  ///
  /// Firebase 인덱스 필요:
  /// Collection: users/{userId}/walk_sessions
  /// Fields: startTime (Descending)
  Stream<List<WalkSession>> getUserWalkSessionsStream({int? limit}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // 서브컬렉션에서 최신순으로 정렬해서 가져오기 (서버사이드 정렬)
    Query query = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('walk_sessions')
        .orderBy('startTime', descending: true); // 최신순 정렬

    // limit이 지정된 경우에만 적용
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => WalkSession.fromFirestore(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  /// 특정 산책 세션 하나만 가져오기
  Future<WalkSession?> getWalkSession(String sessionId) async {
    try {
      // 현재 사용자의 세션인지 확인을 위해 userId 필요
      final user = _auth.currentUser;
      if (user == null) {
        LogService.warning('Walk', 'WalkSessionService: 사용자가 로그인되지 않음');
        return null;
      }

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('walk_sessions')
          .doc(sessionId)
          .get();

      if (doc.exists && doc.data() != null) {
        return WalkSession.fromFirestore(doc.data()!, doc.id);
      } else {
        LogService.info(
            'Walk', 'WalkSessionService: 세션 ID $sessionId를 찾을 수 없음');
        return null;
      }
    } catch (e) {
      LogService.error('Walk', 'WalkSessionService: 산책 세션 가져오기 중 오류 발생', e);
      return null;
    }
  }

  /// 산책 세션 업데이트 (소감 수정 등)
  Future<bool> updateWalkSession(
      String sessionId, Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LogService.warning('Walk', 'WalkSessionService: 사용자가 로그인되지 않음');
        return false;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('walk_sessions')
          .doc(sessionId)
          .update(updates);

      LogService.info('Walk', 'WalkSessionService: 세션 $sessionId 업데이트 완료');
      return true;
    } catch (e) {
      LogService.error('Walk', 'WalkSessionService: 산책 세션 업데이트 중 오류 발생', e);
      return false;
    }
  }

  /// 산책 세션 삭제
  Future<bool> deleteWalkSession(String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LogService.warning('Walk', 'WalkSessionService: 사용자가 로그인되지 않음');
        return false;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('walk_sessions')
          .doc(sessionId)
          .delete();

      LogService.info('Walk', 'WalkSessionService: 세션 $sessionId 삭제 완료');
      return true;
    } catch (e) {
      LogService.error('Walk', 'WalkSessionService: 산책 세션 삭제 중 오류 발생', e);
      return false;
    }
  }

  /// 사용자 통계 조회 (총 산책 횟수, 총 시간 등)
  Future<Map<String, dynamic>> getUserWalkStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'totalWalks': 0, 'totalDuration': 0, 'totalDistance': 0.0};
      }

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('walk_sessions')
          .get();

      int totalWalks = querySnapshot.docs.length;
      int totalDuration = 0; // 분 단위
      double totalDistance = 0.0; // km 단위

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        totalDuration += (data['totalDuration'] as int?) ?? 0;
        totalDistance += (data['totalDistance'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'totalWalks': totalWalks,
        'totalDuration': totalDuration,
        'totalDistance': totalDistance,
      };
    } catch (e) {
      LogService.error('Walk', 'WalkSessionService: 사용자 통계 조회 중 오류 발생', e);
      return {'totalWalks': 0, 'totalDuration': 0, 'totalDistance': 0.0};
    }
  }

  /// 사진 없이 즉시 저장하는 메서드 (빠른 저장용)
  Future<String?> saveWalkSessionWithoutPhoto({
    required WalkStateManager walkStateManager,
    String? walkReflection,
    String? locationName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        LogService.warning('Walk', 'WalkSessionService: 사용자가 로그인되지 않음');
        return null;
      }

      if (walkStateManager.startLocation == null ||
          walkStateManager.waypointLocation == null) {
        LogService.warning('Walk', 'WalkSessionService: 필수 위치 정보가 누락됨');
        return null;
      }

      // 서브컬렉션에서 고유 ID 생성
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('walk_sessions')
          .doc();

      // WalkSession 객체 생성 (사진 없이)
      final walkSession = WalkSession.fromWalkStateManager(
        id: docRef.id,
        userId: user.uid,
        startTime: walkStateManager.actualStartTime ??
            DateTime.now().subtract(const Duration(hours: 1)),
        startLocation: walkStateManager.startLocation!,
        // 목적지 좌표는 실제 목적지로 저장
        destinationLocation: walkStateManager.destinationLocation!,
        waypointLocation: walkStateManager.waypointLocation!,
        selectedMate: walkStateManager.selectedMate ?? '혼자',
        waypointQuestion: walkStateManager.waypointQuestion,
        waypointAnswer: walkStateManager.userAnswer,
        poseImageUrl: walkStateManager.poseImageUrl, // 추천 포즈 URL 저장
        takenPhotoPath: walkStateManager.photoPath, // 사진 경로 포함
        walkReflection: walkReflection,
        locationName: locationName,
        endTime: walkStateManager.actualEndTime,
        totalDuration: walkStateManager.actualDurationInMinutes,
        totalDistance: walkStateManager.accumulatedDistanceKm,
        customStartName: walkStateManager.customStartName,
      );

      // Firestore에 즉시 저장
      final firestoreData = walkSession.toFirestore();
      await docRef.set(firestoreData);

      LogService.info(
          'Walk', 'WalkSessionService: 산책 세션 즉시 저장 완료 - ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      LogService.error('Walk', 'WalkSessionService: 산책 세션 즉시 저장 중 오류 발생', e);
      return null;
    }
  }
}
