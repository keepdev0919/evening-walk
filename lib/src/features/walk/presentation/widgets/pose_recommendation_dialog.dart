import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/application/services/pose_image_service.dart';
import 'package:walk/src/features/walk/application/services/photo_share_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class PoseRecommendationDialog {
  static Future<bool?> show({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required String selectedMate,
    String? initialPoseImageUrl,
    String? initialTakenPhotoPath,
    required Function(String) onPoseImageGenerated,
    required Function(String?) onPhotoTaken,
  }) async {
    final String? initialRandomImagePath = initialPoseImageUrl ??
        await PoseImageService.fetchRandomImageUrl(selectedMate);
    if (initialRandomImagePath != null && initialPoseImageUrl == null) {
      onPoseImageGenerated(initialRandomImagePath);
    }

    String? _takenPhotoPath = initialTakenPhotoPath;
    bool _isLoadingImage = initialPoseImageUrl == null;
    String? _currentDisplayedImageUrl = initialPoseImageUrl;
    final GlobalKey _repaintBoundaryKey = GlobalKey();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            if (_isLoadingImage && _currentDisplayedImageUrl == null) {
              PoseImageService.fetchRandomImageUrl(selectedMate)
                  .then((imageUrl) {
                if (imageUrl != null) {
                  onPoseImageGenerated(imageUrl);
                  if (context.mounted) {
                    setState(() {
                      _currentDisplayedImageUrl = imageUrl;
                      _isLoadingImage = false;
                    });
                  }
                } else {
                  if (context.mounted) {
                    setState(() {
                      _isLoadingImage = false;
                    });
                  }
                }
              });
            }
            return AlertDialog(
              backgroundColor: Colors.black.withValues(alpha: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white54, width: 1),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: _takenPhotoPath != null
                    ? MediaQuery.of(context).size.height * 0.8
                    : MediaQuery.of(context).size.height * 0.63,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: Container(
                          width: 360,
                          constraints: BoxConstraints(
                            minHeight: _takenPhotoPath != null ? 640 : 320,
                            maxHeight: _takenPhotoPath != null ? 640 : 360,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.9),
                                Colors.grey.shade900.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: EdgeInsets.only(
                            left: 20.0,
                            right: 20.0,
                            top: _takenPhotoPath != null ? 25.0 : 15.0,
                            bottom: _takenPhotoPath != null ? 10.0 : 8.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: _takenPhotoPath != null
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  '📸 추천 포즈',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _takenPhotoPath != null ? 15 : 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(
                                  height: _takenPhotoPath != null ? 15 : 10),
                              if (_isLoadingImage)
                                Container(
                                  width: 280,
                                  height: 210,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white),
                                  ),
                                )
                              else if (_currentDisplayedImageUrl != null)
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double maxW = constraints.maxWidth;
                                    final double targetW =
                                        maxW.clamp(220.0, 320.0);
                                    final double targetH =
                                        (targetW / 4 * 3).clamp(180.0, 240.0);
                                    return Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                _currentDisplayedImageUrl!,
                                            width: targetW,
                                            height: targetH,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              width: targetW,
                                              height: targetH,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.2)),
                                              ),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.white),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              width: targetW,
                                              height: targetH,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.2)),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.error,
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                )
                              else
                                Container(
                                  width: 280,
                                  height: 210,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2)),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '추천 이미지를 찾을 수 없습니다.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              if (_takenPhotoPath != null) ...[
                                const SizedBox(height: 15),
                                Container(
                                  width: 120,
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => Dialog(
                                        backgroundColor: Colors.black,
                                        insetPadding: EdgeInsets.zero,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Image.file(
                                                File(_takenPhotoPath!),
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            Positioned(
                                              top: 40,
                                              right: 20,
                                              child: IconButton(
                                                icon: const Icon(Icons.close,
                                                    color: Colors.white,
                                                    size: 30),
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.3),
                                          width: 1.5),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(
                                        File(_takenPhotoPath!),
                                        width: 280,
                                        height: 210,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.15)),
                                  ),
                                  child: const Text(
                                    '#저녁산책 #포즈추천',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _takenPhotoPath == null
                          ? Center(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt,
                                    color: Colors.white),
                                label: const Text('사진 찍기',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                onPressed: () async {
                                  final photoPath =
                                      await walkStateManager.takePhoto();
                                  if (photoPath != null) {
                                    if (context.mounted) {
                                      setState(() {
                                        _takenPhotoPath = photoPath;
                                      });
                                    }
                                    walkStateManager.saveAnswerAndPhoto(
                                      answer: walkStateManager.userAnswer,
                                      photoPath: photoPath,
                                    );
                                    onPhotoTaken(photoPath);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.blue.withValues(alpha: 0.8),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color:
                                            Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.camera_alt,
                                      color: Colors.white),
                                  label: const Text('다시 찍기',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                  onPressed: () async {
                                    final photoPath =
                                        await walkStateManager.takePhoto();
                                    if (photoPath != null) {
                                      if (context.mounted) {
                                        setState(() {
                                          _takenPhotoPath = photoPath;
                                        });
                                      }
                                      walkStateManager.saveAnswerAndPhoto(
                                        answer: walkStateManager.userAnswer,
                                        photoPath: photoPath,
                                      );
                                      onPhotoTaken(photoPath);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.blue.withValues(alpha: 0.8),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: Colors.blue
                                              .withValues(alpha: 0.3)),
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.share,
                                      color: Colors.white),
                                  label: const Text('공유하기',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                  onPressed: () async {
                                    try {
                                      await PhotoShareService
                                          .captureAndShareWidget(
                                        repaintBoundaryKey: _repaintBoundaryKey,
                                        customMessage: '''
📸 저녁 산책 포즈 추천!

추천받은 포즈와 제가 찍은 사진입니다 😊

#저녁산책 #포즈추천 #산책일기
                                        '''
                                            .trim(),
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('공유 중 오류가 발생했습니다: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.green.withValues(alpha: 0.8),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: Colors.green
                                              .withValues(alpha: 0.3)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: _takenPhotoPath != null ? double.infinity : 130,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2)),
                            ),
                          ),
                          child: const Text(
                            '완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
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
}
