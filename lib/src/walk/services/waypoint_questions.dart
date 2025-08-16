import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:walk/src/core/services/log_service.dart';

/// 산책 메이트 유형에 따라 경유지 질문을 제공하는 역할을 담당하는 클래스.
class WaypointQuestionProvider {
  // 산책 메이트별 질문 목록 (로드 후 저장될 맵)
  final Map<String, List<String>> _loadedQuestions = {};
  // 친구 인원별 추가 세분화 질문 목록
  List<String> _friendTwoQuestions = [];
  List<String> _friendManyQuestions = [];
  // 친구 게임용 질문 목록
  List<String> _friendTwoGameQuestions = [];
  List<String> _friendManyGameQuestions = [];
  // 게임 종류 리스트
  final List<String> _gameTypes = ['가위바위보', '제로게임'];
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
      final String dogJson = await rootBundle.loadString(
          'lib/src/features/walk/application/data/walk_question/dog_questions.json');
      // 가족 질문 로드 추가
      final String familyJson = await rootBundle.loadString(
          'lib/src/features/walk/application/data/walk_question/family_questions.json');
      // 기본 친구 질문 파일(friend_questions.json)은 제거됨. 세분화 파일만 사용.
      // 세분화된 친구 질문 로드 (없어도 안전)
      String? friendTwoJson;
      String? friendManyJson;
      String? friendTwoGameJson;
      String? friendManyGameJson;
      try {
        friendTwoJson = await rootBundle.loadString(
            'lib/src/features/walk/application/data/walk_question/friend_questions_two_talk.json');
      } catch (_) {}
      try {
        friendManyJson = await rootBundle.loadString(
            'lib/src/features/walk/application/data/walk_question/friend_questions_many_talk.json');
      } catch (_) {}
      try {
        friendTwoGameJson = await rootBundle.loadString(
            'lib/src/features/walk/application/data/walk_question/friend_questions_two_game.json');
      } catch (_) {}
      try {
        friendManyGameJson = await rootBundle.loadString(
            'lib/src/features/walk/application/data/walk_question/friend_questions_many_game.json');
      } catch (_) {}

      _loadedQuestions['혼자'] = List<String>.from(json.decode(aloneJson));
      _loadedQuestions['연인'] = List<String>.from(json.decode(coupleJson));
      _loadedQuestions['반려견'] = List<String>.from(json.decode(dogJson));
      _loadedQuestions['가족'] = List<String>.from(json.decode(familyJson));
      // '친구' 기본 리스트는 비움. 실제 사용은 two/many 세분화 리스트로 대체
      _loadedQuestions['친구'] = [];
      if (friendTwoJson != null) {
        _friendTwoQuestions = List<String>.from(json.decode(friendTwoJson));
      }
      if (friendManyJson != null) {
        _friendManyQuestions = List<String>.from(json.decode(friendManyJson));
      }
      if (friendTwoGameJson != null) {
        _friendTwoGameQuestions = List<String>.from(json.decode(friendTwoGameJson));
      }
      if (friendManyGameJson != null) {
        _friendManyGameQuestions = List<String>.from(json.decode(friendManyGameJson));
      }
      _isLoaded = true;

      LogService.info('Walk', 'WaypointQuestionProvider: 질문 파일 로드 완료.');
    } catch (e) {
      LogService.error('Walk', 'WaypointQuestionProvider: 질문 파일 로드 실패', e);
    }
  }

  /// 선택된 메이트에 맞는 무작위 질문을 반환합니다.
  ///
  /// 질문이 아직 로드되지 않았다면 로드될 때까지 기다립니다.
  Future<String?> getQuestionForMate(String? selectedMate,
      {String? friendGroupType, String? friendQuestionType}) async {
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
      LogService.warning(
          'Walk', 'WaypointQuestionProvider: 질문이 로드되지 않아 질문을 반환할 수 없습니다.');
      return null;
    }

    // 친구 인원 타입이 지정된 경우 우선 사용
    if (selectedMate.startsWith('친구') && friendGroupType != null) {
      // 디버깅 로그 추가
      LogService.info('Walk',
          '친구 질문 생성 - friendGroupType: $friendGroupType, friendQuestionType: $friendQuestionType');

      // 게임을 선택한 경우와 토크를 선택한 경우에 따라 다른 리스트 사용
      List<String> list;
      if (friendQuestionType == 'game') {
        list = friendGroupType == 'two' ? _friendTwoGameQuestions : _friendManyGameQuestions;
        if (list.isNotEmpty) {
          final Random r = Random();
          final randomGame = _gameTypes[r.nextInt(_gameTypes.length)];
          final randomQuestion = list[r.nextInt(list.length)];
          final result = '$randomGame 진사람이 $randomQuestion';
          LogService.info('Walk', '게임 질문 생성: $result');
          return result;
        }
      } else {
        // talk를 선택한 경우 기존 토크 리스트 사용
        list = friendGroupType == 'two' ? _friendTwoQuestions : _friendManyQuestions;
        if (list.isNotEmpty) {
          final Random r = Random();
          final result = list[r.nextInt(list.length)];
          LogService.info('Walk', '토크 질문 생성: $result');
          return result;
        }
      }
      // 세분화 파일이 아직 없거나 비어있을 때는 도착 다이얼로그만 띄우기 위해 빈 문자열 반환
      return '';
    }

    // 친구 기본 리스트는 사용하지 않음. 도착 다이얼로그만 필요하므로 빈 문자열 반환
    if (selectedMate.startsWith('친구')) {
      return '';
    }

    final List<String>? mateQuestions = _loadedQuestions[selectedMate];
    if (mateQuestions != null && mateQuestions.isNotEmpty) {
      final Random random = Random();
      return mateQuestions[random.nextInt(mateQuestions.length)];
    }
    return null;
  }
}
