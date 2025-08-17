import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math';
import 'package:walk/src/core/services/log_service.dart';

class PoseImageService {
  static Future<String?> fetchRandomImageUrl(String mate) async {
    try {
      // 한글 메이트 이름을 영어 폴더 이름으로 매핑
      String folderName;
      if (mate.startsWith('친구')) {
        // "친구", "친구(2명)", "친구(여러명)" 모두 friend 폴더 사용
        folderName = 'friend';
      } else {
        switch (mate) {
          case '혼자':
            folderName = 'alone';
            break;
          case '연인':
            folderName = 'couple';
            break;
          case '반려견':
            folderName = 'dog';
            break;
          case '가족':
            folderName = 'family';
            break;
          default:
            folderName = 'alone'; // 기본값 또는 에러 처리
        }
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
