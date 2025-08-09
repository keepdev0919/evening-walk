import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 사진을 Firebase Storage에 업로드하는 서비스
class PhotoUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 목적지 사진을 Firebase Storage에 업로드
  /// 
  /// [filePath]: 로컬 사진 파일 경로
  /// [sessionId]: 산책 세션 ID (파일명에 사용)
  /// [onProgress]: 업로드 진행률 콜백 (0.0 ~ 1.0)
  /// 
  /// Returns: 업로드된 사진의 다운로드 URL, 실패 시 null
  Future<String?> uploadDestinationPhoto({
    required String filePath,
    required String sessionId,
    Function(double progress)? onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('PhotoUploadService: 사용자가 로그인되지 않음');
        return null;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        print('PhotoUploadService: 파일이 존재하지 않음: $filePath');
        return null;
      }

      // Storage 경로: user_photos/{userId}/{sessionId}_destination.jpg
      final String fileName = '${sessionId}_destination.jpg';
      final String storagePath = 'user_photos/${user.uid}/$fileName';

      print('PhotoUploadService: 업로드 시작 - $storagePath');

      // Firebase Storage에 업로드
      final Reference ref = _storage.ref().child(storagePath);
      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'sessionId': sessionId,
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        ),
      );

      // 업로드 진행률 모니터링
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('PhotoUploadService: 업로드 진행률: ${(progress * 100).toStringAsFixed(1)}%');
        
        // 진행률 콜백 호출
        if (onProgress != null) {
          onProgress(progress);
        }
      });

      // 업로드 완료 대기
      final TaskSnapshot snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        // 다운로드 URL 획득
        final String downloadUrl = await ref.getDownloadURL();
        print('PhotoUploadService: 업로드 완료 - URL: $downloadUrl');
        return downloadUrl;
      } else {
        print('PhotoUploadService: 업로드 실패 - State: ${snapshot.state}');
        return null;
      }
    } catch (e) {
      print('PhotoUploadService: 사진 업로드 중 오류 발생: $e');
      return null;
    }
  }

  /// 업로드된 사진 삭제
  /// 
  /// [photoUrl]: Firebase Storage 다운로드 URL
  /// 
  /// Returns: 삭제 성공 여부
  Future<bool> deletePhoto(String photoUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('PhotoUploadService: 사용자가 로그인되지 않음');
        return false;
      }

      // URL에서 Storage Reference 생성
      final Reference ref = _storage.refFromURL(photoUrl);
      
      // 삭제 실행
      await ref.delete();
      print('PhotoUploadService: 사진 삭제 완료 - $photoUrl');
      return true;
    } catch (e) {
      print('PhotoUploadService: 사진 삭제 중 오류 발생: $e');
      return false;
    }
  }

  /// 사용자의 모든 사진 목록 조회 (선택적 기능)
  /// 
  /// Returns: 사용자가 업로드한 사진 URL 목록
  Future<List<String>> getUserPhotos() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('PhotoUploadService: 사용자가 로그인되지 않음');
        return [];
      }

      final String userFolderPath = 'user_photos/${user.uid}';
      final Reference userFolderRef = _storage.ref().child(userFolderPath);
      
      final ListResult result = await userFolderRef.listAll();
      
      List<String> photoUrls = [];
      for (Reference ref in result.items) {
        try {
          final String downloadUrl = await ref.getDownloadURL();
          photoUrls.add(downloadUrl);
        } catch (e) {
          print('PhotoUploadService: URL 조회 실패 - ${ref.fullPath}: $e');
        }
      }

      print('PhotoUploadService: ${photoUrls.length}개의 사진을 찾았습니다.');
      return photoUrls;
    } catch (e) {
      print('PhotoUploadService: 사진 목록 조회 중 오류 발생: $e');
      return [];
    }
  }

  /// 파일 크기 확인 (업로드 전 검증용)
  /// 
  /// [filePath]: 확인할 파일 경로
  /// [maxSizeMB]: 최대 허용 크기 (MB, 기본값 10MB)
  /// 
  /// Returns: 파일 크기가 제한 내에 있으면 true
  Future<bool> validateFileSize(String filePath, {int maxSizeMB = 10}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final int fileSizeBytes = await file.length();
      final double fileSizeMB = fileSizeBytes / (1024 * 1024);
      
      print('PhotoUploadService: 파일 크기: ${fileSizeMB.toStringAsFixed(2)}MB');
      
      return fileSizeMB <= maxSizeMB;
    } catch (e) {
      print('PhotoUploadService: 파일 크기 확인 중 오류 발생: $e');
      return false;
    }
  }
}