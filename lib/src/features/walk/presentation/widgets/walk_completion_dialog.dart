import 'package:flutter/material.dart';

class WalkCompletionDialog {
  static Future<bool?> showWalkCompletionDialog({
    required BuildContext context,
    required String savedSessionId, // 이미 저장된 세션 ID
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          title: const Column(
            children: [
              Text(
                '🎉',
                style: TextStyle(fontSize: 48),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '산책 완료!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: const Text(
            '오늘의 산책 일기가 도착했어요!\n소중한 추억을 기록해보세요.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // 나중에
              },
              child: const Text(
                '나중에',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // 확인
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.withValues(alpha: 0.8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '일기 작성',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}