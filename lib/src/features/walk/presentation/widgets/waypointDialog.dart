import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'common_arrival_dialog.dart';

class WaypointDialogs {
  static Future<void> showWaypointArrivalDialog({
    required BuildContext context,
    required String questionPayload,
    required String? selectedMate,
    required Function(bool, String?, String?) updateWaypointEventState,
  }) async {
    return CommonArrivalDialog.show<void>(
      context: context,
      title: '경유지 도착!',
      icon: Icons.card_giftcard,
      iconColor: Colors.orange,
      message: '경유지 이벤트를 확인하시겠어요?',
      onEventConfirm: () {
        // 연인 모드: 질문 종류 선택 다이얼로그 표시
        if (selectedMate == '연인') {
          _showQuestionTypeSelector(context).then((selection) async {
            String finalQuestion = questionPayload;
            if (selection == _QuestionType.balanceGame) {
              final String? balanceQ = await _loadCoupleBalanceQuestion();
              if (balanceQ != null && balanceQ.trim().isNotEmpty) {
                finalQuestion = balanceQ.trim();
              }
            }
            updateWaypointEventState(true, finalQuestion, null);
            if (context.mounted) {
              WaypointDialogs.showQuestionDialog(
                context,
                finalQuestion,
                updateWaypointEventState,
                null,
              );
            }
          });
        } else if (selectedMate != null && selectedMate.startsWith('친구')) {
          _showFriendQuestionTypeSelector(context).then((selection) async {
            String finalQuestion = questionPayload;
            if (selection != null) {
              final bool isTwo = selectedMate.contains('2명');
              final bool isGame = selection == _FriendQuestionType.game;
              final String? friendQ = await _loadFriendQuestion(
                isTwo: isTwo,
                isGame: isGame,
              );
              if (friendQ != null && friendQ.trim().isNotEmpty) {
                finalQuestion = friendQ.trim();
              }
            }
            updateWaypointEventState(true, finalQuestion, null);
            if (context.mounted) {
              WaypointDialogs.showQuestionDialog(
                context,
                finalQuestion,
                updateWaypointEventState,
                null,
              );
            }
          });
        } else {
          // 기본 플로우
          updateWaypointEventState(true, questionPayload, null);
          WaypointDialogs.showQuestionDialog(
              context, questionPayload, updateWaypointEventState, null);
        }
      },
      onLater: () {
        updateWaypointEventState(true, questionPayload, null);
      },
      barrierDismissible: false,
    );
  }

  static void showQuestionDialog(
    BuildContext context,
    String question,
    Function(bool, String?, String?) updateWaypointEventState,
    String? initialAnswer,
  ) {
    final TextEditingController answerController =
        TextEditingController(text: initialAnswer);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  question,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: answerController,
                  decoration: const InputDecoration(
                    hintText: '우측 상단 경유지 버튼으로 내용을 수정할수 있어요!',
                    hintStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                updateWaypointEventState(true, question, answerController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 질문 타입 선택용 다이얼로그
  static Future<_QuestionType?> _showQuestionTypeSelector(
      BuildContext context) async {
    return showDialog<_QuestionType>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          title: const Text(
            '질문 종류 선택',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '원하는 질문 종류를 선택해주세요.',
            style: TextStyle(color: Colors.white70),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(_QuestionType.balanceGame),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                minimumSize: const Size(0, 44),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('1. 밸런스게임'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(_QuestionType.coupleQ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                minimumSize: const Size(0, 44),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('2. 커플 질문'),
            )
          ],
        );
      },
    );
  }

  // 커플 밸런스 게임 질문 로더
  static Future<String?> _loadCoupleBalanceQuestion() async {
    try {
      final String jsonStr = await rootBundle.loadString(
          'lib/src/features/walk/application/data/walk_question/couple_balance.json');
      final List<dynamic> parsed = json.decode(jsonStr);
      final List<String> questions = parsed.cast<String>();
      if (questions.isEmpty) return null;
      final rnd = Random();
      return questions[rnd.nextInt(questions.length)];
    } catch (_) {
      // 파일이 없거나 파싱 실패 시 null 반환
      return null;
    }
  }

  // 친구: 질문 타입 선택 다이얼로그 (게임/토크)
  static Future<_FriendQuestionType?> _showFriendQuestionTypeSelector(
      BuildContext context) async {
    return showDialog<_FriendQuestionType>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          title: const Text(
            '질문 종류 선택',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '원하는 질문 종류를 선택해주세요.',
            style: TextStyle(color: Colors.white70),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(_FriendQuestionType.game),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                minimumSize: const Size(0, 44),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('게임'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(_FriendQuestionType.talk),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                minimumSize: const Size(0, 44),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Talk'),
            )
          ],
        );
      },
    );
  }

  // 친구 질문 로더: 2명/여러명 + 게임/토크 조합
  static Future<String?> _loadFriendQuestion({
    required bool isTwo,
    required bool isGame,
  }) async {
    try {
      final String path = isTwo
          ? (isGame
              ? 'lib/src/features/walk/application/data/walk_question/friend_questions_two_game.json'
              : 'lib/src/features/walk/application/data/walk_question/friend_questions_two_talk.json')
          : (isGame
              ? 'lib/src/features/walk/application/data/walk_question/friend_questions_many_game.json'
              : 'lib/src/features/walk/application/data/walk_question/friend_questions_many_talk.json');
      final String jsonStr = await rootBundle.loadString(path);
      final List<dynamic> parsed = json.decode(jsonStr);
      final List<String> questions = parsed.cast<String>();
      if (questions.isEmpty) return null;
      final rnd = Random();
      return questions[rnd.nextInt(questions.length)];
    } catch (_) {
      return null;
    }
  }
}

enum _QuestionType { balanceGame, coupleQ }

enum _FriendQuestionType { game, talk }
