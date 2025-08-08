import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/src/features/walk/domain/models/walk_session.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';

/// 산책 세션 관리를 위한 Firebase 연동 서비스
class WalkSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 산책 세션을 Firebase에 저장
  Future<String?> saveWalkSession({
    required WalkStateManager walkStateManager,
    String? walkReflection,
    List<String>? customHashtags,
    String? weatherInfo,
    String? locationName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('WalkSessionService: 사용자가 로그인되지 않음');
        return null;
      }

      if (walkStateManager.startLocation == null ||
          walkStateManager.waypointLocation == null) {
        print('WalkSessionService: 필수 위치 정보가 누락됨');
        return null;
      }

      // 고유 ID 생성
      final docRef = _firestore.collection('walk_sessions').doc();
      
      // WalkSession 객체 생성
      final walkSession = WalkSession.fromWalkStateManager(
        id: docRef.id,
        userId: user.uid,
        startTime: DateTime.now().subtract(const Duration(hours: 1)), // 임시로 1시간 전을 시작 시간으로 설정
        startLocation: walkStateManager.startLocation!,
        destinationLocation: walkStateManager.startLocation!, // 임시로 출발지와 동일하게 설정 - 실제로는 destinationLocation을 사용해야 함
        waypointLocation: walkStateManager.waypointLocation!,
        selectedMate: walkStateManager.selectedMate ?? '혼자',
        waypointQuestion: walkStateManager.waypointQuestion,
        waypointAnswer: walkStateManager.userAnswer,
        poseImageUrl: null, // PoseImageService의 URL은 일반적으로 로컬 캐시이므로 저장하지 않음
        takenPhotoPath: walkStateManager.photoPath,
        walkReflection: walkReflection,
        hashtags: customHashtags ?? ['#저녁산책', '#포즈추천'],
        weatherInfo: weatherInfo,
        locationName: locationName,
      );

      // Firestore에 저장
      await docRef.set(walkSession.toFirestore());
      
      print('WalkSessionService: 산책 세션 저장 완료 - ID: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('WalkSessionService: 산책 세션 저장 중 오류 발생: $e');
      return null;
    }
  }

  /// 사용자의 모든 산책 세션 목록을 최신순으로 가져오기
  Future<List<WalkSession>> getUserWalkSessions({int limit = 20}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('WalkSessionService: 사용자가 로그인되지 않음');
        return [];
      }

      final querySnapshot = await _firestore
          .collection('walk_sessions')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true) // 최신순 정렬
          .limit(limit)
          .get();

      final walkSessions = querySnapshot.docs
          .map((doc) => WalkSession.fromFirestore(doc.data(), doc.id))
          .toList();

      print('WalkSessionService: ${walkSessions.length}개의 산책 세션을 가져왔습니다.');
      return walkSessions;

    } catch (e) {
      print('WalkSessionService: 산책 세션 목록 가져오기 중 오류 발생: $e');
      return [];
    }
  }

  /// 실시간 산책 세션 목록 스트림 (홈화면에서 실시간 업데이트용)
  Stream<List<WalkSession>> getUserWalkSessionsStream({int limit = 10}) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('walk_sessions')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalkSession.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// 특정 산책 세션 하나만 가져오기
  Future<WalkSession?> getWalkSession(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('walk_sessions')
          .doc(sessionId)
          .get();

      if (doc.exists && doc.data() != null) {
        return WalkSession.fromFirestore(doc.data()!, doc.id);
      } else {
        print('WalkSessionService: 세션 ID $sessionId를 찾을 수 없음');
        return null;
      }
    } catch (e) {
      print('WalkSessionService: 산책 세션 가져오기 중 오류 발생: $e');
      return null;
    }
  }

  /// 산책 세션 업데이트 (소감 수정 등)
  Future<bool> updateWalkSession(String sessionId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('walk_sessions')
          .doc(sessionId)
          .update(updates);
      
      print('WalkSessionService: 세션 $sessionId 업데이트 완료');
      return true;
    } catch (e) {
      print('WalkSessionService: 산책 세션 업데이트 중 오류 발생: $e');
      return false;
    }
  }

  /// 산책 세션 삭제
  Future<bool> deleteWalkSession(String sessionId) async {
    try {
      await _firestore
          .collection('walk_sessions')
          .doc(sessionId)
          .delete();
      
      print('WalkSessionService: 세션 $sessionId 삭제 완료');
      return true;
    } catch (e) {
      print('WalkSessionService: 산책 세션 삭제 중 오류 발생: $e');
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
          .collection('walk_sessions')
          .where('userId', isEqualTo: user.uid)
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
      print('WalkSessionService: 사용자 통계 조회 중 오류 발생: $e');
      return {'totalWalks': 0, 'totalDuration': 0, 'totalDistance': 0.0};
    }
  }

  /// 간편한 저장 메서드 (WalkDiaryDialog에서 사용)
  static Future<void> quickSave({
    required WalkStateManager walkStateManager,
    String? userReflection,
  }) async {
    final service = WalkSessionService();
    await service.saveWalkSession(
      walkStateManager: walkStateManager,
      walkReflection: userReflection,
      weatherInfo: '맑음', // 임시값, 추후 실제 날씨 API 연동
      locationName: '서울', // 임시값, 추후 실제 위치명 조회
    );
  }
}