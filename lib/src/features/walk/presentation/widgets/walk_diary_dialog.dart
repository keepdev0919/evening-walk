import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../../../shared/providers/upload_provider.dart';
import '../../../../shared/services/toast_service.dart';

class WalkDiaryDialog {
  static Future<void> show({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required Function(bool) onWalkCompleted,
    bool isViewMode = false, // 읽기 전용 모드 플래그
  }) async {
    final TextEditingController reflectionController = TextEditingController(
      text: walkStateManager.userReflection ?? '',
    );
    final TextEditingController answerEditController = TextEditingController(
      text: walkStateManager.userAnswer ?? '',
    );
    String? currentPhotoPath = walkStateManager.photoPath;
    bool isEditingAnswer = false; // 편집 모드 상태
    bool isEditingReflection = false; // 편집 모드 상태

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.black.withValues(alpha: 0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white54, width: 1.5),
              ),
              title: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🎉 완료 축하 헤더
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withValues(alpha: 0.8),
                              Colors.teal.withValues(alpha: 0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '🎉',
                              style: TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '산책 완료!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '오늘의 추억을 일기로 남겨보세요',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 경유지 경험 섹션 (편집 가능)
                      if (walkStateManager.waypointQuestion != null)
                        _buildExperienceSection(
                          title: '🚩 경유지에서',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Q. ${walkStateManager.waypointQuestion}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: TextField(
                                  controller: answerEditController,
                                  readOnly: !isEditingAnswer,
                                  maxLines: 4,
                                  style: TextStyle(
                                    color: isEditingAnswer
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: isEditingAnswer
                                        ? '(답변을 입력하거나 수정하세요)'
                                        : null,
                                    hintStyle: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool isNarrow =
                                      constraints.maxWidth < 360;

                                  final Widget primaryButton =
                                      ElevatedButton.icon(
                                    icon: Icon(
                                      isEditingAnswer
                                          ? Icons.check
                                          : Icons.edit,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      isEditingAnswer ? '완료' : '편집',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    onPressed: () {
                                      if (isEditingAnswer) {
                                        // 완료 모드: 저장하고 편집 모드 종료
                                        FocusScope.of(context).unfocus();
                                        final updated =
                                            answerEditController.text.trim();
                                        walkStateManager.saveAnswerAndPhoto(
                                          answer:
                                              updated.isEmpty ? null : updated,
                                        );
                                        setState(() {
                                          isEditingAnswer = false;
                                        });
                                      } else {
                                        // 편집 모드: 편집 모드 시작 (읽기 모드가 아닐 때만)
                                        if (!isViewMode) {
                                          setState(() {
                                            isEditingAnswer = true;
                                          });
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.blue.withValues(alpha: 0.8),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 12),
                                      minimumSize: const Size(0, 44),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  );

                                  final Widget clearButton = TextButton.icon(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.white70),
                                    label: const Text('지우기',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                    onPressed: () {
                                      _showDeleteConfirmDialog(
                                        context: context,
                                        title: '경유지 답변 삭제',
                                        content: '경유지 답변을 삭제하시겠습니까?',
                                        onConfirm: () {
                                          answerEditController.clear();
                                          walkStateManager.saveAnswerAndPhoto(
                                              answer: null);
                                          setState(() {
                                            isEditingAnswer = true;
                                          });
                                        },
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 12),
                                      minimumSize: const Size(0, 44),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  );

                                  if (isNarrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                            width: double.infinity,
                                            child: primaryButton),
                                        if (isEditingAnswer) ...[
                                          const SizedBox(height: 8),
                                          clearButton,
                                        ],
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: primaryButton),
                                      if (isEditingAnswer) ...[
                                        const SizedBox(width: 8),
                                        clearButton,
                                      ],
                                    ],
                                  );
                                },
                              )
                            ],
                          ),
                        ),

                      if (walkStateManager.waypointQuestion != null)
                        const SizedBox(height: 16),

