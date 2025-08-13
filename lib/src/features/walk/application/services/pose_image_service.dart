import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math';
import 'package:walk/src/core/services/log_service.dart';

class PoseImageService {
  static Future<String?> fetchRandomImageUrl(String mate) async {
    try {
      // 한글 메이트 이름을 영어 폴더 이름으로 매핑
      String folderName;
      switch (mate) {
        case '혼자':
          folderName = 'alone';
          break;
        case '연인':
          folderName = 'couple';
          break;
        case '친구':
          folderName = 'friend';
          break;
        default:
          folderName = 'alone'; // 기본값 또는 에러 처리
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('recommendation_pose_images/$folderName/');
      final ListResult result = await storageRef.listAll();

      if (result.items.isNotEmpty) {
        final random = Random();
        final Reference randomRef =
            result.items[random.nextInt(result.items.length)];
        return await randomRef.getDownloadURL();
      }
    } catch (e) {
      LogService.error('Walk', 'Error loading images from Firebase Storage', e);
    }
    return null;
  }
}