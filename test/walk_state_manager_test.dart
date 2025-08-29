import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk/src/walk/services/walk_state_manager.dart';

void main() {
  group('WalkStateManager Tests', () {
    late WalkStateManager walkStateManager;

    setUp(() {
      walkStateManager = WalkStateManager();
    });

    test('should initialize walk with valid coordinates', () async {
      // Arrange
      const startLocation = LatLng(37.5665, 126.9780); // 서울시청
      const destinationLocation = LatLng(37.5658, 126.9822); // 덕수궁
      const selectedMate = '혼자';

      // Act
      await walkStateManager.startWalk(
        startLocation: startLocation,
        destinationLocation: destinationLocation,
        selectedMate: selectedMate,
      );

      // Assert
      expect(walkStateManager.startLocation, equals(startLocation));
      expect(walkStateManager.destinationLocation, equals(destinationLocation));
      expect(walkStateManager.selectedMate, equals(selectedMate));
      expect(walkStateManager.actualStartTime, isNotNull);
      expect(walkStateManager.waypointLocation, isNotNull);
    });

    test('should throw error for invalid start location', () async {
      // Arrange
      const invalidStartLocation = LatLng(91.0, 0.0); // 위도 범위 초과
      const validDestinationLocation = LatLng(37.5658, 126.9822);
      const selectedMate = '혼자';

      // Act & Assert
      expect(
        () async => await walkStateManager.startWalk(
          startLocation: invalidStartLocation,
          destinationLocation: validDestinationLocation,
          selectedMate: selectedMate,
        ),
        throwsArgumentError,
      );
    });

    test('should throw error for empty mate selection', () async {
      // Arrange
      const startLocation = LatLng(37.5665, 126.9780);
      const destinationLocation = LatLng(37.5658, 126.9822);
      const emptyMate = '';

      // Act & Assert
      expect(
        () async => await walkStateManager.startWalk(
          startLocation: startLocation,
          destinationLocation: destinationLocation,
          selectedMate: emptyMate,
        ),
        throwsArgumentError,
      );
    });

    test('should save answer and photo correctly', () {
      // Arrange
      const testAnswer = '테스트 답변';
      const testPhotoPath = '/path/to/test/photo.jpg';

      // Act
      walkStateManager.saveUserAnswerAndPhoto(
        answer: testAnswer,
        photoPath: testPhotoPath,
      );

      // Assert
      expect(walkStateManager.userAnswer, equals(testAnswer));
      expect(walkStateManager.photoPath, equals(testPhotoPath));
    });

    test('should clear answer when clearAnswer flag is true', () {
      // Arrange
      const testAnswer = '테스트 답변';
      walkStateManager.saveUserAnswerAndPhoto(answer: testAnswer);

      // Act
      walkStateManager.saveUserAnswerAndPhoto(clearAnswer: true);

      // Assert
      expect(walkStateManager.userAnswer, isNull);
    });

    test('should calculate walk distance correctly', () async {
      // Arrange
      const startLocation = LatLng(37.5665, 126.9780); // 서울시청
      const destinationLocation = LatLng(37.5658, 126.9822); // 덕수궁
      
      await walkStateManager.startWalk(
        startLocation: startLocation,
        destinationLocation: destinationLocation,
        selectedMate: '혼자',
      );

      // Act
      final distance = walkStateManager.walkDistance;

      // Assert
      expect(distance, isNotNull);
      expect(distance! > 0, isTrue);
      // 서울시청에서 덕수궁까지 약 400-500m 정도
      expect(distance < 1000, isTrue);
    });

    test('should validate location coordinates correctly', () {
      // Valid coordinates
      expect(() => walkStateManager.startWalk(
        startLocation: const LatLng(37.5665, 126.9780),
        destinationLocation: const LatLng(37.5658, 126.9822),
        selectedMate: '혼자',
      ), returnsNormally);

      // Invalid latitude (> 90)
      expect(() => walkStateManager.startWalk(
        startLocation: const LatLng(91.0, 126.9780),
        destinationLocation: const LatLng(37.5658, 126.9822),
        selectedMate: '혼자',
      ), throwsArgumentError);

      // Invalid longitude (> 180)
      expect(() => walkStateManager.startWalk(
        startLocation: const LatLng(37.5665, 181.0),
        destinationLocation: const LatLng(37.5658, 126.9822),
        selectedMate: '혼자',
      ), throwsArgumentError);

      // Zero coordinates (invalid for this app)
      expect(() => walkStateManager.startWalk(
        startLocation: const LatLng(0.0, 0.0),
        destinationLocation: const LatLng(37.5658, 126.9822),
        selectedMate: '혼자',
      ), throwsArgumentError);
    });
  });
}