import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/domain/models/walk_session.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

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
    final double? _distanceKm =
        walkSession.totalDistance ?? _straightLineDistanceKm(walkSession);
    return Container(
      // 카드가 필터 탭/상단 위젯과 붙어 보이지 않도록 하단 여백을 넉넉히 확보
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5), // 다이얼로그 스타일 참고한 반투명 검정 배경
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
                              // 메이트 정보를 시간 옆으로 이동 (Flexible로 래핑하여 오버플로우 방지)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white54,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${_getMateEmoji(_normalizeMate(walkSession.selectedMate))} ${_normalizeMate(walkSession.selectedMate)}',
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
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // 오른쪽 끝: 시간, 거리, 삭제 버튼 (순서 변경)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                          const SizedBox(width: 12),
                        ],
                        // 거리 정보 (시간 다음)
                        if (_distanceKm != null) ...[
                          Text(
                            '👣 ${_distanceKm.toStringAsFixed(1)}km',
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
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
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
                      color: Colors.black.withValues(alpha: 0.2),
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
                      color: Colors.black.withValues(alpha: 0.15),
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
                            color: Colors.grey.withValues(alpha: 0.6),
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

  double _straightLineDistanceKm(WalkSession s) {
    final d = Geolocator.distanceBetween(
      s.startLocation.latitude,
      s.startLocation.longitude,
      s.destinationLocation.latitude,
      s.destinationLocation.longitude,
    );
    return d / 1000.0;
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
      case '반려견':
        return '🐕'; // 반려견
      case '가족':
        return '👨‍👩‍👧‍👦'; // 가족
      default:
        return '🚶'; // 기본 걷기
    }
  }

  /// 심플한 메이트 텍스트 반환 (이모지 제외)
  String _normalizeMate(String? mate) {
    if (mate == null) return '혼자';
    if (mate.startsWith('친구')) return '친구';
    return mate;
  }

  /// 삭제 확인 다이얼로그 표시
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
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
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
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
                backgroundColor: Colors.red.withValues(alpha: 0.8),
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
