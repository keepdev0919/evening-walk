import 'package:flutter/foundation.dart';
import '../models/upload_state.dart';
import '../../common/services/toast_service.dart';
import '../services/photo_upload_service.dart';
import '../services/walk_session_service.dart';
import '../../core/services/log_service.dart';

/// 업로드 상태를 관리하는 Provider
class UploadProvider extends ChangeNotifier {
  final Map<String, WalkSessionUploadState> _uploadStates = {};
  final PhotoUploadService _photoUploadService = PhotoUploadService();

  /// 모든 업로드 상태 조회
  Map<String, WalkSessionUploadState> get uploadStates =>
      Map.unmodifiable(_uploadStates);

  /// 특정 세션의 업로드 상태 조회
  WalkSessionUploadState? getUploadState(String sessionId) {
    return _uploadStates[sessionId];
  }

  /// 백그라운드에서 사진 업로드 시작
  Future<void> startBackgroundUpload(
    String sessionId,
    String photoPath,
  ) async {
    // 업로드 상태 초기화
    _uploadStates[sessionId] = WalkSessionUploadState(
      sessionId: sessionId,
      status: UploadStatus.uploading,
      startTime: DateTime.now(),
    );
    notifyListeners();

    try {
      // 사진 업로드 수행
      final uploadedUrl = await _photoUploadService.uploadDestinationPhoto(
        filePath: photoPath,
        sessionId: sessionId,
        onProgress: (progress) {
          // 진행률 업데이트
          _updateUploadProgress(sessionId, progress);
        },
      );

      if (uploadedUrl != null) {
        // 업로드 성공
        _uploadStates[sessionId] = _uploadStates[sessionId]!.copyWith(
          status: UploadStatus.completed,
          progress: 1.0,
          completedTime: DateTime.now(),
        );

        // Firestore의 세션 데이터 업데이트
        await _updateSessionPhotoUrl(sessionId, uploadedUrl);
      } else {
        // 업로드 실패 (URL이 null)
        _handleUploadFailure(sessionId, '사진 업로드에 실패했습니다.');
      }
    } catch (e) {
      // 업로드 실패 (예외 발생)
      _handleUploadFailure(sessionId, '사진 업로드 중 오류가 발생했습니다: ${e.toString()}');
    }

    notifyListeners();
  }

  /// 업로드 진행률 업데이트
  void _updateUploadProgress(String sessionId, double progress) {
    final currentState = _uploadStates[sessionId];
    if (currentState != null && currentState.isUploading) {
      _uploadStates[sessionId] = currentState.copyWith(progress: progress);
      notifyListeners();
    }
  }

  /// 업로드 실패 처리
  void _handleUploadFailure(String sessionId, String errorMessage) {
    _uploadStates[sessionId] = _uploadStates[sessionId]!.copyWith(
      status: UploadStatus.failed,
      errorMessage: errorMessage,
    );

    ToastService.showError(errorMessage);
  }

  /// Firestore의 세션 데이터에 사진 URL 업데이트
  Future<void> _updateSessionPhotoUrl(String sessionId, String photoUrl) async {
    try {
      final walkSessionService = WalkSessionService();
      await walkSessionService.updateWalkSession(sessionId, {
        'takenPhotoPath': photoUrl,
      });
    } catch (e) {
      LogService.error('Upload', '세션 사진 URL 업데이트 실패', e);
    }
  }

  /// Provider 해제 시 정리
  @override
  void dispose() {
    _uploadStates.clear();
    super.dispose();
  }
}
