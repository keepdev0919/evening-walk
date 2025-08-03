import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/destination_event_handler.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/presentation/widgets/destination_event_card.dart';

/// 산책 중 발생하는 이벤트(질문 다이얼로그, 목적지 도착 카드)를 처리하는 유틸리티 클래스입니다.
class WalkEventHandler {
  final BuildContext context;
  final WalkStateManager walkStateManager;

  WalkEventHandler({
    required this.context,
    required this.walkStateManager,
  });

  /// 🚩 경유지 이벤트 발생!의 질문 다이얼로그를 표시합니다.
  void showQuestionDialog(String question) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          // title: const Text(
          //   '🚩 경유지 이벤트 발생!',
          //   style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          // ),
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

  /// 목적지 도착 시 표시되는 카드(바텀 시트)를 보여줍니다。
  /// 질문과 포즈 제안을 포함하며, 사용자의 답변과 사진을 저장합니다.
  void showDestinationCard() {
    final question = walkStateManager.waypointQuestion ?? "오늘 하루는 어떠셨나요?";
    final poseSuggestions = DestinationEventHandler().getPoseSuggestions();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: DestinationEventCard(
            question: question,
            poseSuggestions: poseSuggestions,
            onComplete: (answer, photoPath) {
              walkStateManager.saveAnswerAndPhoto(
                  answer: answer, photoPath: photoPath);
              Navigator.of(context).pop();
              // TODO: Navigate to results screen
            },
          ),
        );
      },
    );
  }
}
