/// 업로드 상태를 나타내는 열거형
enum UploadStatus {
  idle, // 대기 중
  uploading, // 업로드 중
  completed, // 완료
  failed, // 실패
}

/// 개별 산책 세션의 업로드 상태
class WalkSessionUploadState {
  final String sessionId;
  final UploadStatus status;
  final double progress; // 0.0 ~ 1.0
  final String? errorMessage;
  final DateTime? startTime;
  final DateTime? completedTime;

  const WalkSessionUploadState({
    required this.sessionId,
    this.status = UploadStatus.idle,
    this.progress = 0.0,
    this.errorMessage,
    this.startTime,
    this.completedTime,
  });

  /// 복사 생성자
  WalkSessionUploadState copyWith({
    String? sessionId,
    UploadStatus? status,
    double? progress,
    String? errorMessage,
    DateTime? startTime,
    DateTime? completedTime,
  }) {
    return WalkSessionUploadState(
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      completedTime: completedTime ?? this.completedTime,
    );
  }

  /// 업로드가 진행 중인지 확인
  bool get isUploading => status == UploadStatus.uploading;

  /// 업로드가 완료되었는지 확인
  bool get isCompleted => status == UploadStatus.completed;

  /// 업로드가 실패했는지 확인
  bool get isFailed => status == UploadStatus.failed;

  @override
  String toString() {
    return 'WalkSessionUploadState(sessionId: $sessionId, status: $status, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalkSessionUploadState &&
        other.sessionId == sessionId &&
        other.status == status &&
        other.progress == progress;
  }

  @override
  int get hashCode => Object.hash(sessionId, status, progress);
}
