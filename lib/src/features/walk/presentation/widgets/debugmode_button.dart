import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/presentation/widgets/waypointDialog.dart';
import 'package:walk/src/features/walk/presentation/widgets/destinationDialog.dart';
import 'package:walk/src/features/walk/presentation/widgets/walk_diary_dialog.dart';

class DebugModeButtons extends StatelessWidget {
  final bool isLoading;
  final LatLng? currentPosition;
  final WalkStateManager walkStateManager;
  final String selectedMate;
  final Function(bool, String?, String?) updateWaypointEventState;
  final Function(bool) updateDestinationEventState;
  final Function(String) onPoseImageGenerated;
  final Function(String?) onPhotoTaken;

  const DebugModeButtons({
    Key? key,
    required this.isLoading,
    required this.currentPosition,
    required this.walkStateManager,
    required this.selectedMate,
    required this.updateWaypointEventState,
    required this.updateDestinationEventState,
    required this.onPoseImageGenerated,
    required this.onPhotoTaken,
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
                      updateWaypointEventState: updateWaypointEventState,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('경유지 질문 생성에 실패했습니다. 경유지가 없거나 다른 이벤트가 발생했습니다.'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('WalkStateManager 또는 현재 위치가 초기화되지 않았습니다.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withOpacity(0.8),
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
                    DestinationDialog.showDestinationArrivalDialog(
                      context: context,
                      walkStateManager: walkStateManager,
                      selectedMate: selectedMate,
                      updateDestinationEventState: updateDestinationEventState,
                      onPoseImageGenerated: onPoseImageGenerated,
                      onPhotoTaken: onPhotoTaken,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('목적지 도착 이벤트 처리에 실패했습니다.'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('현재 위치를 알 수 없어 목적지 도착을 강제할 수 없습니다.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('목적지 도착', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            // 출발지 복귀 버튼
            ElevatedButton(
              onPressed: () async {
                if (currentPosition != null) {
                  final result = await walkStateManager.updateUserLocation(
                    currentPosition!,
                    forceStartReturnEvent: true,
                  );

                  if (!context.mounted) return;

                  if (result == 'start_returned') {
                    WalkDiaryDialog.show(
                      context: context,
                      walkStateManager: walkStateManager,
                      onWalkCompleted: (completed) {
                        print('디버그: 산책이 완전히 완료되었습니다!');
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('출발지 복귀 이벤트 처리에 실패했습니다.'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('현재 위치를 알 수 없어 출발지 복귀를 강제할 수 없습니다.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('출발지 복귀', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink(); // 디버그 모드가 아니면 아무것도 표시하지 않음
    }
  }
}
