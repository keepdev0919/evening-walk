import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:walk/src/features/walk/application/services/pose_image_service.dart';
import 'dart:io';

import '../../../../shared/providers/upload_provider.dart';
import '../../../../shared/services/toast_service.dart';

class WalkDiaryScreen extends StatefulWidget {
  final WalkStateManager walkStateManager;
  final Function(bool) onWalkCompleted;
  final bool isViewMode;
  final String? sessionId;
  final String? selectedMate;

  const WalkDiaryScreen({
    Key? key,
    required this.walkStateManager,
    required this.onWalkCompleted,
    this.isViewMode = false,
    this.sessionId,
    this.selectedMate,
  }) : super(key: key);

  @override
  State<WalkDiaryScreen> createState() => _WalkDiaryScreenState();
}

class _WalkDiaryScreenState extends State<WalkDiaryScreen> {
  late TextEditingController reflectionController;
  late TextEditingController answerEditController;
  String? currentPhotoPath;
  String? tempPhotoPath; // 임시 사진 경로 (편집 중)
  bool isEditingAnswer = false;
  bool isEditingReflection = false;
  bool isEditingPhoto = false; // 사진 편집 모드
  bool hasRequestedPhotoRefreshAfterUpload = false;
  Future<String?>? recommendedPoseFuture;

  @override
  void initState() {
    super.initState();
    reflectionController = TextEditingController(
      text: widget.walkStateManager.userReflection ?? '',
    );
    answerEditController = TextEditingController(
      text: widget.walkStateManager.userAnswer ?? '',
    );

    // 사진 경로 설정
    currentPhotoPath = widget.walkStateManager.photoPath;

    // 추천 포즈 이미지 설정
    recommendedPoseFuture = widget.walkStateManager.poseImageUrl != null
        ? Future.value(widget.walkStateManager.poseImageUrl)
        : (widget.selectedMate != null
            ? PoseImageService.fetchRandomImageUrl(widget.selectedMate!)
            : null);
  }

