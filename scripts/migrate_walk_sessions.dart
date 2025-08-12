import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 기존 walk_sessions 컬렉션의 데이터를 users/{userId}/walk_sessions 서브컬렉션으로 이전하는 스크립트
/// 
/// 사용법:
/// 1. 프로젝트 루트에서 실행: dart run scripts/migrate_walk_sessions.dart
/// 2. 프롬프트 확인 후 'yes' 입력
/// 3. 마이그레이션 완료 후 기존 walk_sessions 컬렉션 수동 삭제

void main() async {
  print('🚀 산책 세션 데이터 마이그레이션 시작...');
  print('');
  print('⚠️  주의: 이 작업은 Firebase 데이터를 변경합니다.');
  print('   백업을 완료했는지 확인하세요!');
  print('');
  print('계속 진행하시겠습니까? (yes/no): ');
  
  final input = stdin.readLineSync();
  if (input?.toLowerCase() != 'yes') {
    print('❌ 마이그레이션이 취소되었습니다.');
    return;
  }
  
  try {
    // .env 파일 로드
    await dotenv.load(fileName: 'assets/config/.env');
    
    // Firebase 초기화
    await Firebase.initializeApp();
    final firestore = FirebaseFirestore.instance;
    
    print('📊 기존 walk_sessions 컬렉션에서 데이터 조회 중...');
    
    // 기존 walk_sessions 컬렉션의 모든 문서 가져오기
    final oldCollectionSnapshot = await firestore
        .collection('walk_sessions')
        .get();
    
    final totalDocs = oldCollectionSnapshot.docs.length;
    print('📄 총 ${totalDocs}개의 산책 세션을 발견했습니다.');
    
    if (totalDocs == 0) {
      print('✅ 마이그레이션할 데이터가 없습니다.');
      return;
    }
    
    int successCount = 0;
    int errorCount = 0;
    
    // 사용자별 세션 그룹화
    Map<String, List<QueryDocumentSnapshot>> userSessions = {};
    
    for (final doc in oldCollectionSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId']?.toString();
      
      if (userId == null || userId.isEmpty) {
        print('⚠️  userId가 없는 문서 발견: ${doc.id}');
        errorCount++;
        continue;
      }
      
      if (!userSessions.containsKey(userId)) {
        userSessions[userId] = [];
      }
      userSessions[userId]!.add(doc);
    }
    
    print('👥 ${userSessions.length}명의 사용자 데이터를 처리합니다...');
    
    // 사용자별 데이터 마이그레이션
    for (final entry in userSessions.entries) {
      final userId = entry.key;
      final sessions = entry.value;
      
      print('📝 사용자 $userId의 ${sessions.length}개 세션 마이그레이션 중...');
      
      // Batch 사용으로 성능 최적화
      WriteBatch batch = firestore.batch();
      int batchCount = 0;
      
      for (final session in sessions) {
        try {
          final sessionId = session.id;
          final sessionData = session.data() as Map<String, dynamic>;
          
          // userId 필드는 서브컬렉션에서 불필요하므로 제거
          sessionData.remove('userId');
          
          // 새로운 서브컬렉션 경로에 데이터 추가
          final newDocRef = firestore
              .collection('users')
              .doc(userId)
              .collection('walk_sessions')
              .doc(sessionId);
          
          batch.set(newDocRef, sessionData);
          batchCount++;
          
          // Firestore Batch 제한 (500개)을 고려하여 분할 실행
          if (batchCount >= 500) {
            await batch.commit();
            print('  📦 배치 ${batchCount}개 커밋 완료');
            batch = firestore.batch();
            batchCount = 0;
          }
          
        } catch (e) {
          print('❌ 세션 ${session.id} 마이그레이션 실패: $e');
          errorCount++;
        }
      }
      
      // 남은 배치 커밋
      if (batchCount > 0) {
        await batch.commit();
        print('  📦 마지막 배치 ${batchCount}개 커밋 완료');
      }
      
      successCount += sessions.length;
      print('✅ 사용자 $userId 마이그레이션 완료 (${sessions.length}개 세션)');
    }
    
    print('');
    print('🎉 마이그레이션 완료!');
    print('✅ 성공: ${successCount}개');
    print('❌ 실패: ${errorCount}개');
    print('📊 총 처리: ${successCount + errorCount}개');
    
    if (errorCount == 0) {
      print('');
      print('⚠️  다음 단계:');
      print('1. 앱에서 새로운 구조가 정상 작동하는지 확인');
      print('2. Firebase Console에서 기존 walk_sessions 컬렉션 수동 삭제');
      print('3. Firebase 보안 규칙 업데이트');
    }
    
  } catch (e) {
    print('💥 마이그레이션 중 오류 발생: $e');
  }
}

/// 마이그레이션 검증 함수 (선택사항)
Future<void> validateMigration() async {
  final firestore = FirebaseFirestore.instance;
  
  print('🔍 마이그레이션 검증 중...');
  
  // 기존 컬렉션 문서 수
  final oldSnapshot = await firestore.collection('walk_sessions').get();
  final oldCount = oldSnapshot.docs.length;
  
  // 새로운 서브컬렉션 문서 수 계산
  final usersSnapshot = await firestore.collection('users').get();
  int newCount = 0;
  
  for (final userDoc in usersSnapshot.docs) {
    final sessionsSnapshot = await firestore
        .collection('users')
        .doc(userDoc.id)
        .collection('walk_sessions')
        .get();
    newCount += sessionsSnapshot.docs.length;
  }
  
  print('📊 검증 결과:');
  print('   기존 컬렉션: ${oldCount}개');
  print('   새 서브컬렉션: ${newCount}개');
  
  if (oldCount == newCount) {
    print('✅ 마이그레이션이 성공적으로 완료되었습니다!');
  } else {
    print('⚠️  문서 수가 일치하지 않습니다. 확인이 필요합니다.');
  }
}