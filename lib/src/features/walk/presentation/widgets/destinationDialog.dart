import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'pose_recommendation_dialog.dart';

class DestinationDialog {
  static void showDestinationArrivalDialog({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required String selectedMate,
    required Function(bool) updateDestinationEventState,
    String? initialPoseImageUrl,
    String? initialTakenPhotoPath,
    required Function(String) onPoseImageGenerated,
    required Function(String?) onPhotoTaken,
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
                PoseRecommendationDialog.show(
                  context: context,
                  walkStateManager: walkStateManager,
                  selectedMate: selectedMate,
                  updateDestinationEventState: updateDestinationEventState,
                  initialPoseImageUrl: initialPoseImageUrl,
                  initialTakenPhotoPath: initialTakenPhotoPath,
                  onPoseImageGenerated: onPoseImageGenerated,
                  onPhotoTaken: onPhotoTaken,
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

}
