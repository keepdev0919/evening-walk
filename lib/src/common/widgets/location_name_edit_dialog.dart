import 'package:flutter/material.dart';

/// 위치명(출발지/목적지 등)을 편집하기 위한 공통 다이얼로그
/// - 역할: 화면별로 중복 구현되던 입력 다이얼로그를 통합
/// - onSave로 null이 전달되면 기본 주소 사용을 의미함
Future<void> showLocationNameEditDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required ValueChanged<String?> onSave,
}) async {
  final controller = TextEditingController(text: initialValue);
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white54, width: 1),
      ),
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '공유/일기에 표시될 이름이에요',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          StatefulBuilder(
            builder: (context, setInner) {
              return TextField(
                controller: controller,
                maxLength: 300,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  hintText: '예) OO공원 입구',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon:
                      const Icon(Icons.place_outlined, color: Colors.red),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            controller.clear();
                            setInner(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.white54, width: 1.2),
                  ),
                  counterStyle:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onChanged: (_) => setInner(() {}),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            onSave(null); // 기본 주소 사용
            Navigator.of(ctx).pop();
          },
          child:
              const Text('기본 주소 사용', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('취소', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            onSave(text.isEmpty ? null : text);
            Navigator.of(ctx).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.withValues(alpha: 0.9),
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        )
      ],
    ),
  );
}
