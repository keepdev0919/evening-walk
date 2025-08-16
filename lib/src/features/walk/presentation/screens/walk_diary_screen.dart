import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:walk/src/features/walk/domain/models/walk_session.dart';
import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/application/services/route_snapshot_service.dart';
import 'package:walk/src/features/walk/application/services/in_app_map_snapshot_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:walk/src/common/widgets/location_name_edit_dialog.dart';

import '../../../../common/providers/upload_provider.dart';
import '../../../../common/services/toast_service.dart';
import '../../../../core/services/log_service.dart';
import '../../application/services/photo_share_service.dart';
import '../../../../core/constants/app_constants.dart';

class WalkDiaryScreen extends StatefulWidget {
  final WalkStateManager walkStateManager;
  final Function(bool) onWalkCompleted;
  final bool isViewMode;
  final String? sessionId;
  final String? selectedMate;
  final String? returnRoute; // 저장 후 돌아갈 화면 지정

  const WalkDiaryScreen({
    Key? key,
    required this.walkStateManager,
    required this.onWalkCompleted,
    this.isViewMode = false,
    this.sessionId,
    this.selectedMate,
    this.returnRoute,
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
  // 추천 포즈는 산책일기에서 표시하지 않습니다
  int? _recordedDurationMin; // 세션에 저장된 총 소요 시간(분)

  // 공유 기능을 위한 RepaintBoundary Key
  final GlobalKey _shareKey = GlobalKey();
  String? _shareStartAddress;
  String? _shareDestAddress;
  String? _userPhotoPath; // 사용자 촬영 사진 경로

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
    _userPhotoPath = widget.walkStateManager.photoPath; // 초기 설정

    // 추천 포즈: 산책일기에서는 사용하지 않음

    // 경로 스냅샷이 없다면 진입 시 1회 생성 시도 (fallback)
    if (widget.walkStateManager.routeSnapshotPng == null) {
      _generateRouteSnapshotFallback();
    }

    // 세션 기록 거리 로드 (있다면 우선 표시)
    _loadRecordedDistanceIfAny();
  }

  // 개별 구현 제거: 공통 다이얼로그 사용

  String _mateEmoji(String mate) {
    switch (mate) {
      case '혼자':
        return '🌙';
      case '연인':
        return '💕';
      case '친구':
        return '👫';
      case '반려견':
        return '🐕';
      case '가족':
        return '👨‍👩‍👧‍👦';
      default:
        return '🚶';
    }
  }

  Future<void> _loadRecordedDistanceIfAny() async {
    if (widget.sessionId == null) return;
    try {
      final svc = WalkSessionService();
      final session = await svc.getWalkSession(widget.sessionId!);
      if (session != null) {
        setState(() {
          // 저장된 총시간이 없으면 카드와 동일하게 종료-시작 기반 계산값 사용
          _recordedDurationMin =
              session.totalDuration ?? session.durationInMinutes; // 분 단위
          // 저장된 사용자 지정 위치명 복원 (뒤로가기 후 재진입 시 유지)
          widget.walkStateManager
              .setDestinationBuildingName(session.locationName);
          widget.walkStateManager.setCustomStartName(session.customStartName);
          // 세션에 저장된 사진 경로를 초기 로드 (조회/재진입 시 반영)
          currentPhotoPath = session.takenPhotoPath;
          _userPhotoPath = session.takenPhotoPath; // 세션에서 사진 경로 로드
        });
      }
    } catch (_) {}
  }

  Future<void> _generateRouteSnapshotFallback() async {
    try {
      final start = widget.walkStateManager.startLocation;
      final waypoint = widget.walkStateManager.waypointLocation;
      final dest = widget.walkStateManager.destinationLocation;
      if (start == null || dest == null) return;
      // In-app 캡처 우선 시도
      Uint8List? png = await InAppMapSnapshotService.captureRouteSnapshot(
        context: context,
        start: start,
        waypoint: waypoint,
        destination: dest,
        width: 600,
        height: 400,
      );
      // 실패 시 Static Maps fallback
      png ??= await RouteSnapshotService.generateRouteSnapshot(
        start: start,
        waypoint: waypoint,
        destination: dest,
        width: 600,
        height: 400,
      );
      if (png != null) {
        widget.walkStateManager.saveRouteSnapshot(png);
        if (mounted) setState(() {});
      }
    } catch (_) {}
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
                      trailing: _buildMateChip(widget.selectedMate!),
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
                            child: answerEditController.text.trim().isEmpty &&
                                    !isEditingAnswer
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    child: const Text(
                                      '답변을 남기지 않았어요.',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        height: 1.4,
                                      ),
                                    ),
                                  )
                                : TextField(
                                    controller: answerEditController,
                                    readOnly: !isEditingAnswer,
                                    maxLines: 2,
                                    maxLength: 300,
                                    onTap: !isEditingAnswer
                                        ? () {
                                            if (answerEditController.text
                                                .trim()
                                                .isNotEmpty) {
                                              _showFullScreenText(
                                                '경유지 답변',
                                                answerEditController.text,
                                              );
                                            }
                                          }
                                        : null,
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
                            maxLines: 2,
                            maxLength: 300,
                            onTap: !isEditingReflection
                                ? () {
                                    if (reflectionController.text
                                        .trim()
                                        .isNotEmpty) {
                                      _showFullScreenText(
                                        '오늘의 소감',
                                        reflectionController.text,
                                      );
                                    }
                                  }
                                : null,
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
    Widget? trailing,
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
              const SizedBox(width: 8),
              if (trailing != null) trailing,
            ],
          ),
          // 출발지와 목적지 사이 간격 확대
          const SizedBox(height: 16),
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

  // 추천 포즈 위젯 제거

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
            widget.sessionId != null &&
            !hasRequestedPhotoRefreshAfterUpload) {
          hasRequestedPhotoRefreshAfterUpload = true;
          WalkSessionService()
              .getWalkSession(widget.sessionId!)
              .then((session) {
            if (session?.takenPhotoPath != null) {
              setState(() {
                currentPhotoPath = session!.takenPhotoPath;
                _userPhotoPath = session.takenPhotoPath; // 세션에서 사진 경로 로드
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
                    content: const Text('사진이 저장되었습니다. ✨'),
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
                      if (widget.sessionId != null) {
                        // Firestore에 즉시 반영
                        WalkSessionService().updateWalkSession(
                          widget.sessionId!,
                          {
                            'takenPhotoPath': null,
                            'updatedAt': DateTime.now().toIso8601String(),
                          },
                        );
                      }
                      setState(() {
                        currentPhotoPath = null;
                        _userPhotoPath = null; // 세션에서 사진 경로 제거
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
        // 공유하기 버튼
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
            onPressed: _onSharePressed,
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

        const SizedBox(width: 16),

        // 산책 저장 버튼
        Expanded(
          flex: 2,
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
                  // 기존 세션에 소감/경유지 답변 업데이트
                  final success = await walkSessionService.updateWalkSession(
                    widget.sessionId!,
                    {
                      'walkReflection': reflectionController.text.trim().isEmpty
                          ? null
                          : reflectionController.text.trim(),
                      'waypointAnswer': answerEditController.text.trim().isEmpty
                          ? null
                          : answerEditController.text.trim(),
                      // 사용자 지정 위치명도 함께 업데이트하여 히스토리에서 반영되도록 함
                      'locationName':
                          widget.walkStateManager.destinationBuildingName,
                      'customStartName':
                          widget.walkStateManager.customStartName,
                      'updatedAt': DateTime.now().toIso8601String(),
                    },
                  );

                  if (success) {
                    Navigator.of(context).pop();
                    widget.onWalkCompleted(true);

                    // 저장 성공 스낵바 표시
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '산책이 저장되었습니다 ✨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );

                    // 1초 후 홈화면으로 이동
                    Future.delayed(const Duration(seconds: 1), () {
                      if (widget.returnRoute != null) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          widget.returnRoute!,
                          (route) => false,
                        );
                      } else {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/homescreen',
                          (route) => false,
                        );
                      }
                    });
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
                    locationName:
                        widget.walkStateManager.destinationBuildingName,
                  );

                  if (sessionId != null) {
                    Navigator.of(context).pop();
                    widget.onWalkCompleted(true);

                    // 저장 성공 스낵바 표시
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '산책이 저장되었습니다 ✨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );

                    // 1초 후 홈화면으로 이동
                    Future.delayed(const Duration(seconds: 1), () {
                      if (widget.returnRoute != null) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          widget.returnRoute!,
                          (route) => false,
                        );
                      } else {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/homescreen',
                          (route) => false,
                        );
                      }
                    });

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
          // 제목(좌) + 시간 정보(우) - 공유 UI와 동일 배치
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🗺️', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 6),
                  Text(
                    '산책 경로',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              _buildDiaryTimeDistanceInfo(),
            ],
          ),
          const SizedBox(height: 16),
          // 좌: 출발지/목적지, 우: 지도 PNG (공유 UI와 동일 배치)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: widget.walkStateManager.getStartLocationAddress(),
                      builder: (context, snapshot) {
                        final bool isLoading =
                            snapshot.connectionState == ConnectionState.waiting;
                        final String address =
                            widget.walkStateManager.customStartName ??
                                (snapshot.data ?? '로딩 중...');
                        return _buildLocationInfo(
                          icon: Icons.home,
                          iconColor: Colors.blue,
                          label: '출발지',
                          address: address,
                          isLoading: isLoading,
                          onTap: isLoading
                              ? null
                              : () {
                                  final initial =
                                      widget.walkStateManager.customStartName ??
                                          (snapshot.data ?? '');
                                  showLocationNameEditDialog(
                                    context: context,
                                    title: '출발지 이름 수정',
                                    initialValue: initial,
                                    onSave: (value) {
                                      widget.walkStateManager
                                          .setCustomStartName(value);
                                      setState(() {});
                                    },
                                  );
                                },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: widget.walkStateManager
                          .getDestinationLocationAddress(),
                      builder: (context, snapshot) {
                        final bool isLoading =
                            snapshot.connectionState == ConnectionState.waiting;
                        final String address =
                            widget.walkStateManager.destinationBuildingName ??
                                (snapshot.data ?? '로딩 중...');
                        return _buildLocationInfo(
                          icon: Icons.flag,
                          iconColor: Colors.red,
                          label: '목적지',
                          address: address,
                          isLoading: isLoading,
                          onTap: isLoading
                              ? null
                              : () {
                                  final initial = widget.walkStateManager
                                          .destinationBuildingName ??
                                      (snapshot.data ?? '');
                                  showLocationNameEditDialog(
                                    context: context,
                                    title: '목적지 이름 수정',
                                    initialValue: initial,
                                    onSave: (value) {
                                      widget.walkStateManager
                                          .setDestinationBuildingName(value);
                                      setState(() {});
                                    },
                                  );
                                },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (widget.walkStateManager.routeSnapshotPng != null)
                GestureDetector(
                  onTap: () => _showFullScreenRouteSnapshot(
                      widget.walkStateManager.routeSnapshotPng!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      widget.walkStateManager.routeSnapshotPng!,
                      width: 180,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 180,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    '경로 이미지를 준비 중...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 산책 일기 헤더용 시간과 거리 정보 표시
  Widget _buildDiaryTimeDistanceInfo() {
    final duration =
        widget.walkStateManager.actualDurationInMinutes ?? _recordedDurationMin;
    final distance = widget.walkStateManager.accumulatedDistanceKm;

    if (duration == null) return const SizedBox.shrink();

    List<Widget> infoWidgets = [];

    // 시간 정보 추가
    final String durationText = duration <= 0 ? '1분 미만' : '${duration}분';
    infoWidgets.addAll([
      const Icon(Icons.access_time, color: Colors.white70, size: 16),
      const SizedBox(width: 4),
      Text(
        durationText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);

    // 거리 정보 추가 (시간과 거리 사이에 구분자 추가)
    if (distance != null) {
      infoWidgets.addAll([
        const SizedBox(width: 8),
        const Text('•', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(width: 8),
        const Icon(Icons.directions_walk, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          distance < 0.1 ? '0.1km 미만' : '${distance.toStringAsFixed(1)}km',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: infoWidgets,
    );
  }

  /// 전체 화면 경로 스냅샷 보기 (목적지 화면)
  void _showFullScreenRouteSnapshot(Uint8List pngBytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                panEnabled: true, // 이동 허용
                scaleEnabled: true, // 확대/축소 허용
                minScale: 0.5, // 최소 축소 비율
                maxScale: 4.0, // 최대 확대 비율
                child: Center(
                  child: Image.memory(
                    pngBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // 상단 컨트롤 바
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 안내 아이콘과 텍스트
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.touch_app,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '확대/축소 및 드래그하여 탐색하세요',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 닫기 버튼
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
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
  }

  /// 전체화면 텍스트 보기
  void _showFullScreenText(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white54),
                    const SizedBox(height: 20),
                    // 스크롤 가능한 텍스트 내용
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.6,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 닫기 버튼
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 위치 정보 위젯 (포즈 추천 화면과 동일)
  Widget _buildLocationInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // 산책일기 화면에서는 연필 아이콘을 표시하지 않습니다 (요청사항)
            ],
          ),
          const SizedBox(height: 6),
          isLoading
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    color: Colors.white.withValues(alpha: 0.7),
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  address,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );

    return onTap != null
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: content,
          )
        : content;
  }

  /// 공유하기 - 바로 공유 실행
  Future<void> _onSharePressed() async {
    // 공유 전에 현재 사진 경로를 _userPhotoPath에 설정
    _userPhotoPath = currentPhotoPath;

    // 공유 전에 경로 스냅샷이 없다면 한 번 생성 시도 (in-app 우선 → static maps)
    if (widget.walkStateManager.routeSnapshotPng == null &&
        widget.walkStateManager.startLocation != null &&
        widget.walkStateManager.destinationLocation != null) {
      try {
        Uint8List? png = await InAppMapSnapshotService.captureRouteSnapshot(
          context: context,
          start: widget.walkStateManager.startLocation!,
          waypoint: widget.walkStateManager.waypointLocation,
          destination: widget.walkStateManager.destinationLocation!,
          width: 900,
          height: 600,
        );
        png ??= await RouteSnapshotService.generateRouteSnapshot(
          start: widget.walkStateManager.startLocation!,
          waypoint: widget.walkStateManager.waypointLocation,
          destination: widget.walkStateManager.destinationLocation!,
          width: 900,
          height: 600,
        );
        if (png != null) {
          widget.walkStateManager.saveRouteSnapshot(png);
        }
      } catch (e) {
        LogService.warning('Share', '경로 스냅샷 생성 실패 (무시 가능)');
      }
    }

    // 주소를 먼저 미리 로드하여 캡처 시점에 반영되도록 함
    try {
      _shareStartAddress =
          await widget.walkStateManager.getStartLocationAddress();
      _shareDestAddress =
          await widget.walkStateManager.getDestinationLocationAddress();
    } catch (_) {}

    // 임시로 공유용 위젯을 오프스크린에 렌더링
    await _captureAndShareDirectly();
  }

  /// 직접 공유하기
  Future<void> _captureAndShareDirectly() async {
    try {
      // 로딩 다이얼로그 표시: 공유 준비 중
      _showBlockingLoadingDialog('공유 준비 중...');

      // 임시 RepaintBoundary를 사용하여 오프스크린 캡처
      final shareWidget = _buildShareContent();

      // 오버레이를 사용하여 화면 밖에서 위젯 렌더링
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -9999, // 화면 밖으로 이동
          top: -9999,
          child: Material(
            color: Colors.transparent,
            child: RepaintBoundary(
              key: _shareKey,
              child: shareWidget,
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      // 렌더링이 완료될 때까지 잠시 대기
      await Future.delayed(const Duration(milliseconds: 100));

      // 캡처 및 공유
      await PhotoShareService.captureAndShareWidget(
        repaintBoundaryKey: _shareKey,
        customMessage: '''
📸 저녁 산책!

오늘의 산책 기록을 공유합니다 😊

#저녁산책 #산책일기 #산책기록
        ''',
        pixelRatio: 3.0,
      );

      // 오버레이 제거
      overlayEntry.remove();
    } catch (e) {
      _showErrorSnackBar('공유 중 오류가 발생했습니다: $e ✨');
      LogService.error('WalkDiary', '공유 오류', e);
    } finally {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  /// 공유 준비/진행 동안 사용자 혼란을 막기 위한 블로킹 로딩 다이얼로그 표시
  void _showBlockingLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: Colors.black.withValues(alpha: 0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white54, width: 1),
            ),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 공유용 콘텐츠 빌드
  Widget _buildShareContent() {
    return Container(
      width: AppConstants.shareContentWidth,
      height: AppConstants.shareContentHeight, // 9:16 비율
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(AppConstants.backgroundImagePath),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // 은은한 워터마크 (#저녁산책 반복 텍스트), 터치 막음
          IgnorePointer(
            ignoring: true,
            child: Opacity(
              opacity: 0.13,
              child: CustomPaint(
                painter: _WatermarkPainter(text: '#저녁산책'),
                size: Size.infinite,
              ),
            ),
          ),
          // 상하 그라디언트 + 실제 컨텐츠
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: Column(
                  children: [
                    // 메인 콘텐츠
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // 산책 경로: 좌측 정보(a) + 우측 지도(동일 높이)
                            _buildShareRouteCombinedSection(),

                            const SizedBox(height: 16),

                            // 경유지 질문 (있을 때만)
                            if (widget.walkStateManager.waypointQuestion !=
                                null) ...[
                              _buildWaypointQuestionSection(),
                              const SizedBox(height: 16),
                            ],

                            // // 산책메이트 정보 (경유지 질문이 없어도 표시)
                            // if (widget.walkStateManager.selectedMate !=
                            //     null) ...[
                            //   _buildMateInfoSection(),
                            //   const SizedBox(height: 16),
                            // ],

                            // 사용자 촬영 사진
                            if (_userPhotoPath != null &&
                                File(_userPhotoPath!).existsSync())
                              _buildShareUserPhotoSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 공유용 경로 스냅샷 섹션 (목적지 화면): 산책일기 UI와 동일한 구성
  Widget _buildShareRouteCombinedSection() {
    final png = widget.walkStateManager.routeSnapshotPng;
    final preloadedStart = _shareStartAddress;
    final preloadedDest = _shareDestAddress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목(좌) + 시간/거리(우)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🗺️', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 6),
                  Text(
                    '산책 경로',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              _buildTimeDistanceInfo(),
            ],
          ),
          const SizedBox(height: 16),
          // 좌: 출발지/목적지, 우: 지도 PNG (일기 화면과 동일 배치)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preloadedStart != null)
                      _buildLocationInfo(
                        icon: Icons.home,
                        iconColor: Colors.blue,
                        label: '출발지',
                        address: preloadedStart,
                        isLoading: false,
                        onTap: () {
                          final initial =
                              widget.walkStateManager.customStartName ??
                                  preloadedStart;
                          showLocationNameEditDialog(
                            context: context,
                            title: '출발지 이름 수정',
                            initialValue: initial,
                            onSave: (newName) {
                              setState(() {
                                _shareStartAddress = newName;
                              });
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    if (preloadedDest != null)
                      _buildLocationInfo(
                        icon: Icons.flag,
                        iconColor: Colors.red,
                        label: '목적지',
                        address: preloadedDest,
                        isLoading: false,
                        onTap: () {
                          final initial = preloadedDest;
                          showLocationNameEditDialog(
                            context: context,
                            title: '목적지 이름 수정',
                            initialValue: initial,
                            onSave: (newName) {
                              setState(() {
                                _shareDestAddress = newName;
                              });
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 지도 스냅샷 (포즈추천 페이지와 동일한 크기)
              if (png != null)
                GestureDetector(
                  onTap: () => _showFullScreenRouteSnapshot(png),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      png,
                      width: 180,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 180,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    '경로 이미지를 준비 중...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 시간과 거리 정보 표시
  Widget _buildTimeDistanceInfo() {
    final duration = widget.walkStateManager.actualDurationInMinutes;
    final distance = widget.walkStateManager.accumulatedDistanceKm;

    // 시간과 거리 모두 없으면 빈 위젯
    if (duration == null || duration <= 0) {
      return const SizedBox.shrink();
    }

    List<Widget> infoWidgets = [];

    // 시간 정보 추가
    infoWidgets.addAll([
      const Icon(
        Icons.access_time,
        color: Colors.white70,
        size: 14,
      ),
      const SizedBox(width: 4),
      Text(
        '${duration}분',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ]);

    // 거리 정보 추가 (시간과 거리 사이에 구분자 추가)
    if (distance != null) {
      infoWidgets.addAll([
        const SizedBox(width: 8),
        const Text('•', style: TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(width: 8),
        const Icon(
          Icons.directions_walk,
          color: Colors.white70,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          distance < 0.1 ? '0.1km 미만' : '${distance.toStringAsFixed(1)}km',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: infoWidgets,
      ),
    );
  }

  /// 경유지 질문 섹션
  Widget _buildWaypointQuestionSection() {
    return Container(
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
              const Icon(Icons.card_giftcard, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              const Text(
                '경유지에서',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.selectedMate != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _mateEmoji(_normalizedMate(widget.selectedMate!)),
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _normalizedMate(widget.selectedMate!),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Q. ${widget.walkStateManager.waypointQuestion}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 기존 UI용 산책메이트 칩 (작은 크기)
  Widget _buildMateChip(String? selectedMate) {
    if (selectedMate == null) return const SizedBox.shrink();
    final String text = selectedMate.startsWith('친구') ? '친구' : selectedMate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_mateEmoji(text), style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _normalizedMate(String mate) {
    return mate.startsWith('친구') ? '친구' : mate;
  }

  /// 공유용 사용자 사진 섹션
  Widget _buildShareUserPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text(
                '목적지에서',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 사진 카드 (목적지 화면과 동일한 테두리/반경 재사용)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(_userPhotoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.black.withValues(alpha: 0.3),
                              child: const Center(
                                child: Text(
                                  '사진을 불러올 수 없습니다',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            );
                          },
                        ),
                        // 살짝 어둡게 보이도록 오버레이 (일관 유지)
                        IgnorePointer(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 공유 중 오류 발생 시 스낵바 표시
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// 반복 워터마크 페인터
class _WatermarkPainter extends CustomPainter {
  final String text;
  const _WatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    // Paint 인스턴스는 현재 필요하지 않습니다.
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const double stepX = 160;
    const double stepY = 80;
    const double angle = -0.35; // 라디안 단위 근사 (약 -20도)

    for (double y = -stepY; y < size.height + stepY; y += stepY) {
      for (double x = -stepX; x < size.width + stepX; x += stepX) {
        final span = TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        );
        textPainter.text = span;
        textPainter.layout();

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
