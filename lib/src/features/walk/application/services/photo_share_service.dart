import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class PhotoShareService {

  /// 위젯을 캡처하고 이미지로 공유하는 메서드
  static Future<void> captureAndShareWidget({
    required GlobalKey repaintBoundaryKey,
    String? customMessage,
  }) async {
    try {
      // RepaintBoundary에서 위젯을 이미지로 캡처
      RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // 고화질 이미지 생성 (픽셀 비율 적용)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('이미지 데이터를 생성할 수 없습니다.');
      }

      // 임시 디렉토리에 이미지 파일 저장
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/pose_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);

      await file.writeAsBytes(byteData.buffer.asUint8List());

      // 기본 메시지 설정
      final message = customMessage ??
          '''
📸 저녁 산책!

추천받은 포즈와 제가 찍은 사진입니다 😊

#저녁산책 #포즈추천 #산책일기
      '''
              .trim();

      // XFile 객체로 변환하여 공유
      final xFile = XFile(filePath);

      await Share.shareXFiles(
        [xFile],
        text: message,
      );

      // 임시 파일 정리 (공유 후 잠시 대기 후 삭제)
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('임시 파일 삭제 중 오류: $e');
        }
      });
    } catch (e) {
      debugPrint('위젯 캡처 및 공유 중 오류 발생: $e');
      rethrow;
    }
  }
}
