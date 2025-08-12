import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 테스트용 마이그레이션: 첫 3개 문서만 이전해보기
void main() async {
  print('🧪 테스트 마이그레이션 시작...');
  
  try {
    // .env 파일 로드
    await dotenv.load(fileName: 'assets/config/.env');
    
    // Firebase 초기화
    await Firebase.initializeApp();
    final firestore = FirebaseFirestore.instance;
    
    print('📊 기존 walk_sessions 컬렉션에서 처음 3개 문서 조회...');
    
    // 처음 3개만 가져오기
    final snapshot = await firestore
        .collection('walk_sessions')
        .limit(3)
        .get();
    
    print('📄 ${snapshot.docs.length}개의 테스트 문서를 발견했습니다.');
    
    if (snapshot.docs.isEmpty) {
      print('✅ 마이그레이션할 데이터가 없습니다.');
      return;
    }
    
    print('');
    print('📋 테스트 문서들:');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['userId'];
      final startTime = data['startTime'];
      print('  - 문서 ID: ${doc.id}');
      print('    사용자 ID: $userId');
      print('    시작시간: $startTime');
      print('');
    }
    
    print('이 문서들을 새로운 구조로 복사하시겠습니까? (yes/no): ');
    final input = stdin.readLineSync();
    if (input?.toLowerCase() != 'yes') {
      print('❌ 테스트가 취소되었습니다.');
      return;
    }
    
    // 테스트 마이그레이션 실행
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = data['userId']?.toString();
      
      if (userId == null) {
        print('⚠️  userId가 없는 문서 건너뜀: ${doc.id}');
        continue;
      }
      
      // userId 필드 제거
      final newData = Map<String, dynamic>.from(data);
      newData.remove('userId');
      
      // 새로운 위치에 문서 생성
      await firestore
          .collection('users')
          .doc(userId)
          .collection('walk_sessions')
          .doc(doc.id)
          .set(newData);
      
      print('✅ 문서 ${doc.id} 마이그레이션 완료');
    }
    
    print('');
    print('🎉 테스트 마이그레이션 완료!');
    print('');
    print('🔍 Firebase Console에서 다음을 확인하세요:');
    print('  users/[사용자ID]/walk_sessions/[세션ID]');
    print('');
    print('⚠️  테스트가 성공하면 전체 마이그레이션을 실행하세요:');
    print('  dart run scripts/migrate_walk_sessions.dart');
    
  } catch (e) {
    print('💥 테스트 중 오류 발생: $e');
  }
}