                      // 목적지 경험 섹션 (편집 가능)
                      _buildExperienceSection(
                        title: '📸 목적지에서',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '추천 포즈로 찍은 사진',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (currentPhotoPath != null)
                              GestureDetector(
                                onTap: () => _showFullScreenPhoto(
                                  context,
                                  currentPhotoPath!,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildImageWidget(currentPhotoPath!),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                height: 200,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Text(
                                  '사진이 없습니다. 추가해 보세요!',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            const SizedBox(height: 8),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool isNarrow =
                                    constraints.maxWidth < 360;

                                final Widget takeOrRetakeButton =
                                    ElevatedButton.icon(
                                  icon: const Icon(Icons.camera_alt,
                                      color: Colors.white),
                                  label: Text(
                                    currentPhotoPath == null
                                        ? '사진 추가'
                                        : '사진 다시 찍기',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onPressed: () async {
                                    final path =
                                        await walkStateManager.takePhoto();
                                    if (path != null) {
                                      walkStateManager.saveAnswerAndPhoto(
                                          photoPath: path);
                                      if (context.mounted) {
                                        setState(() {
                                          currentPhotoPath = path;
                                        });
                                      }
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('사진이 업데이트되었습니다.')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.blue.withValues(alpha: 0.8),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 12),
                                    minimumSize: const Size(0, 44),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                );

                                final Widget? deleteButton = currentPhotoPath !=
                                        null
                                    ? TextButton.icon(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.white70),
                                        label: const Text('사진 제거',
                                            style: TextStyle(
                                                color: Colors.white70)),
                                        onPressed: () {
                                          _showDeleteConfirmDialog(
                                            context: context,
                                            title: '사진 제거',
                                            content: '목적지 사진을 제거하시겠습니까?',
                                            onConfirm: () {
                                              walkStateManager
                                                  .saveAnswerAndPhoto(
                                                      photoPath: null);
                                              setState(() {
                                                currentPhotoPath = null;
                                              });
                                            },
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 12),
                                          minimumSize: const Size(0, 44),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      )
                                    : null;

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                          width: double.infinity,
                                          child: takeOrRetakeButton),
                                      if (deleteButton != null) ...[
                                        const SizedBox(height: 8),
                                        deleteButton,
                                      ]
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: takeOrRetakeButton),
                                    if (deleteButton != null) ...[
                                      const SizedBox(width: 8),
                                      deleteButton,
                                    ]
                                  ],
                                );
                              },
                            )
                          ],
                        ),
                      ),

                      if (walkStateManager.photoPath != null)
                        const SizedBox(height: 16),

                      // 소감 입력 섹션
                      _buildExperienceSection(
                        title: '💭 오늘의 소감',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '오늘 산책은 어떠셨나요?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: TextField(
                                controller: reflectionController,
                                readOnly: !isEditingReflection,
                                maxLines: 4,
                                style: TextStyle(
                                  color: isEditingReflection
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: isEditingReflection
                                      ? '예) 날씨가 좋아서 기분이 좋았어요. 다음에도 이런 산책을 하고 싶어요.'
                                      : null,
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                onChanged: (value) {
                                  // 실시간 업데이트는 컨트롤러에서 처리됨
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool isNarrow =
                                    constraints.maxWidth < 360;

                                final Widget applyButton = ElevatedButton.icon(
                                  icon: Icon(
                                    isEditingReflection
                                        ? Icons.check
                                        : Icons.edit,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    isEditingReflection ? '완료' : '편집',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onPressed: () {
                                    if (isEditingReflection) {
                                      // 완료 모드: 저장하고 편집 모드 종료
                                      FocusScope.of(context).unfocus();
                                      final updated =
                                          reflectionController.text.trim();
                                      walkStateManager.saveReflection(
                                          updated.isEmpty ? null : updated);
                                      setState(() {
                                        isEditingReflection = false;
                                      });
                                    } else {
                                      // 편집 모드: 편집 모드 시작 (읽기 모드가 아닐 때만)
                                      if (!isViewMode) {
                                        setState(() {
                                          isEditingReflection = true;
                                        });
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.blue.withValues(alpha: 0.8),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 12),
                                    minimumSize: const Size(0, 44),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                );

                                final Widget clearButton = TextButton.icon(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white70),
                                  label: const Text('지우기',
                                      style: TextStyle(color: Colors.white70)),
                                  onPressed: () {
                                    _showDeleteConfirmDialog(
                                      context: context,
                                      title: '소감 삭제',
                                      content: '오늘의 소감을 삭제하시겠습니까?',
                                      onConfirm: () {
                                        reflectionController.clear();
                                        walkStateManager.saveReflection(null);
                                        setState(() {
                                          isEditingReflection = true;
                                        });
                                      },
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 12),
                                    minimumSize: const Size(0, 44),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                          width: double.infinity,
                                          child: applyButton),
                                      if (isEditingReflection) ...[
                                        const SizedBox(height: 8),
                                        clearButton,
                                      ],
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: applyButton),
                                    if (isEditingReflection) ...[
                                      const SizedBox(width: 8),
                                      clearButton,
                                    ],
                                  ],
                                );
                              },
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 버튼 영역
                      if (isViewMode)
                        // 읽기 모드: 닫기 버튼만 표시
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text(
                              '닫기',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.grey.withValues(alpha: 0.8),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                            ),
                          ),
                        )
                      else
                        // 편집 모드: 저장 및 공유 버튼
                        Row(
                          children: [
                            // 저장하기 버튼
                            Expanded(
                              child: ElevatedButton.icon(
                                icon:
                                    const Icon(Icons.save, color: Colors.white),
                                label: const Text(
                                  '일기 저장',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () async {
                                  final uploadProvider =
                                      Provider.of<UploadProvider>(context,
                                          listen: false);

                                  try {
                                    // 1. 즉시 텍스트 데이터만 저장 (사진 제외)
                                    final walkSessionService =
                                        WalkSessionService();
                                    final sessionId = await walkSessionService
                                        .saveWalkSessionWithoutPhoto(
                                      walkStateManager: walkStateManager,
                                      walkReflection: reflectionController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : reflectionController.text.trim(),
                                      weatherInfo: '맑음',
                                      locationName: '서울',
                                    );

                                    if (sessionId != null) {
                                      // 2. 다이얼로그 닫고 홈으로 즉시 이동
                                      Navigator.of(dialogContext).pop();
                                      onWalkCompleted(true);

                                      // 홈으로 이동
                                      Navigator.of(context)
                                          .pushNamedAndRemoveUntil(
                                        '/',
                                        (route) => false,
                                      );

                                      // 3. 성공 토스트 메시지 표시
                                      ToastService.showSuccess('일기가 저장되었습니다!');

                                      // 4. 백그라운드에서 사진 업로드 시작 (사진이 있는 경우, await 제거)
                                      if (walkStateManager.photoPath != null) {
                                        // await를 제거하여 백그라운드에서 실행되도록 함
                                        uploadProvider.startBackgroundUpload(
                                          sessionId,
                                          walkStateManager.photoPath!,
                                        );
                                      }
                                    } else {
                                      ToastService.showError(
                                          '저장에 실패했습니다. 다시 시도해주세요.');
                                    }
                                  } catch (e) {
                                    ToastService.showError(
                                        '저장 중 오류가 발생했습니다: ${e.toString()}');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.blue.withValues(alpha: 0.8),
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color:
                                            Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // 공유하기 버튼 (나중에 구현)
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.share,
                                    color: Colors.white),
                                label: const Text(
                                  '공유하기',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  // TODO: 산책 일기 공유 기능 구현 예정
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('공유 기능은 곧 추가될 예정입니다!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.green.withValues(alpha: 0.8),
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: Colors.green
                                            .withValues(alpha: 0.3)),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  // 경험 섹션 빌더
  static Widget _buildExperienceSection({
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  // 삭제 확인 다이얼로그
  static Future<void> _showDeleteConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // 키보드 숨기기
                FocusScope.of(context).unfocus();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.8),
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  // 전체화면 사진 보기
  static void _showFullScreenPhoto(BuildContext context, String photoPath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildImageWidget(photoPath, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// URL인지 로컬 파일 경로인지 구분하여 적절한 이미지 위젯 반환
  static Widget _buildImageWidget(String imagePath, {BoxFit? fit}) {
    final isUrl =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');

    if (isUrl) {
      // Firebase Storage URL인 경우 - CachedNetworkImage 사용
      return CachedNetworkImage(
        imageUrl: imagePath,
        width: double.infinity,
        height: fit == null ? 200 : null,
        fit: fit ?? BoxFit.cover,
        placeholder: (context, url) => Container(
          width: double.infinity,
          height: fit == null ? 200 : null,
          color: Colors.grey.withValues(alpha: 0.1),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          print('캐시된 네트워크 이미지 로드 실패: $error');
          return Container(
            width: double.infinity,
            height: fit == null ? 200 : null,
            color: Colors.red.withValues(alpha: 0.1),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '사진을 불러올 수 없습니다',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // 로컬 파일 경로인 경우
      return Image.file(
        File(imagePath),
        width: double.infinity,
        height: fit == null ? 200 : null,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('로컬 이미지 로드 실패: $error');
          return Container(
            width: double.infinity,
            height: fit == null ? 200 : null,
            color: Colors.red.withValues(alpha: 0.1),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '로컬 사진을 찾을 수 없습니다',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}