  @override
  void dispose() {
    reflectionController.dispose();
    answerEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          '산책 일기',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nature_walk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 어두운 오버레이 (가독성을 위해)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          // 메인 콘텐츠
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // 위치 정보 헤더
                  _buildLocationInfoHeader(),

                  const SizedBox(height: 20),

                  // 경유지 경험 섹션 (편집 가능)
                  if (widget.walkStateManager.waypointQuestion != null)
                    _buildExperienceSection(
                      title: '경유지에서',
                      leading: const Icon(
                        Icons.card_giftcard,
                        color: Colors.orange,
                        size: 18,
                      ),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q. ${widget.walkStateManager.waypointQuestion}',
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
                          _buildAnswerEditButtons(),
                        ],
                      ),
                    ),

                  if (widget.walkStateManager.waypointQuestion != null)
                    const SizedBox(height: 16),

                  // 목적지 경험 섹션 (편집 가능)
                  _buildExperienceSection(
                    title: '목적지에서',
                    leading: const Icon(
                      Icons.flag,
                      color: Colors.red,
                      size: 18,
                    ),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 추천 포즈
                        if (recommendedPoseFuture != null) ...[
                          const Text(
                            '📸 추천 포즈',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRecommendedPoseWidget(),
                          const SizedBox(height: 16),
                        ],

                        // 내가 찍은 사진 섹션
                        const Text(
                          '내가 찍은 사진',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPhotoSection(),
                        const SizedBox(height: 8),
                        _buildPhotoEditButtons(),
                      ],
                    ),
                  ),

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
                              hintText:
                                  '예) 날씨가 좋아서 기분이 좋았어요. 다음에도 이런 산책을 하고 싶어요.',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildReflectionEditButtons(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 버튼 영역
                  if (widget.isViewMode)
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
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.8),
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
                    _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceSection({
    required String title,
    Widget? leading,
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
          Row(
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildAnswerEditButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 360;

        final Widget primaryButton = ElevatedButton.icon(
          icon: Icon(
            isEditingAnswer ? Icons.check : Icons.edit,
            color: Colors.white,
          ),
          label: Text(
            isEditingAnswer ? '완료' : '편집',
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: () {
            if (isEditingAnswer) {
              FocusScope.of(context).unfocus();
              final updated = answerEditController.text.trim();
              widget.walkStateManager.saveAnswerAndPhoto(
                answer: updated.isEmpty ? null : updated,
              );
              setState(() {
                isEditingAnswer = false;
              });
            } else {
              if (!widget.isViewMode) {
                setState(() {
                  isEditingAnswer = true;
                });
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            minimumSize: const Size(0, 44),
            visualDensity: VisualDensity.compact,
          ),
        );

        final Widget clearButton = TextButton.icon(
          icon: const Icon(Icons.clear, color: Colors.white70),
          label: const Text('지우기', style: TextStyle(color: Colors.white70)),
          onPressed: () {
            _showDeleteConfirmDialog(
              context: context,
              title: '경유지 답변 삭제',
              content: '경유지 답변을 삭제하시겠습니까?',
              onConfirm: () {
                answerEditController.clear();
                widget.walkStateManager.saveAnswerAndPhoto(clearAnswer: true);
                setState(() {
                  isEditingAnswer = true;
                });
              },
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            minimumSize: const Size(0, 44),
            visualDensity: VisualDensity.compact,
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: primaryButton),
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
    );
  }

  Widget _buildRecommendedPoseWidget() {
    return FutureBuilder<String?>(
      future: recommendedPoseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: const CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildImageWidget(snapshot.data!),
          );
        }
        return Container(
          width: double.infinity,
          height: 180,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: const Text(
            '추천 포즈 이미지를 불러올 수 없습니다',
            style: TextStyle(color: Colors.white70),
          ),
        );
      },
    );
  }

  Widget _buildPhotoSection() {
    return Consumer<UploadProvider>(
      builder: (context, uploadProvider, _) {
        final uploadState = widget.sessionId != null
            ? uploadProvider.getUploadState(widget.sessionId!)
            : null;
        final isUploading =
            uploadState?.isUploading == true && (currentPhotoPath == null);

        if (isUploading) {
          final progress = (uploadState?.progress ?? 0.0);
          return Container(
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  '사진 업로드 중... ${(progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        if (uploadState?.isCompleted == true &&
            currentPhotoPath == null &&
            widget.sessionId != null &&
            !hasRequestedPhotoRefreshAfterUpload) {
          hasRequestedPhotoRefreshAfterUpload = true;
          WalkSessionService()
              .getWalkSession(widget.sessionId!)
              .then((session) {
            if (session?.takenPhotoPath != null) {
              setState(() {
                currentPhotoPath = session!.takenPhotoPath;
              });
            }
          });
        }

        // 편집 중이면 임시 사진, 아니면 현재 사진 표시
        final displayPhotoPath =
            isEditingPhoto ? tempPhotoPath : currentPhotoPath;

        if (displayPhotoPath != null) {
          return GestureDetector(
            onTap: () => _showFullScreenPhoto(context, displayPhotoPath),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEditingPhoto
                      ? Colors.orange.withValues(alpha: 0.6) // 편집 중일 때는 주황색 테두리
                      : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImageWidget(displayPhotoPath),
                  ),
                  // 편집 중일 때 오버레이 표시
                  if (isEditingPhoto)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '편집 중',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        return Container(
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
        );
      },
    );
  }

  Widget _buildPhotoEditButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 360;

        final Widget primaryButton = ElevatedButton.icon(
          icon: Icon(
            isEditingPhoto ? Icons.check : Icons.camera_alt,
            color: Colors.white,
          ),
          label: Text(
            isEditingPhoto
                ? '사진 저장'
                : (currentPhotoPath == null ? '사진 추가' : '사진 편집'),
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: () async {
            if (isEditingPhoto) {
              // 저장 완료
              if (tempPhotoPath != null) {
                widget.walkStateManager
                    .saveAnswerAndPhoto(photoPath: tempPhotoPath);
                setState(() {
                  currentPhotoPath = tempPhotoPath;
                  tempPhotoPath = null;
                  isEditingPhoto = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('사진이 저장되었습니다.'),
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                );
              }
            } else {
              // 편집 모드 시작 또는 사진 촬영
              if (!widget.isViewMode) {
                final path = await widget.walkStateManager.takePhoto();
                if (path != null) {
                  setState(() {
                    tempPhotoPath = path;
                    isEditingPhoto = true;
                  });
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            minimumSize: const Size(0, 44),
            visualDensity: VisualDensity.compact,
          ),
        );

        final Widget? cancelButton = isEditingPhoto
            ? TextButton.icon(
                icon: const Icon(Icons.cancel, color: Colors.white70),
                label:
                    const Text('취소', style: TextStyle(color: Colors.white70)),
                onPressed: () {
                  setState(() {
                    tempPhotoPath = null;
                    isEditingPhoto = false;
                  });
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  minimumSize: const Size(0, 44),
                  visualDensity: VisualDensity.compact,
                ),
              )
            : null;

        final Widget? deleteButton = currentPhotoPath != null && !isEditingPhoto
            ? TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.white70),
                label: const Text('사진 제거',
                    style: TextStyle(color: Colors.white70)),
                onPressed: () {
                  _showDeleteConfirmDialog(
                    context: context,
                    title: '사진 제거',
                    content: '목적지 사진을 제거하시겠습니까?',
                    onConfirm: () {
                      widget.walkStateManager
                          .saveAnswerAndPhoto(clearPhoto: true);
                      setState(() {
                        currentPhotoPath = null;
                      });
                    },
                  );
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  minimumSize: const Size(0, 44),
                  visualDensity: VisualDensity.compact,
                ),
              )
            : null;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: primaryButton),
              if (cancelButton != null) ...[
                const SizedBox(height: 8),
                cancelButton,
              ],
              if (deleteButton != null) ...[
                const SizedBox(height: 8),
                deleteButton,
              ]
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primaryButton),
            if (cancelButton != null) ...[
              const SizedBox(width: 8),
              cancelButton,
            ],
            if (deleteButton != null) ...[
              const SizedBox(width: 8),
              deleteButton,
            ]
          ],
        );
      },
    );
  }

  Widget _buildReflectionEditButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 360;

        final Widget applyButton = ElevatedButton.icon(
          icon: Icon(
            isEditingReflection ? Icons.check : Icons.edit,
            color: Colors.white,
          ),
          label: Text(
            isEditingReflection ? '완료' : '편집',
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: () {
            if (isEditingReflection) {
              FocusScope.of(context).unfocus();
              final updated = reflectionController.text.trim();
              widget.walkStateManager
                  .saveReflection(updated.isEmpty ? null : updated);
              setState(() {
                isEditingReflection = false;
              });
            } else {
              if (!widget.isViewMode) {
                setState(() {
                  isEditingReflection = true;
                });
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            minimumSize: const Size(0, 44),
            visualDensity: VisualDensity.compact,
          ),
        );

        final Widget clearButton = TextButton.icon(
          icon: const Icon(Icons.clear, color: Colors.white70),
          label: const Text('지우기', style: TextStyle(color: Colors.white70)),
          onPressed: () {
            _showDeleteConfirmDialog(
              context: context,
              title: '소감 삭제',
              content: '오늘의 소감을 삭제하시겠습니까?',
              onConfirm: () {
                reflectionController.clear();
                widget.walkStateManager.saveReflection(null);
                setState(() {
                  isEditingReflection = true;
                });
              },
            );
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            minimumSize: const Size(0, 44),
            visualDensity: VisualDensity.compact,
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: applyButton),
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // 저장하기 버튼
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              '산책 저장',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () async {
              try {
                final walkSessionService = WalkSessionService();

                // 기존 저장된 세션이 있으면 소감만 업데이트, 없으면 새로 저장
                if (widget.sessionId != null) {
                  // 기존 세션에 소감 업데이트
                  final success = await walkSessionService.updateWalkSession(
                    widget.sessionId!,
                    {
                      'walkReflection': reflectionController.text.trim().isEmpty
                          ? null
                          : reflectionController.text.trim(),
                      'updatedAt': DateTime.now().toIso8601String(),
                    },
                  );

                  if (success) {
                    Navigator.of(context).pop();
                    widget.onWalkCompleted(true);

                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    );

                    ToastService.showSuccess('산책 일기가 업데이트되었습니다!');
                  } else {
                    ToastService.showError('업데이트에 실패했습니다. 다시 시도해주세요.');
                  }
                } else {
                  // 세션 ID가 없으면 새로 저장 (기존 로직 유지 - 산책 기록 목록에서 접근한 경우)
                  final uploadProvider =
                      Provider.of<UploadProvider>(context, listen: false);

                  final sessionId =
                      await walkSessionService.saveWalkSessionWithoutPhoto(
                    walkStateManager: widget.walkStateManager,
                    walkReflection: reflectionController.text.trim().isEmpty
                        ? null
                        : reflectionController.text.trim(),
                    weatherInfo: '맑음',
                    locationName:
                        widget.walkStateManager.destinationBuildingName,
                  );

                  if (sessionId != null) {
                    Navigator.of(context).pop();
                    widget.onWalkCompleted(true);

                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    );

                    ToastService.showSuccess('일기가 저장되었습니다!');

                    if (widget.walkStateManager.photoPath != null) {
                      uploadProvider.startBackgroundUpload(
                        sessionId,
                        widget.walkStateManager.photoPath!,
                      );
                    }
                  } else {
                    ToastService.showError('저장에 실패했습니다. 다시 시도해주세요.');
                  }
                }
              } catch (e) {
                ToastService.showError('저장 중 오류가 발생했습니다: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withValues(alpha: 0.8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 공유하기 버튼 (나중에 구현)
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text(
              '공유하기',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('공유 기능은 곧 추가될 예정입니다!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.withValues(alpha: 0.8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget(String imagePath, {BoxFit? fit}) {
    final isUrl =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');

    if (isUrl) {
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
      return Image.file(
        File(imagePath),
        width: double.infinity,
        height: fit == null ? 200 : null,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
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

  void _showFullScreenPhoto(BuildContext context, String photoPath) {
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

  Future<void> _showDeleteConfirmDialog({
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

  Widget _buildLocationInfoHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              '🗺️ 산책 경로',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 출발지 정보
          FutureBuilder<String>(
            future: widget.walkStateManager.getStartLocationAddress(),
            builder: (context, snapshot) {
              return _buildLocationRow(
                leading: const Icon(
                  Icons.home,
                  color: Colors.blue,
                  size: 22,
                ),
                label: '출발지',
                address: snapshot.data ?? '로딩 중...',
                isLoading: snapshot.connectionState == ConnectionState.waiting,
              );
            },
          ),

          const SizedBox(height: 12),

          // 경유지 정보 (경유지가 있는 경우만)
          FutureBuilder<String?>(
            future: widget.walkStateManager.getWaypointLocationAddress(),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                return Column(
                  children: [
                    _buildLocationRow(
                      leading: const Icon(
                        Icons.card_giftcard,
                        color: Colors.orange,
                        size: 22,
                      ),
                      label: '경유지',
                      address: snapshot.data!,
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // 목적지 정보
          FutureBuilder<String>(
            future: widget.walkStateManager.getDestinationLocationAddress(),
            builder: (context, snapshot) {
              return _buildLocationRow(
                leading: const Icon(
                  Icons.flag,
                  color: Colors.red,
                  size: 22,
                ),
                label: '목적지',
                address: snapshot.data ?? '로딩 중...',
                isLoading: snapshot.connectionState == ConnectionState.waiting,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required Widget leading,
    required String label,
    required String address,
    required bool isLoading,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              isLoading
                  ? Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            color: Colors.white.withValues(alpha: 0.7),
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '주소를 불러오는 중...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      address,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
