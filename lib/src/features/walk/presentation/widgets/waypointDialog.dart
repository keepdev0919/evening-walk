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
      message: '경유지 이벤트를 확인해봐요!',
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
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 600,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 콘텐츠 크기에 맞춤
              children: <Widget>[
                // 제목
                Column(
                  children: [
                    const Text(
                      '경유지 질문',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 질문 텍스트
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // 답변 입력 필드
                TextField(
                  controller: answerController,
                  decoration: InputDecoration(
                    hintText: '우측 상단 경유지 버튼으로 내용을 수정할 수 있어요!',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.orange.withValues(alpha: 0.8),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 20),

                // 답변 완료 버튼
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      updateWaypointEventState(
                          true, question, answerController.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withValues(alpha: 0.9),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.orange.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: Colors.orange.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '답변 완료',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
          title: Column(
            children: [
              const Text(
                '질문 종류 선택',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: const Text(
              '원하는 질문 종류를 선택해주세요.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.4,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          actions: [
            Column(
              children: [
                // 밸런스게임 버튼
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(_QuestionType.balanceGame),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.9),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.blue.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: Colors.blue.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.balance,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '밸런스게임',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 커플 질문 버튼
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(_QuestionType.coupleQ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink.withValues(alpha: 0.9),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.pink.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: Colors.pink.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '커플 질문',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
          title: Column(
            children: [
              const Text(
                '질문 종류 선택',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: const Text(
              '원하는 질문 종류를 선택해주세요.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.4,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          actions: [
            Column(
              children: [
                // 게임 버튼
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(_FriendQuestionType.game),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.9),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.green.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: Colors.green.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sports_esports,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '게임',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Talk 버튼
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop(_FriendQuestionType.talk),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.withValues(alpha: 0.9),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.purple.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: Colors.purple.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Talk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
