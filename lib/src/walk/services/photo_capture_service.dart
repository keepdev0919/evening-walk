import 'package:image_picker/image_picker.dart';
import '../../core/services/log_service.dart';

/// 사진 촬영 전용 서비스
/// SRP: 사진 촬영과 관련된 책임만 담당
class PhotoCaptureService {
  final ImagePicker _picker = ImagePicker();

  /// 카메라로 사진 촬영
  Future<String?> takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // 품질 최적화
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        LogService.info('PhotoCapture', '사진 촬영 성공: ${photo.path}');
        return photo.path;
      } else {
        LogService.info('PhotoCapture', '사용자가 사진 촬영을 취소했습니다.');
        return null;
      }
    } catch (e) {
      LogService.error('PhotoCapture', '사진 촬영 중 오류 발생', e);
      return null;
    }
  }

  /// 갤러리에서 사진 선택
  Future<String?> pickFromGallery() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (photo != null) {
        LogService.info('PhotoCapture', '갤러리에서 사진 선택 성공: ${photo.path}');
        return photo.path;
      } else {
        LogService.info('PhotoCapture', '사용자가 사진 선택을 취소했습니다.');
        return null;
      }
    } catch (e) {
      LogService.error('PhotoCapture', '갤러리 사진 선택 중 오류 발생', e);
      return null;
    }
  }

  /// 여러 사진 선택 (향후 확장용)
  Future<List<String>?> pickMultipleFromGallery({int maxImages = 5}) async {
    try {
      final photos = await _picker.pickMultiImage(
        imageQuality: 85,
        limit: maxImages,
      );

      if (photos.isNotEmpty) {
        final paths = photos.map((photo) => photo.path).toList();
        LogService.info('PhotoCapture', '${paths.length}개 사진 선택 성공');
        return paths;
      } else {
        LogService.info('PhotoCapture', '사용자가 사진 선택을 취소했습니다.');
        return null;
      }
    } catch (e) {
      LogService.error('PhotoCapture', '다중 사진 선택 중 오류 발생', e);
      return null;
    }
  }
}