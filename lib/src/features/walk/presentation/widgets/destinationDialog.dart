import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io'; // File 클래스를 사용하기 위해 추가

class DestinationDialog {
  static void showDestinationArrivalDialog({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required String selectedMate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '📍 목적지에 도착했어요!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '산책을 완료했습니다. 이벤트를 확인하시겠습니까?',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showPoseRecommendationDialog(
                  context: context,
                  walkStateManager: walkStateManager,
                  selectedMate: selectedMate,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
              child: const Text('이벤트 확인'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showPoseRecommendationDialog({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required String selectedMate,
  }) async {
    // Firebase Storage에서 랜덤 이미지 URL을 가져오는 비동기 헬퍼 함수
    Future<String?> fetchRandomImageUrl(String mate) async {
      try {
        // 한글 메이트 이름을 영어 폴더 이름으로 매핑
        String folderName;
        switch (mate) {
          case '혼자':
            folderName = 'alone';
            break;
          case '연인':
            folderName = 'couple';
            break;
          case '친구':
            folderName = 'friend';
            break;
          default:
            folderName = 'alone'; // 기본값 또는 에러 처리
        }

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('recommendation_pose_images/$folderName/');
        final ListResult result = await storageRef.listAll();

        if (result.items.isNotEmpty) {
          final random = Random();
          final Reference randomRef =
              result.items[random.nextInt(result.items.length)];
          return await randomRef.getDownloadURL();
        }
      } catch (e) {
        print('Error loading images from Firebase Storage: $e');
      }
      return null;
    }

    // 다이얼로그가 처음 열릴 때만 랜덤 이미지 URL을 가져옵니다.
    final String? initialRandomImagePath =
        await fetchRandomImageUrl(selectedMate);

    String? _takenPhotoPath; // 찍은 사진 경로를 저장할 변수

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.black.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white54, width: 1),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '📸 포즈 추천!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 추천 포즈 이미지
                  if (initialRandomImagePath != null)
                    CachedNetworkImage(
                      imageUrl: initialRandomImagePath,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    )
                  else
                    const Text(
                      '추천 이미지를 찾을 수 없습니다.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  const SizedBox(height: 16),
                  // 찍은 사진이 있으면 표시
                  if (_takenPhotoPath != null)
                    Column(
                      children: [
                        const Text(
                          '내가 찍은 사진:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext fullScreenDialogContext) {
                                return Dialog(
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
                                        top: 10,
                                        right: 10,
                                        child: IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.white, size: 30),
                                          onPressed: () {
                                            Navigator.of(
                                                    fullScreenDialogContext)
                                                .pop();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Image.file(
                            File(_takenPhotoPath!),
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  const Text(
                    '추천 포즈를 참고해 사진을 남겨보세요!',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('사진 찍기'),
                    onPressed: () async {
                      final photoPath = await walkStateManager.takePhoto();
                      if (photoPath != null) {
                        setState(() {
                          _takenPhotoPath = photoPath;
                        });
                        walkStateManager.saveAnswerAndPhoto(
                          answer: '',
                          photoPath: photoPath,
                        );
                      }
                      // 다이얼로그를 닫지 않습니다.
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                    ),
                    child: const Text('완료'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
