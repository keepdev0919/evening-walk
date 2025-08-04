import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'dart:math';

class DestinationDialog {
  static void showDestinationArrivalDialog({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required String selectedMate,
    required Map<String, List<String>> mateImagesManifest,
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
                  mateImagesManifest: mateImagesManifest,
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

  static void showPoseRecommendationDialog({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required String selectedMate,
    required Map<String, List<String>> mateImagesManifest,
  }) {
    final List<String>? images = mateImagesManifest[selectedMate];
    String? randomImagePath;

    if (images != null && images.isNotEmpty) {
      final _random = Random();
      randomImagePath = images[_random.nextInt(images.length)];
    }

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
              if (randomImagePath != null)
                Image.asset(
                  randomImagePath,
                  height: 200,
                  fit: BoxFit.cover,
                )
              else
                const Text(
                  '추천 이미지를 찾을 수 없습니다.',
                  style: TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 16),
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
                  final photoPath =
                      await walkStateManager.takePhoto(); // 예: 사진 촬영 메소드
                  walkStateManager.saveAnswerAndPhoto(
                    answer: '',
                    photoPath: photoPath,
                  );
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
