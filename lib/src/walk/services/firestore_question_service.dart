import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walk/src/core/services/log_service.dart';

/// Firestore에서 질문 데이터를 관리하는 서비스 클래스
/// 경유지 질문을 불러올 때마다 Firestore에서 직접 가져옴
class FirestoreQuestionService {
  static final FirestoreQuestionService _instance =
      FirestoreQuestionService._internal();
  factory FirestoreQuestionService() => _instance;
  FirestoreQuestionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'questions';

  // 게임 종류 리스트
  final List<String> _gameTypes = ['가위바위보', '제로게임'];

  /// 선택된 메이트에 맞는 무작위 질문을 반환
  /// Firestore에서 직접 질문을 가져옴
  Future<String?> getQuestionForMate(String? selectedMate,
      {String? friendGroupType,
      String? friendQuestionType,
      String? coupleQuestionType}) async {
    try {
      // 입력 검증
      if (selectedMate == null || selectedMate.trim().isEmpty) {
        LogService.warning('Firestore', '메이트가 선택되지 않음');
        return null;
      }

      // 메이트에 맞는 문서 이름 결정
      String docName = _getDocumentName(selectedMate, friendGroupType,
          friendQuestionType, coupleQuestionType);
      print('🔥 DEBUG FirestoreService: selectedMate=$selectedMate, coupleQuestionType=$coupleQuestionType, docName=$docName');

      // Firestore에서 직접 질문 가져오기
      final docSnapshot =
          await _firestore.collection(_collectionName).doc(docName).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final questions =
            List<String>.from(docSnapshot.data()!['questions'] ?? []);

        if (questions.isNotEmpty) {
          final random = Random();
          final selectedQuestion = questions[random.nextInt(questions.length)];

          // 게임 타입인 경우 게임 종류를 앞에 붙임
          if (friendQuestionType == 'game') {
            final randomGame = _gameTypes[random.nextInt(_gameTypes.length)];
            final result = '$randomGame 진사람이 $selectedQuestion';
            LogService.info('Firestore', '게임 질문 생성: $result');
            return result;
          }

          LogService.info(
              'Firestore', '$selectedMate 질문 생성: $selectedQuestion');
          return selectedQuestion;
        }
      }

      LogService.warning('Firestore', '"$selectedMate"에 대한 질문을 찾을 수 없음');
      return null;
    } catch (e) {
      LogService.error('Firestore', '질문 가져오기 실패', e);
      return null;
    }
  }

  /// 메이트와 옵션에 따라 Firestore 문서 이름을 결정
  String _getDocumentName(String selectedMate, String? friendGroupType,
      String? friendQuestionType, String? coupleQuestionType) {
    // 연인 질문 타입이 지정된 경우
    if (selectedMate == '연인' && coupleQuestionType != null) {
      if (coupleQuestionType == 'balance') {
        return 'couple_balance';
      } else if (coupleQuestionType == 'talk') {
        return 'couple_talk';
      }
      return 'couple_talk'; // 기본값
    }

    // 친구 질문 타입이 지정된 경우 (인원수 관계없이)
    if (selectedMate.startsWith('친구') && friendQuestionType != null) {
      if (friendQuestionType == 'game') {
        return 'friend_game';
      } else if (friendQuestionType == 'talk') {
        return 'friend_talk';
      }
      return 'friend_talk'; // 기본값
    }

    // 다른 메이트 타입들
    switch (selectedMate) {
      case '혼자':
        return 'alone';
      case '연인':
        return 'couple_talk'; // 기본값
      case '반려견':
        return 'dog';
      case '가족':
        return 'family';
      case '친구':
        return 'friend_talk'; // 기본값
      default:
        return 'alone';
    }
  }
}
