import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'common_arrival_dialog.dart';
import '../services/walk_state_manager.dart';
import '../services/firestore_question_service.dart';
import '../../core/services/analytics_service.dart';

class WaypointDialogs {
  static Future<void> showWaypointArrivalDialog({
    required BuildContext context,
    required String questionPayload,
    required String? selectedMate,
    required Function(bool, String?, String?, [bool]) updateWaypointEventState,
    WalkStateManager? walkStateManager,
    bool isFromWaypointButton = false,
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
            String questionType = 'talk';
            if (selection == _QuestionType.balanceGame) {
              questionType = 'balance';
              print('🔥 DEBUG: 밸런스게임 선택됨, questionType = $questionType');
            } else {
              print('🔥 DEBUG: 커플질문 선택됨, questionType = $questionType');
            }

            // WalkStateManager에 연인 질문 타입 설정 및 새로운 질문 가져오기
            String finalQuestion = "기본 연인 질문";

            if (walkStateManager != null) {
              walkStateManager.setCoupleQuestionType(questionType);
              print(
                  '🔥 DEBUG: WalkStateManager에 coupleQuestionType 설정: $questionType');
            }

            // FirestoreQuestionService에 직접 질문 요청
            final questionService = FirestoreQuestionService();
            print(
                '🔥 DEBUG: 직접 호출 전 - selectedMate=$selectedMate, questionType=$questionType');
            final newQuestion = await questionService.getQuestionForMate(
              selectedMate,
              coupleQuestionType: questionType,
            );
            print('🔥 DEBUG: Firestore에서 가져온 새 질문: $newQuestion');
            finalQuestion = newQuestion ?? "기본 연인 질문";
            print('🔥 DEBUG: 최종 질문: $finalQuestion');

            updateWaypointEventState(true, finalQuestion, null, false);
            if (context.mounted) {
              WaypointDialogs.showQuestionDialog(
                context,
                finalQuestion,
                updateWaypointEventState,
                null,
                selectedMate: selectedMate,
                walkStateManager: walkStateManager,
                preservedCoupleQuestionType: questionType,
                hideReloadButton: isFromWaypointButton,
              );
            }
          });
        } else if (selectedMate != null && selectedMate.startsWith('친구')) {
          _showFriendQuestionTypeSelector(context).then((selection) async {
            String questionType = 'talk';
            if (selection != null) {
              final bool isGame = selection == _FriendQuestionType.game;
              questionType = isGame ? 'game' : 'talk';

              // WalkStateManager에 친구 질문 타입 설정 및 새로운 질문 가져오기
              String finalQuestion = "기본 친구 질문";

              if (walkStateManager != null) {
                walkStateManager.setFriendQuestionType(questionType);
                print('🔥 DEBUG: 친구 questionType 설정: $questionType');
              }

              // FirestoreQuestionService에 직접 질문 요청
              final questionService = FirestoreQuestionService();
              print(
                  '🔥 DEBUG: 친구 직접 호출 - selectedMate=$selectedMate, friendQuestionType=$questionType');
              final newQuestion = await questionService.getQuestionForMate(
                selectedMate,
                friendQuestionType: questionType,
              );
              print('🔥 DEBUG: 친구 Firestore 질문: $newQuestion');
              finalQuestion = newQuestion ?? "기본 친구 질문";
              print('🔥 DEBUG: 친구 최종 질문: $finalQuestion');

              updateWaypointEventState(true, finalQuestion, null, false);
              if (context.mounted) {
                WaypointDialogs.showQuestionDialog(
                  context,
                  finalQuestion,
                  updateWaypointEventState,
                  null,
                  selectedMate: selectedMate,
                  walkStateManager: walkStateManager,
                  preservedFriendQuestionType: questionType,
                  hideReloadButton: isFromWaypointButton,
                );
              }
            }
          });
        } else {
          // 기본 플로우 (혼자, 반려견, 가족 등)
          final question =
              questionPayload.isNotEmpty ? questionPayload : "경유지에 도착했습니다!";
          updateWaypointEventState(true, question, null);
          WaypointDialogs.showQuestionDialog(
              context, question, updateWaypointEventState, null,
              selectedMate: selectedMate, walkStateManager: walkStateManager,
              hideReloadButton: isFromWaypointButton);
        }
      },
      onLater: () {
        updateWaypointEventState(true, questionPayload, null, false);
      },
      barrierDismissible: false,
    );
  }

  static void showQuestionDialog(
    BuildContext context,
    String question,
    Function(bool, String?, String?, [bool]) updateWaypointEventState,
    String? initialAnswer, {
    String? selectedMate,
    WalkStateManager? walkStateManager,
    bool isReloadAlreadyUsed = false,
    String? preservedCoupleQuestionType,
    String? preservedFriendQuestionType,
    bool hideReloadButton = false,
  }) {
    final TextEditingController answerController =
        TextEditingController(text: initialAnswer);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // 재로드 상태 관리 - StatefulBuilder 외부에서 상태 변수 선언
        bool isReloading = false;
        int reloadCount = isReloadAlreadyUsed ? 0 : 1;
        bool isReloadUsed = isReloadAlreadyUsed;
        
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {

            return Dialog(
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // 제목과 재로드 아이콘
                      Row(
                        children: [
                          // 왼쪽 공간 (재로드 아이콘과 동일한 크기로 균형 맞춤)
                          Container(
                            width: 80,
                            height: 40,
                          ),
                          // 중앙에 제목 배치
                          Expanded(
                            child: Text(
                              '경유지 질문',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // 우측에 재로드 아이콘과 횟수 표시 (동적 테마) - hideReloadButton이 true면 숨김
                          hideReloadButton ? Container(width: 80, height: 40) : Container(
                            decoration: BoxDecoration(
                              color: (isReloading || isReloadUsed)
                                  ? Colors.grey.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isReloading || isReloadUsed)
                                    ? Colors.grey.withValues(alpha: 0.4)
                                    : Colors.orange.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: (isReloading || isReloadUsed)
                                    ? null
                                    : () async {
                                        print('🔥 DEBUG: 리로드 버튼 클릭됨');
                                        print('🔥 DEBUG: 현재 질문: $question');
                                        print(
                                            '🔥 DEBUG: selectedMate: $selectedMate');

                                        // 재로드 상태로 변경
                                        setState(() {
                                          isReloading = true;
                                          reloadCount = 0;
                                          isReloadUsed = true;
                                        });
                                        print(
                                            '🔥 DEBUG: 재로드 상태로 변경됨: isReloading=$isReloading, reloadCount=$reloadCount');

                                        // 새로운 질문 가져오기
                                        print('🔥 DEBUG: 리로드 조건 체크 - selectedMate: $selectedMate, walkStateManager: $walkStateManager');
                                        if (selectedMate != null) {
                                          print('🔥 DEBUG: 새로운 질문 가져오기 시작');
                                          String newQuestion = question;

                                          try {
                                            final questionService =
                                                FirestoreQuestionService();

                                            // 최대 5번까지 시도하여 다른 질문 찾기
                                            for (int attempt = 0; attempt < 5; attempt++) {
                                              String? candidateQuestion;
                                              
                                              if (selectedMate == '연인') {
                                                final questionType = preservedCoupleQuestionType ?? 
                                                    (walkStateManager != null
                                                        ? (walkStateManager.coupleQuestionType ?? 'talk')
                                                        : 'talk');
                                                print('🔥 DEBUG: 연인 질문 타입 (preserved: $preservedCoupleQuestionType, walkState: ${walkStateManager?.coupleQuestionType}): $questionType');
                                                candidateQuestion = await questionService
                                                    .getQuestionForMate(
                                                  selectedMate,
                                                  coupleQuestionType:
                                                      questionType,
                                                );
                                              } else if (selectedMate
                                                  .startsWith('친구')) {
                                                final questionType = preservedFriendQuestionType ?? 
                                                    (walkStateManager != null
                                                        ? (walkStateManager.friendQuestionType ?? 'talk')
                                                        : 'talk');
                                                candidateQuestion = await questionService
                                                    .getQuestionForMate(
                                                  selectedMate,
                                                  friendQuestionType:
                                                      questionType,
                                                );
                                              } else {
                                                // 혼자, 반려견, 가족 등
                                                candidateQuestion = await questionService
                                                    .getQuestionForMate(
                                                        selectedMate);
                                              }

                                              // 다른 질문을 찾았으면 사용
                                              if (candidateQuestion != null && candidateQuestion != question) {
                                                newQuestion = candidateQuestion;
                                                print('🔥 DEBUG: 새로운 질문 찾음 (시도 ${attempt + 1}): $newQuestion');
                                                break;
                                              }
                                              
                                              print('🔥 DEBUG: 시도 ${attempt + 1}: 같은 질문 또는 null');
                                            }

                                            // 새로운 질문으로 다이얼로그 업데이트
                                            print(
                                                '🔥 DEBUG: 새 질문으로 다이얼로그 업데이트: $newQuestion');
                                            Navigator.of(dialogContext).pop();
                                            WaypointDialogs
                                                .showQuestionDialog(
                                              context,
                                              newQuestion,
                                              updateWaypointEventState,
                                              answerController.text
                                                      .trim()
                                                      .isNotEmpty
                                                  ? answerController.text
                                                      .trim()
                                                  : null,
                                              selectedMate: selectedMate,
                                              walkStateManager:
                                                  walkStateManager,
                                              isReloadAlreadyUsed: true,
                                              preservedCoupleQuestionType: preservedCoupleQuestionType ?? 
                                                  (walkStateManager?.coupleQuestionType),
                                              preservedFriendQuestionType: preservedFriendQuestionType ?? 
                                                  (walkStateManager?.friendQuestionType),
                                              hideReloadButton: hideReloadButton,
                                            );
                                          } catch (e) {
                                            print('🔥 DEBUG: 질문 로드 에러: $e');
                                            // 에러 발생 시 상태 복원
                                            setState(() {
                                              isReloading = false;
                                              reloadCount = 1;
                                              isReloadUsed = false;
                                            });

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '새로운 질문을 가져오는데 실패했습니다.'),
                                                backgroundColor: Colors.red
                                                    .withValues(alpha: 0.8),
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        } else {
                                          print('🔥 DEBUG: selectedMate가 null이어서 질문 로드 불가');
                                          // 질문 로드를 시도하지 않음 - selectedMate가 null
                                          setState(() {
                                            isReloading = false;
                                            reloadCount = 1;
                                            isReloadUsed = false;
                                          });
                                          
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('메이트 정보가 없어서 새로운 질문을 가져올 수 없습니다.'),
                                              backgroundColor: Colors.red
                                                  .withValues(alpha: 0.8),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh_rounded,
                                        color: (isReloading || isReloadUsed)
                                            ? Colors.grey.withValues(alpha: 0.8)
                                            : Colors.orange
                                                .withValues(alpha: 0.8),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isReloading || isReloadUsed)
                                              ? Colors.grey
                                                  .withValues(alpha: 0.8)
                                              : Colors.orange
                                                  .withValues(alpha: 0.8),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$reloadCount',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      const SizedBox(height: 20),

                      // 질문 텍스트
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                        maxLength: 300,
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
                          onPressed: () async {
                            final answer = answerController.text.trim();
                            print('🔥 DEBUG: 답변 완료 버튼 클릭됨');
                            print('🔥 DEBUG: answer = "$answer"');
                            print(
                                '🔥 DEBUG: answer.isEmpty = ${answer.isEmpty}');

                            Navigator.of(dialogContext).pop();
                            // 답변 완료 시에는 항상 스낵바를 표시 (showSnackbar = true)
                            print(
                                '🔥 DEBUG: updateWaypointEventState 호출: show=true, question="$question", answer="$answer", showSnackbar=true');
                            updateWaypointEventState(
                                true, question, answer, true);

                            // Firebase Analytics 질문 답변 이벤트 기록
                            if (selectedMate != null && answer.isNotEmpty) {
                              String questionType = 'general';
                              if (selectedMate == '연인') {
                                questionType =
                                    walkStateManager?.coupleQuestionType ??
                                        'talk';
                              } else if (selectedMate.startsWith('친구')) {
                                questionType =
                                    walkStateManager?.friendQuestionType ??
                                        'talk';
                              }

                              await AnalyticsService().logQuestionAnswered(
                                mateType: selectedMate,
                                questionType: questionType,
                                answerLength: answer.length,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.orange.withValues(alpha: 0.9),
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
              ),
            );
          },
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
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
        );
      },
    );
  }
}

enum _QuestionType { balanceGame, coupleQ }

enum _FriendQuestionType { game, talk }
