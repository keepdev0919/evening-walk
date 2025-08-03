import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:walk/services/destination_event_handler.dart';
import 'package:walk/services/walk_state_manager.dart';
import 'package:walk/widgets/destination_event_card.dart';

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

  late WalkStateManager _walkStateManager;

  User? _user;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _walkStateManager = WalkStateManager();
    _initializeWalk();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _initializeWalk() async {
    final profileMarker = await _createCustomProfileMarkerBitmap();
    final giftBoxMarker = await _createGiftBoxMarkerBitmap();
    final flagMarker = await _createDestinationMarkerBitmap();

    _walkStateManager.startWalk(
      start: widget.startLocation,
      destination: widget.destinationLocation,
      mate: widget.selectedMate,
    );
    final LatLng? waypoint = _walkStateManager.waypointLocation;

    setState(() {
      _currentPosition = widget.startLocation;
      _currentLocationMarker = Marker(
        markerId: const MarkerId('current_position'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: '현재 위치'),
        icon: profileMarker,
        anchor: const Offset(0.5, 1.0),
      );
      _destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: widget.destinationLocation,
        infoWindow: const InfoWindow(title: '목적지'),
        icon: flagMarker,
        anchor: const Offset(0.5, 1.0),
      );
      if (waypoint != null) {
        _waypointMarker = Marker(
          markerId: const MarkerId('waypoint'),
          position: waypoint,
          infoWindow: const InfoWindow(title: '경유지'),
          icon: giftBoxMarker,
          anchor: const Offset(0.5, 1.0),
        );
      }
      _isLoading = false;
    });

    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    // ... (Permission checks are correct)

    final profileMarker = await _createCustomProfileMarkerBitmap();

    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    )).listen((Position position) {
      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _currentLocationMarker = _currentLocationMarker?.copyWith(
          positionParam: _currentPosition!,
        );
      });

      final String? eventSignal = _walkStateManager.updateUserLocation(_currentPosition!); 
      if (eventSignal != null) {
        if (eventSignal == "destination_reached") {
          _positionStreamSubscription?.cancel();
          _showDestinationCard();
        } else {
          _showQuestionDialog(eventSignal);
        }
      }
    });
  }

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

    final Paint pinPaint = Paint()..color = Colors.blue;
    final Path pinPath = Path();
    pinPath.moveTo(pinSize / 2, pinSize);
    pinPath.quadraticBezierTo(0, pinSize * 0.6, pinSize / 2, pinSize * 0.2);
    pinPath.quadraticBezierTo(pinSize, pinSize * 0.6, pinSize / 2, pinSize);
    canvas.drawPath(pinPath, pinPaint);

    final Paint circlePaint = Paint()..color = Colors.white;
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

  Future<BitmapDescriptor> _createGiftBoxMarkerBitmap() async {
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

    final Paint circlePaint = Paint()..color = Colors.white;
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

  Future<BitmapDescriptor> _createDestinationMarkerBitmap() async {
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

    final Paint circlePaint = Paint()..color = Colors.white;
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showDestinationCard() {
    final question = _walkStateManager.waypointQuestion ?? "오늘 하루는 어떠셨나요?";
    final poseSuggestions = DestinationEventHandler().getPoseSuggestions();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: DestinationEventCard(
            question: question,
            poseSuggestions: poseSuggestions,
            onComplete: (answer, photoPath) {
              _walkStateManager.saveAnswerAndPhoto(answer: answer, photoPath: photoPath);
              Navigator.of(context).pop();
              // TODO: Navigate to results screen
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> allMarkers = {};
    if (_currentLocationMarker != null) allMarkers.add(_currentLocationMarker!);
    if (_destinationMarker != null) allMarkers.add(_destinationMarker!);
    if (_waypointMarker != null) allMarkers.add(_waypointMarker!);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: const Text(
            '산책 중',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition ?? widget.startLocation,
                    zoom: 15.0,
                  ),
                  markers: allMarkers,
                ),
          if (kDebugMode)
            Positioned(
              bottom: 32,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final question = _walkStateManager.waypointQuestion ?? "경유지 질문이 아직 생성되지 않았습니다.";
                      _showQuestionDialog(question);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('경유지 도착', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showDestinationCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('목적지 도착', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}