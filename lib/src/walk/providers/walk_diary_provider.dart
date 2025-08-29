import 'package:flutter/material.dart';
import '../services/walk_state_manager.dart';
import '../services/walk_session_service.dart';
import '../services/photo_share_service.dart';
import '../../core/services/log_service.dart';

/// WalkDiaryScreen의 상태 관리를 담당하는 Provider
/// setState 호출을 최소화하고 성능을 최적화함
class WalkDiaryProvider extends ChangeNotifier {
  WalkDiaryProvider({required this.walkStateManager}) {
    _initializeControllers();
    _initializePhotoPath();
  }

  final WalkStateManager walkStateManager;
  final WalkSessionService _sessionService = WalkSessionService();

  // 컨트롤러들
  late TextEditingController reflectionController;
  late TextEditingController answerEditController;

  // 상태 변수들
  String? _currentPhotoPath;
  String? _tempPhotoPath;
  bool _isEditingAnswer = false;
  bool _isEditingReflection = false;
  bool _isEditingPhoto = false;
  bool _hasRequestedPhotoRefreshAfterUpload = false;
  bool _isEditMode = false;
  bool _isSaving = false;

  // Getters
  String? get currentPhotoPath => _currentPhotoPath;
  String? get tempPhotoPath => _tempPhotoPath;
  bool get isEditingAnswer => _isEditingAnswer;
  bool get isEditingReflection => _isEditingReflection;
  bool get isEditingPhoto => _isEditingPhoto;
  bool get hasRequestedPhotoRefreshAfterUpload => _hasRequestedPhotoRefreshAfterUpload;
  bool get isEditMode => _isEditMode;
  bool get isSaving => _isSaving;

  void _initializeControllers() {
    reflectionController = TextEditingController(
      text: walkStateManager.userReflection ?? '',
    );
    answerEditController = TextEditingController(
      text: walkStateManager.userAnswer ?? '',
    );
  }

  void _initializePhotoPath() {
    _currentPhotoPath = walkStateManager.photoPath;
  }

  /// 편집 모드 토글
  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  /// 답변 편집 모드 토글
  void toggleAnswerEdit() {
    _isEditingAnswer = !_isEditingAnswer;
    if (_isEditingAnswer) {
      answerEditController.text = walkStateManager.userAnswer ?? '';
    }
    notifyListeners();
  }

  /// 소감 편집 모드 토글
  void toggleReflectionEdit() {
    _isEditingReflection = !_isEditingReflection;
    if (_isEditingReflection) {
      reflectionController.text = walkStateManager.userReflection ?? '';
    }
    notifyListeners();
  }

  /// 사진 편집 모드 토글
  void togglePhotoEdit() {
    _isEditingPhoto = !_isEditingPhoto;
    if (_isEditingPhoto) {
      _tempPhotoPath = _currentPhotoPath;
    } else {
      _tempPhotoPath = null;
    }
    notifyListeners();
  }

  /// 답변 저장
  void saveAnswer() {
    final newAnswer = answerEditController.text.trim();
    walkStateManager.saveUserAnswerAndPhoto(
      answer: newAnswer.isEmpty ? null : newAnswer,
    );
    _isEditingAnswer = false;
    LogService.info('WalkDiary', '답변 저장 완료: $newAnswer');
    notifyListeners();
  }

  /// 소감 저장
  void saveReflection() {
    final newReflection = reflectionController.text.trim();
    walkStateManager.saveReflection(
      newReflection.isEmpty ? null : newReflection,
    );
    _isEditingReflection = false;
    LogService.info('WalkDiary', '소감 저장 완료: $newReflection');
    notifyListeners();
  }

  /// 사진 저장
  void savePhoto() {
    if (_tempPhotoPath != null) {
      _currentPhotoPath = _tempPhotoPath;
      walkStateManager.saveUserAnswerAndPhoto(photoPath: _currentPhotoPath);
      LogService.info('WalkDiary', '사진 저장 완료: $_currentPhotoPath');
    }
    _isEditingPhoto = false;
    _tempPhotoPath = null;
    notifyListeners();
  }

  /// 사진 삭제
  void deletePhoto() {
    _currentPhotoPath = null;
    _tempPhotoPath = null;
    walkStateManager.saveUserAnswerAndPhoto(clearPhoto: true);
    _isEditingPhoto = false;
    LogService.info('WalkDiary', '사진 삭제 완료');
    notifyListeners();
  }

  /// 새 사진 촬영
  Future<void> takeNewPhoto() async {
    try {
      final photoPath = await walkStateManager.takePhoto();
      if (photoPath != null) {
        _tempPhotoPath = photoPath;
        LogService.info('WalkDiary', '새 사진 촬영 완료: $photoPath');
        notifyListeners();
      }
    } catch (e) {
      LogService.error('WalkDiary', '사진 촬영 실패', e);
    }
  }

  /// 전체 데이터 저장
  Future<void> saveWalkSession({
    required Function(bool) onCompleted,
    String? returnRoute,
  }) async {
    if (_isSaving) return;

    _isSaving = true;
    notifyListeners();

    try {
      // 현재 편집 중인 데이터들을 먼저 저장
      if (_isEditingAnswer) saveAnswer();
      if (_isEditingReflection) saveReflection();
      if (_isEditingPhoto) savePhoto();

      // 세션 저장
      final sessionId = await _sessionService.saveWalkSession(
        walkStateManager: walkStateManager,
      );
      
      if (sessionId != null) {
        LogService.info('WalkDiary', '산책 세션 저장 완료: $sessionId');
        onCompleted(true);
      } else {
        LogService.warning('WalkDiary', '산책 세션 저장 실패');
        onCompleted(false);
      }
    } catch (e) {
      LogService.error('WalkDiary', '산책 세션 저장 중 오류', e);
      onCompleted(false);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// 사진 공유 (GlobalKey 필요)
  Future<void> sharePhoto(GlobalKey repaintBoundaryKey) async {
    if (_currentPhotoPath == null) return;

    try {
      await PhotoShareService.captureAndShareWidget(
        repaintBoundaryKey: repaintBoundaryKey,
        customMessage: '저녁 산책 추억을 공유합니다!',
      );
      LogService.info('WalkDiary', '사진 공유 완료');
    } catch (e) {
      LogService.error('WalkDiary', '사진 공유 실패', e);
    }
  }

  /// 편집 취소
  void cancelEdit() {
    _isEditingAnswer = false;
    _isEditingReflection = false;
    _isEditingPhoto = false;
    _tempPhotoPath = null;
    
    // 컨트롤러 내용 복원
    answerEditController.text = walkStateManager.userAnswer ?? '';
    reflectionController.text = walkStateManager.userReflection ?? '';
    
    notifyListeners();
  }

  void setHasRequestedPhotoRefresh(bool value) {
    _hasRequestedPhotoRefreshAfterUpload = value;
    notifyListeners();
  }

  @override
  void dispose() {
    reflectionController.dispose();
    answerEditController.dispose();
    super.dispose();
  }
}