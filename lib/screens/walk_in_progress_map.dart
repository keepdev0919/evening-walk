import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:walk/services/walk_event_manager.dart';

class WalkInProgressMapScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng destinationLocation;
  final String selectedMate;

  const WalkInProgressMapScreen({
    Key? key,
    required this.startLocation,
    required this.destinationLocation,
    required this.selectedMate,
  }) : super(key: key);

  @override
  State<WalkInProgressMapScreen> createState() =>
      _WalkInProgressMapScreenState();
}

class _WalkInProgressMapScreenState extends State<WalkInProgressMapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  bool _isLoading = true;

  Marker? _currentLocationMarker;
  Marker? _destinationMarker;
  Marker? _waypointMarker;

  late WalkEventManager _walkEventManager;

  User? _user; // Firebase 사용자

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser; // 현재 사용자 정보 가져오기
    _walkEventManager = WalkEventManager();
    _initializeWalk();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _initializeWalk() async {
    // 커스텀 마커 생성
    final BitmapDescriptor profileMarker =
        await _createCustomProfileMarkerBitmap();
    final BitmapDescriptor giftBoxMarker = await _createGiftBoxMarkerBitmap();
    final BitmapDescriptor flagMarker = await _createDestinationMarkerBitmap();

    _walkEventManager.startWalk(
      start: widget.startLocation,
      destination: widget.destinationLocation,
      mate: widget.selectedMate,
    );
    final LatLng? waypoint = _walkEventManager.getWaypoint();

    setState(() {
      _currentPosition = widget.startLocation;
      _currentLocationMarker = Marker(
        markerId: const MarkerId('current_position'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: '현재 위치'),
        icon: profileMarker, // 사용자 프로필 마커 적용
        anchor: const Offset(0.5, 1.0), // 핀의 아래쪽 끝에 앵커
      );
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: widget.destinationLocation,
        infoWindow: const InfoWindow(title: '목적지'),
        icon: flagMarker, // 목적지 마커 적용
        anchor: const Offset(0.5, 1.0), // 핀의 아래쪽 끝에 앵커
      );
      if (waypoint != null) {
        _waypointMarker = Marker(
          markerId: const MarkerId('waypoint'),
          position: waypoint,
          infoWindow: const InfoWindow(title: '경유지'),
          icon: giftBoxMarker, // 선물상자 마커 적용
          anchor: const Offset(0.5, 1.0), // 핀의 아래쪽 끝에 앵커
        );
      }
      _isLoading = false;
    });

    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // 사용자 프로필 마커를 다시 생성하여 현재 위치에 적용
    final BitmapDescriptor profileMarker =
        await _createCustomProfileMarkerBitmap();

    Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    )).listen((Position position) async {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _currentLocationMarker = Marker(
          markerId: const MarkerId('current_position'),
          position: _currentPosition!,
          infoWindow: const InfoWindow(title: '현재 위치'),
          icon: profileMarker, // 사용자 프로필 마커 적용
          anchor: const Offset(0.5, 1.0),
        );
      });
      final String? question =
          await _walkEventManager.checkWaypointArrival(_currentPosition!);
      if (question != null) {
        _showQuestionDialog(question);
      }
    });
  }

  // --- 커스텀 마커 생성 함수들 ---

  /// 사용자 프로필 이미지를 포함한 커스텀 마커를 생성합니다.
  Future<BitmapDescriptor> _createCustomProfileMarkerBitmap() async {
    String? imageUrl;
    if (_user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
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

    // 핀 모양 그리기
    final Paint pinPaint = Paint()..color = Colors.blue;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    // 아바타 배경 흰색 원 그리기
    final Paint circlePaint = Paint()..color = Colors.white;
    canvas.drawCircle(
        const Offset(pinSize / 2, pinSize / 2), avatarRadius + 5, circlePaint);

    // 아바타 이미지 로드 및 그리기
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

    // 아바타를 원형으로 클리핑
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

  /// 선물상자 아이콘을 포함한 커스텀 마커를 생성합니다.
  Future<BitmapDescriptor> _createGiftBoxMarkerBitmap() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double pinSize = 150.0; // 마커 전체 크기
    const double iconSize = 60.0; // 아이콘 크기

    // 핀 모양 그리기 (주황색)
    final Paint pinPaint = Paint()..color = Colors.orange;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    // 아이콘 배경 원 그리기 (흰색) - 핀 위에 위치하도록 조정 (출발지 마커와 통일)
    final Paint circlePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(pinSize / 2, pinSize / 2.5),
        (iconSize / 1.2) + 5, circlePaint);

    // 아이콘 그리기 (선물상자) - 핀 위에 위치하도록 조정 (출발지 마커와 통일)
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.card_giftcard.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.card_giftcard.fontFamily,
          color: Colors.orange, // 아이콘 색상
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
          (pinSize - textPainter.width) / 2,
          (pinSize / 2.5) - (textPainter.height / 2), // 아이콘을 원의 중앙에 맞춤
        ));

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  /// 목적지 아이콘을 포함한 커스텀 마커를 생성합니다.
  Future<BitmapDescriptor> _createDestinationMarkerBitmap() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double pinSize = 150.0; // 마커 전체 크기 (출발지 마커와 통일)
    const double iconSize = 60.0; // 아이콘 크기

    // 핀 모양 그리기 (빨간색)
    final Paint pinPaint = Paint()..color = Colors.red;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    // 아이콘 배경 원 그리기 (흰색) - 핀 위에 위치하도록 조정 (출발지 마커와 통일)
    final Paint circlePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(pinSize / 2, pinSize / 2.5),
        (iconSize / 1.2) + 5, circlePaint);

    // 아이콘 그리기 (깃발) - 핀 위에 위치하도록 조정 (출발지 마커와 통일)
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.flag.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.flag.fontFamily,
          color: Colors.red, // 아이콘 색상
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
          (pinSize - textPainter.width) / 2,
          (pinSize / 2.5) - (textPainter.height / 2), // 아이콘을 원의 중앙에 맞춤
        ));

    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(pinSize.toInt(), pinSize.toInt());
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  void _showQuestionDialog(String question) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          title: const Text(
            '산책 메이트의 질문',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            question,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white54, width: 0.5),
                ),
                elevation: 0,
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> allMarkers = {};
    if (_currentLocationMarker != null) {
      allMarkers.add(_currentLocationMarker!);
    }
    if (_destinationMarker != null) {
      allMarkers.add(_destinationMarker!);
    }
    if (_waypointMarker != null) {
      allMarkers.add(_waypointMarker!);
    }

    return Scaffold(
      extendBodyBehindAppBar: true, // body를 AppBar 뒤까지 확장
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 배경색 투명
        elevation: 0, // 그림자 제거
        leading: Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: const Text(
            '산책 중',
            style: TextStyle(color: Colors.black87, fontSize: 16),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 15.0,
              ),
              markers: allMarkers,
            ),
    );
  }
}
