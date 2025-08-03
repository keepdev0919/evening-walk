import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// 지도에 표시될 사용자 정의 마커 비트맵을 생성하는 유틸리티 클래스입니다.
/// 프로필 이미지, 선물 상자, 깃발 모양의 마커를 생성하는 기능을 제공합니다.
class MapMarkerCreator {
  /// 사용자 프로필 이미지를 사용하여 사용자 정의 마커 비트맵을 생성합니다.
  /// Firebase에서 프로필 이미지 URL을 가져와 마커 아이콘으로 사용합니다.
  static Future<BitmapDescriptor> createCustomProfileMarkerBitmap(User? user) async {
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
        print("Failed to fetch user data for profile marker: $e");
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
        print('Error loading profile image for marker: $e');
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
}
