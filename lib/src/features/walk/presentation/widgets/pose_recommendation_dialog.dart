import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/application/services/pose_image_service.dart';
import 'package:walk/src/features/walk/application/services/photo_share_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class PoseRecommendationDialog {
  static Future<void> show({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required String selectedMate,
    required Function(bool) updateDestinationEventState,
    String? initialPoseImageUrl,
    String? initialTakenPhotoPath,
    required Function(String) onPoseImageGenerated,
    required Function(String?) onPhotoTaken,
  }) async {
    // 다이얼로그가 처음 열릴 때만 랜덤 이미지 URL을 가져옵니다.
    final String? initialRandomImagePath = initialPoseImageUrl ??
        await PoseImageService.fetchRandomImageUrl(selectedMate);
    if (initialRandomImagePath != null && initialPoseImageUrl == null) {
      onPoseImageGenerated(initialRandomImagePath);
    }

    String? _takenPhotoPath = initialTakenPhotoPath; // 찍은 사진 경로를 저장할 변수
    bool _isLoadingImage = initialPoseImageUrl == null; // 초기 로딩 상태 설정
    String? _currentDisplayedImageUrl = initialPoseImageUrl; // 현재 표시될 이미지 URL
    final GlobalKey _repaintBoundaryKey = GlobalKey(); // RepaintBoundary를 위한 키

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // 이미지가 로드되지 않았고, 이전에 로딩 중이 아니었다면 이미지 로딩 시작
            if (_isLoadingImage && _currentDisplayedImageUrl == null) {
              PoseImageService.fetchRandomImageUrl(selectedMate)
                  .then((imageUrl) {
                if (imageUrl != null) {
                  onPoseImageGenerated(imageUrl);
                  setState(() {
                    _currentDisplayedImageUrl = imageUrl;
                    _isLoadingImage = false;
                  });
                } else {
                  setState(() {
                    _isLoadingImage = false;
                  });
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
                    ? MediaQuery.of(context).size.height * 0.8 // 사진 찍은 후엔 기존 높이
                    : MediaQuery.of(context).size.height *
                        0.63, // 사진 찍기 전엔 더 작게
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // RepaintBoundary로 공유할 영역을 감싸기
                      RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: Container(
                          width: 360,
                          constraints: BoxConstraints(
                            minHeight: _takenPhotoPath != null ? 640 : 320,
                            maxHeight: _takenPhotoPath != null ? 640 : 360,
                          ), // 사진 찍기 전엔 더 컴팩트한 제약
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
                          ), // 인스타 스타일 배경
                          padding: EdgeInsets.only(
                            left: 20.0,
                            right: 20.0,
                            top: _takenPhotoPath != null
                                ? 25.0
                                : 15.0, // 사진 찍기 전엔 위쪽 더 줄임
                            bottom: _takenPhotoPath != null
                                ? 10.0
                                : 8.0, // 사진 찍기 전엔 아래쪽도 줄임
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: _takenPhotoPath != null
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center, // 사진 찍기 전엔 가운데 정렬
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
                                    fontSize: _takenPhotoPath != null
                                        ? 15
                                        : 14, // 사진 찍기 전엔 폰트 크기도 줄임
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(
                                  height: _takenPhotoPath != null
                                      ? 15
                                      : 10), // 사진 찍기 전엔 간격 줄임
                              // 추천 포즈 이미지
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
                                ) // 로딩 중일 때 표시
                              else if (_currentDisplayedImageUrl != null)
                                Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedNetworkImage(
                                        imageUrl: _currentDisplayedImageUrl!,
                                        width: 280,
                                        height: 210,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          width: 280,
                                          height: 210,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.2)),
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                                color: Colors.white),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          width: 280,
                                          height: 210,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.2)),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.error,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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

                              // 찍은 사진이 있으면 표시
                              if (_takenPhotoPath != null) ...[
                                const SizedBox(height: 15),
                                Container(
                                  //포즈추천, 찍은사진 경계선
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
                                    // 전체화면 사진 보기 - 간단한 다이얼로그로 대체
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
                      // 사진이 찍히지 않았을 때는 사진 찍기 버튼만 중앙에 표시
                      // 사진이 찍힌 후에는 사진 찍기와 공유 버튼을 나란히 표시
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
                                    setState(() {
                                      _takenPhotoPath = photoPath;
                                    });
                                    walkStateManager.saveAnswerAndPhoto(
                                      answer: '',
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
                                      setState(() {
                                        _takenPhotoPath = photoPath;
                                      });
                                      walkStateManager.saveAnswerAndPhoto(
                                        answer: '',
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
                            Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                            updateDestinationEventState(
                                true); // <-- 목적지 이벤트 완료 알림
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
