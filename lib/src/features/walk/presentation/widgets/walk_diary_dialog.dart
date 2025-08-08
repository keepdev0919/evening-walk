import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:walk/src/features/walk/domain/models/walk_session.dart';
import 'dart:io';

class WalkDiaryDialog {
  static Future<void> show({
    required BuildContext context,
    required WalkStateManager walkStateManager,
    required Function(bool) onWalkCompleted,
  }) async {
    String userReflection = ''; // 사용자 소감
    final TextEditingController reflectionController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: Colors.black.withValues(alpha: 0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white54, width: 1.5),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🎉 완료 축하 헤더
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withValues(alpha: 0.8),
                              Colors.teal.withValues(alpha: 0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '🎉',
                              style: TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '산책 완료!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '오늘의 추억을 일기로 남겨보세요',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 경유지 경험 섹션
                      if (walkStateManager.waypointQuestion != null)
                        _buildExperienceSection(
                          title: '🚩 경유지에서',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Q. ${walkStateManager.waypointQuestion}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  walkStateManager.userAnswer ?? '(답변 없음)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (walkStateManager.waypointQuestion != null)
                        const SizedBox(height: 16),

                      // 목적지 경험 섹션
                      if (walkStateManager.photoPath != null)
                        _buildExperienceSection(
                          title: '📸 목적지에서',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '추천 포즈로 찍은 사진',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _showFullScreenPhoto(context, walkStateManager.photoPath!),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(walkStateManager.photoPath!),
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (walkStateManager.photoPath != null)
                        const SizedBox(height: 16),

                      // 소감 입력 섹션
                      _buildExperienceSection(
                        title: '💭 오늘의 소감',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '오늘 산책은 어떠셨나요?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: TextField(
                                controller: reflectionController,
                                maxLines: 4,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: '예) 날씨가 좋아서 기분이 좋았어요. 다음에도 이런 산책을 하고 싶어요.',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                onChanged: (value) {
                                  userReflection = value;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 버튼 영역
                      Row(
                        children: [
                          // 저장하기 버튼
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: const Text(
                                '일기 저장',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () async {
                                // Firebase에 산책 세션 저장
                                await WalkSessionService.quickSave(
                                  walkStateManager: walkStateManager,
                                  userReflection: userReflection.isEmpty ? null : userReflection,
                                );
                                
                                // 성공 메시지 표시
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('산책 일기가 저장되었습니다! 홈에서 확인하실 수 있어요.'),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                                
                                Navigator.of(dialogContext).pop();
                                onWalkCompleted(true);
                                
                                // 홈으로 이동
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/',
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.withValues(alpha: 0.8),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // 공유하기 버튼 (나중에 구현)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.share, color: Colors.white),
                              label: const Text(
                                '공유하기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () {
                                // TODO: 산책 일기 공유 기능 구현 예정
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('공유 기능은 곧 추가될 예정입니다!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.withValues(alpha: 0.8),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 경험 섹션 빌더
  static Widget _buildExperienceSection({
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  // 전체화면 사진 보기
  static void _showFullScreenPhoto(BuildContext context, String photoPath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(
                File(photoPath),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

}