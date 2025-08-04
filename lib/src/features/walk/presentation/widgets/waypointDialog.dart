import 'package:flutter/material.dart';

class WaypointDialogs {
  static Future<void> showWaypointArrivalDialog({
    required BuildContext context,
    required String questionPayload,
    required Function(bool, String?) updateWaypointEventState,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 사용자가 다이얼로그 바깥을 탭하여 닫을 수 없게 함
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.7), // 배경색
          shape: RoundedRectangleBorder(
            // 모양
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          title: const Text(
            '🚩 경유지 도착!', // 제목
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  '경유지에 도착했습니다. 이벤트를 확인하시겠습니까?', // 내용
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              // 버튼
              onPressed: () {
                Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                updateWaypointEventState(true, questionPayload);
                WaypointDialogs.showQuestionDialog(
                    context, questionPayload); // 질문 다이얼로그 표시
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // 원하는 색상으로 지정
              ),
              child: const Text('이벤트 확인'),
            ),
          ],
        );
      },
    );
  }

  static void showQuestionDialog(BuildContext context, String question) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          content: Text(
            question,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // 원하는 색상으로 지정
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}
