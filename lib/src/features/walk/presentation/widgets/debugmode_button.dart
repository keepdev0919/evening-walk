import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/presentation/widgets/waypointDialog.dart';
import 'package:walk/src/features/walk/presentation/widgets/destinationDialog.dart';
// import 'package:walk/src/features/walk/presentation/screens/walk_diary_screen.dart';
// import 'package:walk/src/features/walk/presentation/widgets/walk_completion_dialog.dart';
// import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:walk/src/features/walk/presentation/screens/pose_recommendation_screen.dart';
// import 'package:walk/src/core/services/log_service.dart';

class DebugModeButtons extends StatelessWidget {
  final bool isLoading;
  final LatLng? currentPosition;
  final WalkStateManager walkStateManager;
  final String selectedMate;
  final Function(bool, String?, String?, [bool]) updateWaypointEventState;
  final Function(bool) updateDestinationEventState;
  final VoidCallback hideDestinationTeaseBubble;
  final Function(String) onPoseImageGenerated;
  final Function(String?) onPhotoTaken;
  final String? initialPoseImageUrl;
  final String? initialTakenPhotoPath;
  // 단순화: 모드 제거

  const DebugModeButtons({
    Key? key,
    required this.isLoading,
    required this.currentPosition,
    required this.walkStateManager,
    required this.selectedMate,
    required this.updateWaypointEventState,
    required this.updateDestinationEventState,
    required this.hideDestinationTeaseBubble,
    required this.onPoseImageGenerated,
    required this.onPhotoTaken,
    required this.initialPoseImageUrl,
    required this.initialTakenPhotoPath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isLoading && kDebugMode) {
      return Positioned(
        bottom: 32,
        left: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 경유지 도착 버튼
            ElevatedButton(
              // 1. 버튼 누름 -> 2. 질문 받아옴 -> 3. 경유지 도착 다이얼로그 띄움
              // 4. 이벤트 확인 누르면 질문 다이얼로그로 이동 -> 5. 질문받아온거 띄움
              // 6. 확인버튼 누르면 pop하면서 progress_map 띄움

              onPressed: () async {
                // onPressed를 비동기로 변경
                if (currentPosition != null) {
                  // await를 사용하여 비동기 함수의 결과를 기다림
                  final String? question =
                      await walkStateManager.updateUserLocation(
                    currentPosition!,
                    forceWaypointEvent: true,
                  );

                  // 위젯이 여전히 화면에 있는지 확인 (비동기 작업 후)
                  if (!context.mounted) return;

                  if (question != null) {
                    WaypointDialogs.showWaypointArrivalDialog(
                      context: context,
                      questionPayload: question,
                      selectedMate: selectedMate,
                      updateWaypointEventState: updateWaypointEventState,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            '경유지 질문 생성에 실패했습니다. 경유지가 없거나 다른 이벤트가 발생했습니다. ✨'),
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'WalkStateManager 또는 현재 위치가 초기화되지 않았습니다. ✨'),
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('경유지 도착', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            // 목적지 도착 버튼
            ElevatedButton(
              onPressed: () async {
                if (currentPosition != null) {
                  final result = await walkStateManager.updateUserLocation(
                    currentPosition!,
                    forceDestinationEvent: true,
                  );

                  if (!context.mounted) return;

                  if (result == 'destination_reached') {
                    updateDestinationEventState(true);
                    final bool? wantsToSeeEvent =
                        await DestinationDialog.showDestinationArrivalDialog(
                      context: context,
                    );
                    if (wantsToSeeEvent == true && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PoseRecommendationScreen(
                            walkStateManager: walkStateManager,
                          ),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('목적지 도착 이벤트 처리에 실패했습니다. ✨'),
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('현재 위치를 알 수 없어 목적지 도착을 강제할 수 없습니다. ✨'),
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('목적지 도착', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            // 말풍선 테스트 버튼
            ElevatedButton(
              onPressed: () {
                _showSpeechBubbleTestDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('말풍선 테스트', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink(); // 디버그 모드가 아니면 아무것도 표시하지 않음
    }
  }

  /// 말풍선 테스트 다이얼로그를 표시합니다.
  void _showSpeechBubbleTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('말풍선 상태 테스트'),
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SpeechBubbleState.values.map((state) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      walkStateManager.setDebugSpeechBubbleState(state);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('말풍선 설정: ${state.message} ✨'),
                          backgroundColor: Colors.purple.withValues(alpha: 0.8),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getButtonColor(state),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      '${state.name}: ${state.message}',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 말풍선 상태별로 버튼 색상을 반환합니다.
  Color _getButtonColor(SpeechBubbleState state) {
    switch (state) {
      case SpeechBubbleState.toWaypoint:
        return Colors.blue.withValues(alpha: 0.8);
      case SpeechBubbleState.almostWaypoint:
        return Colors.orange.withValues(alpha: 0.8);
      case SpeechBubbleState.waypointEventCompleted:
        return Colors.yellow.withValues(alpha: 0.8); // 경유지 이벤트 완료 후 노란색
      case SpeechBubbleState.almostDestination:
        return Colors.red.withValues(alpha: 0.8);
      default:
        return Colors.grey.withValues(alpha: 0.8);
    }
  }
}
