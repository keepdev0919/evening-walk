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
    VoidCallback? onLater,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            if (onLater != null)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false); // false 반환
                  onLater();
                },
                child: const Text('나중에', style: TextStyle(color: Colors.white70)),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // true 반환
                onEventConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: const Text('이벤트 확인'),
            ),
          ],
        );
      },
    );
  }
}