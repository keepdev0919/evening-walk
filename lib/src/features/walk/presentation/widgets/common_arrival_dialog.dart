import 'package:flutter/material.dart';

/// 목적지/경유지 도착 다이얼로그의 공통 UI 컴포넌트
class CommonArrivalDialog {
  /// 공통 도착 다이얼로그 표시
  ///
  /// [title]: 다이얼로그 제목 (예: '목적지 도착!', '경유지 도착!')
  /// [icon]: 제목 앞에 표시할 아이콘
  /// [iconColor]: 아이콘 색상
  /// [message]: 본문 메시지 (예: '목적지 이벤트를 확인하시겠어요?')
  /// [onEventConfirm]: '이벤트 확인' 버튼 클릭 시 실행될 콜백
  /// [onLater]: '나중에' 버튼 클릭 시 실행될 콜백 (optional)
  /// [barrierDismissible]: 다이얼로그 외부 터치로 닫기 가능 여부
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required String message,
    required VoidCallback onEventConfirm,
    VoidCallback? onMessageTap,
    VoidCallback? onLater,
    bool barrierDismissible = false,
    String confirmLabel = '확인',
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Colors.white70, width: 1.5),
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 420,
              maxHeight: 500,
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 제목 영역
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: iconColor,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 4,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 메시지 영역
                GestureDetector(
                  onTap: onMessageTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // 버튼 영역
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onLater != null) ...[
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(false);
                              onLater();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white70,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: const Text(
                              '나중에',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      flex: 1,
                      child: Container(
                        margin: EdgeInsets.only(
                          left: onLater != null ? 8 : 0,
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true);
                            onEventConfirm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: iconColor.withValues(alpha: 0.9),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: iconColor.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: iconColor.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
