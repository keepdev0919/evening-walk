import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/domain/models/walk_session.dart';
import 'package:intl/intl.dart';

/// 산책 목록에서 사용되는 개별 아이템 위젯
class WalkHistoryItemWidget extends StatelessWidget {
  final WalkSession walkSession;
  final VoidCallback onTap;
  final VoidCallback? onDelete; // 삭제 콜백 추가

  const WalkHistoryItemWidget({
    super.key,
    required this.walkSession,
    required this.onTap,
    this.onDelete, // 선택적 파라미터
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5), // 다이얼로그 스타일 참고한 반투명 검정 배경
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.white54, // 다이얼로그와 동일한 흰색 테두리
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 날짜와 메타 정보
                Row(
                  children: [
                    // 날짜 + 요일 + 시간 - 일기장 스타일 (왼쪽)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final dateInfo =
                              _formatDateWithDay(walkSession.startTime);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                dateInfo['dateWithDay']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2.0,
                                      color: Colors.black54,
                                      offset: Offset(1.0, 1.0),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateInfo['time']!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13, // 시간 부분만 작은 글씨
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2.0,
                                      color: Colors.black54,
                                      offset: Offset(1.0, 1.0),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 메이트 정보를 시간 옆으로 이동
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white54,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '${_getMateEmoji(walkSession.selectedMate)} ${_getSimpleMateText(walkSession.selectedMate)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 2.0,
                                        color: Colors.black54,
                                        offset: Offset(1.0, 1.0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // 오른쪽 끝: 거리, 시간, 삭제 버튼
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 거리 정보
                        if (walkSession.totalDistance != null) ...[
                          Text(
                            '👣 ${walkSession.totalDistance?.toStringAsFixed(1)}km',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  blurRadius: 2.0,
                                  color: Colors.black54,
                                  offset: Offset(1.0, 1.0),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // 시간 정보
                        if (walkSession.durationInMinutes != null) ...[
                          Text(
                            '⏰ ${walkSession.durationInMinutes}분',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  blurRadius: 2.0,
                                  color: Colors.black54,
                                  offset: Offset(1.0, 1.0),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // 삭제 버튼
                        if (onDelete != null)
                          GestureDetector(
                            onTap: () => _showDeleteConfirmDialog(context),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 경유지 질문 표시
                if (walkSession.waypointQuestion != null &&
                    walkSession.waypointQuestion!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white54,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '❓',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            walkSession.waypointQuestion!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                              shadows: [
                                Shadow(
                                  blurRadius: 2.0,
                                  color: Colors.black54,
                                  offset: Offset(1.0, 1.0),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white38,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '❓',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '경유지 질문이 없습니다',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            shadows: const [
                              Shadow(
                                blurRadius: 2.0,
                                color: Colors.black54,
                                offset: Offset(1.0, 1.0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 날짜 포맷팅 - 날짜 + 요일 + 시간으로 표시
  Map<String, String> _formatDateWithDay(DateTime dateTime) {
    // 한국어 요일 맵핑
    final weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
    final koreanWeekday = weekdays[dateTime.weekday];

    final dateWithDay =
        '${DateFormat('MM.dd').format(dateTime)}($koreanWeekday)';
    final time = DateFormat('HH:mm').format(dateTime);
    return {
      'dateWithDay': dateWithDay,
      'time': time,
    };
  }

  /// 동반자별 이모지 반환
  String _getMateEmoji(String mate) {
    switch (mate) {
      case '혼자':
        return '🌙'; // 혼자만의 시간
      case '연인':
        return '💕'; // 사랑
      case '친구':
        return '👫'; // 친구
      default:
        return '🚶'; // 기본 걷기
    }
  }

  /// 심플한 메이트 텍스트 반환 (이모지 제외)
  String _getSimpleMateText(String? selectedMate) {
    switch (selectedMate) {
      case '혼자':
        return '혼자';
      case '연인':
        return '연인';
      case '친구':
        return '친구';
      case '가족':
        return '가족';
      case '반려동물':
        return '반려동물';
      default:
        return '혼자';
    }
  }

  /// 삭제 확인 다이얼로그 표시
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                '기록 삭제',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이 산책 기록을 삭제하시겠습니까?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '삭제된 기록은 복구할 수 없습니다.',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete?.call(); // 삭제 콜백 호출
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '삭제',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
