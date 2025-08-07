import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

/// 산책 메이트 유형에 따라 경유지 질문을 제공하는 역할을 담당하는 클래스.
class WaypointQuestionProvider {
  // 산책 메이트별 질문 목록 (로드 후 저장될 맵)
  final Map<String, List<String>> _loadedQuestions = {};
  bool _isLoaded = false;

  /// WaypointQuestionProvider가 생성될 때 질문 로드를 시작합니다.
  WaypointQuestionProvider() {
    _loadQuestions();
  }

  /// JSON 파일에서 질문을 비동기적으로 로드합니다.
  Future<void> _loadQuestions() async {
    try {
      // 각 JSON 파일의 경로
      final String aloneJson = await rootBundle.loadString(
          'lib/src/features/walk/application/data/walk_question/alone_questions.json');
      final String coupleJson = await rootBundle.loadString(
          'lib/src/features/walk/application/data/walk_question/couple_questions.json');
      final String friendJson = await rootBundle.loadString(
          'lib/src/features/walk/application/data/walk_question/friend_questions.json');

      _loadedQuestions['혼자'] = List<String>.from(json.decode(aloneJson));
      _loadedQuestions['연인'] = List<String>.from(json.decode(coupleJson));
      _loadedQuestions['친구'] = List<String>.from(json.decode(friendJson));
      _isLoaded = true;

      print('WaypointQuestionProvider: 질문 파일 로드 완료.');
    } catch (e) {
      print('WaypointQuestionProvider: 질문 파일 로드 실패: $e');
    }
  }

  /// 선택된 메이트에 맞는 무작위 질문을 반환합니다.
  ///
  /// 질문이 아직 로드되지 않았다면 로드될 때까지 기다립니다.
  Future<String?> getQuestionForMate(String? selectedMate) async {
    if (selectedMate == null) {
      return null;
    }

    // 질문이 로드될 때까지 최대 2초 대기 (안전장치)
    int attempts = 0;
    while (!_isLoaded && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!_isLoaded) {
      print('WaypointQuestionProvider: 질문이 로드되지 않아 질문을 반환할 수 없습니다.');
      return null;
    }

    final List<String>? mateQuestions = _loadedQuestions[selectedMate];
    if (mateQuestions != null && mateQuestions.isNotEmpty) {
      final Random random = Random();
      return mateQuestions[random.nextInt(mateQuestions.length)];
    }
    return null;
  }
}
