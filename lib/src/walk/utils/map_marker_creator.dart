import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:walk/src/core/services/log_service.dart';

//walk_in_progress에서 사용합니다.
/// 프로필 이미지, 선물 상자, 깃발 모양의 마커를 생성하는 기능을 제공합니다.
class MapMarkerCreator {
  /// 프로필 이미지의 마커 비트맵을 생성합니다. 출발지 마커로 사용됩니다.
  static Future<BitmapDescriptor> createCustomProfileMarkerBitmap(
      User? user) async {
    String? imageUrl;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          imageUrl = userDoc.data()?['profileImageUrl'];
        }
      } catch (e) {
        LogService.error(
            'Walk', 'Failed to fetch user data for profile marker', e);
      }
    }

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double pinSize = 150.0;
    const double avatarRadius = 50.0;

    final Paint pinPaint = Paint()..color = Colors.blue;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    final Paint circlePaint = Paint()..color = Colors.black;
    canvas.drawCircle(
        const Offset(pinSize / 2, pinSize / 2), avatarRadius + 5, circlePaint);

    ui.Image? avatarImage;
    if (imageUrl != null) {
      try {
        final Uint8List bytes = (await http.get(Uri.parse(imageUrl))).bodyBytes;
        final ui.Codec codec = await ui.instantiateImageCodec(bytes,
            targetWidth: avatarRadius.toInt() * 2);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        avatarImage = frameInfo.image;
      } catch (e) {
        LogService.error('Walk', 'Error loading profile image for marker', e);
      }
    }

    final Rect avatarRect = Rect.fromCircle(
        center: const Offset(pinSize / 2, pinSize / 2), radius: avatarRadius);
    final Path clipPath = Path()..addOval(avatarRect);
    canvas.clipPath(clipPath);

    if (avatarImage != null) {
      paintImage(
          canvas: canvas,
          rect: avatarRect,
          image: avatarImage,
          fit: BoxFit.cover);
    } else {
      final Paint placeholderPaint = Paint()..color = Colors.grey[300]!;
      canvas.drawCircle(avatarRect.center, avatarRadius, placeholderPaint);
    }

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  /// 선물 상자 모양의 마커 비트맵을 생성합니다. 경유지 마커로 사용됩니다.
  static Future<BitmapDescriptor> createGiftBoxMarkerBitmap() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double pinSize = 150.0;
    const double iconSize = 60.0;

    final Paint pinPaint = Paint()..color = Colors.orange;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    final Paint circlePaint = Paint()..color = Colors.black;
    canvas.drawCircle(const Offset(pinSize / 2, pinSize / 2.5),
        (iconSize / 1.2) + 5, circlePaint);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.card_giftcard.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.card_giftcard.fontFamily,
          color: Colors.orange,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
          (pinSize - textPainter.width) / 2,
          (pinSize / 2.5) - (textPainter.height / 2),
        ));

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  /// 깃발 모양의 마커 비트맵을 생성합니다. 목적지 마커로 사용됩니다.
  static Future<BitmapDescriptor> createDestinationMarkerBitmap() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double pinSize = 150.0;
    const double iconSize = 60.0;

    final Paint pinPaint = Paint()..color = Colors.red;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    final Paint circlePaint = Paint()..color = Colors.black;
    canvas.drawCircle(const Offset(pinSize / 2, pinSize / 2.5),
        (iconSize / 1.2) + 5, circlePaint);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.flag.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.flag.fontFamily,
          color: Colors.red,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
          (pinSize - textPainter.width) / 2,
          (pinSize / 2.5) - (textPainter.height / 2),
        ));

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  /// 집(홈) 아이콘의 마커 비트맵을 생성합니다. 출발지 마커로 사용됩니다.
  static Future<BitmapDescriptor> createHomeMarkerBitmap() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double pinSize = 150.0;
    const double iconSize = 60.0;

    final Paint pinPaint = Paint()..color = Colors.blue;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    final Paint circlePaint = Paint()..color = Colors.black;
    canvas.drawCircle(const Offset(pinSize / 2, pinSize / 2.5),
        (iconSize / 1.2) + 5, circlePaint);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.home.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.home.fontFamily,
          color: Colors.blue,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
          (pinSize - textPainter.width) / 2,
          (pinSize / 2.5) - (textPainter.height / 2),
        ));

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  /// UI용 PNG 바이트로 경유지(선물상자) 마커 아이콘을 생성합니다.
  /// 리스트/일기 화면 등 지도 외 위젯에서 이미지로 사용합니다.
  static Future<Uint8List> createGiftBoxMarkerPng({
    double pinSize = 60.0,
    double iconSize = 24.0,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint pinPaint = Paint()..color = Colors.orange;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    final Paint circlePaint = Paint()..color = Colors.black;
    canvas.drawCircle(
      Offset(pinSize / 2, pinSize / 2.5),
      (iconSize / 1.2) + 4,
      circlePaint,
    );

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.card_giftcard.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.card_giftcard.fontFamily,
          color: Colors.orange,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (pinSize - textPainter.width) / 2,
        (pinSize / 2.5) - (textPainter.height / 2),
      ),
    );

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// UI용 PNG 바이트로 목적지(깃발) 마커 아이콘을 생성합니다.
  /// 리스트/일기 화면 등 지도 외 위젯에서 이미지로 사용합니다.
  static Future<Uint8List> createDestinationMarkerPng({
    double pinSize = 60.0,
    double iconSize = 24.0,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint pinPaint = Paint()..color = Colors.red;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    final Paint circlePaint = Paint()..color = Colors.black;
    canvas.drawCircle(
      Offset(pinSize / 2, pinSize / 2.5),
      (iconSize / 1.2) + 4,
      circlePaint,
    );

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.flag.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.flag.fontFamily,
          color: Colors.red,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (pinSize - textPainter.width) / 2,
        (pinSize / 2.5) - (textPainter.height / 2),
      ),
    );

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// 발자국(🐾) 이모지를 그려서 Google Maps 마커로 사용할 비트맵을 생성합니다.
  /// 지도 위에 사용자의 이동 경로를 따라 작은 발자국 마커를 찍는 용도로 사용합니다.
  static Future<BitmapDescriptor> createFootprintMarkerBitmap({
    double canvasSize = 64.0,
    double emojiSize = 44.0,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // 투명 배경 위에 이모지를 중앙 정렬로 그림
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text: '👣',
        style: TextStyle(
          fontSize: 40.0,
        ),
      ),
    );
    textPainter.layout();
    final double dx = (canvasSize - textPainter.width) / 2.0;
    final double dy = (canvasSize - textPainter.height) / 2.0;
    textPainter.paint(canvas, Offset(dx, dy));

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(canvasSize.toInt(), canvasSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  /// 작은 점(원형) 마커 비트맵을 생성합니다. 경로를 촘촘히 시각화하는 보조 용도입니다.
  static Future<BitmapDescriptor> createDotMarkerBitmap({
    double diameter = 12.0,
    Color color = Colors.white,
    double alpha = 0.85,
    Color borderColor = Colors.black54,
    double borderWidth = 1.0,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final double radius = diameter / 2.0;
    final Paint fill = Paint()
      ..color = color.withOpacity(alpha)
      ..isAntiAlias = true;
    final Paint stroke = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..isAntiAlias = true;

    canvas.drawCircle(Offset(radius, radius), radius, fill);
    canvas.drawCircle(
        Offset(radius, radius), radius - (borderWidth / 2.0), stroke);

    final ui.Image img = await pictureRecorder
        .endRecording()
        .toImage(diameter.toInt(), diameter.toInt());
    final ByteData? byteData =
        await img.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }
}
