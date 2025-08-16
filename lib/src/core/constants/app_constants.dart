import 'package:flutter/material.dart';

/// 애플리케이션 전체에서 사용되는 상수들
class AppConstants {
  // === 거리 관련 상수 ===
  static const double maxWalkDistance = 1200.0; // 미터
  static const double waypointTriggerDistance = 50.0; // 미터
  static const double destinationTriggerDistance = 50.0; // 미터
  static const double startReturnTriggerDistance = 50.0; // 미터

  // === UI 크기 상수 ===
  static const double shareContentWidth = 400.0;
  static const double shareContentHeight = 750.0; // 9:16 비율
  static const double defaultImageHeight = 280.0;
  static const double defaultImageHeightLarge = 250.0;

  // === 애니메이션 및 타이밍 ===
  static const Duration renderingDelay = Duration(milliseconds: 100);
  static const Duration debugAutoCompleteDelay = Duration(seconds: 3);
  static const Duration snackBarDuration = Duration(seconds: 2);
  static const Duration errorSnackBarDuration = Duration(seconds: 3);

  // === 텍스트 상수 ===
  static const String defaultWeather = "맑음";
  static const String unknownLocation = "알 수 없는 위치";
  static const String walkHashtag = "#저녁산책";
  static const String shareDefaultMessage = "오늘의 산책 기록";

  // === 이미지 경로 ===
  static const String backgroundImagePath = 'assets/images/nature_walk.jpg';
}

/// 색상 관련 상수들
class AppColors {
  // === 투명도가 있는 색상들 ===
  static final Color backgroundOverlay = Colors.black.withValues(alpha: 0.6);
  static final Color backgroundOverlayLight =
      Colors.black.withValues(alpha: 0.3);
  static final Color backgroundOverlayDark =
      Colors.black.withValues(alpha: 0.7);
  static final Color backgroundOverlayVeryDark =
      Colors.black.withValues(alpha: 0.8);
  static final Color backgroundOverlayTransparent =
      Colors.black.withValues(alpha: 0.5);

  static final Color whiteOverlay = Colors.white.withValues(alpha: 0.2);
  static final Color whiteOverlayLight = Colors.white.withValues(alpha: 0.05);
  static final Color whiteOverlayMedium = Colors.white.withValues(alpha: 0.4);
  static final Color whiteOverlayStrong = Colors.white.withValues(alpha: 0.9);

  static final Color blueOverlay = Colors.blue.withValues(alpha: 0.7);
  static final Color blueOverlayStrong = Colors.blue.withValues(alpha: 0.8);
  static final Color blueOverlayLight = Colors.blue.withValues(alpha: 0.3);

  static final Color greenOverlay = Colors.green.withValues(alpha: 0.8);
  static final Color greenOverlayLight = Colors.green.withValues(alpha: 0.3);

  // === 그라데이션 ===
  static final LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      backgroundOverlayLight,
      backgroundOverlay,
    ],
  );

  static final LinearGradient backgroundGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      backgroundOverlayLight,
      backgroundOverlayDark,
    ],
  );
}

/// 스타일 관련 상수들
class AppStyles {
  // === 카드 데코레이션 ===
  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.whiteOverlayLight,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.whiteOverlay),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  static BoxDecoration buttonDecoration = BoxDecoration(
    color: AppColors.backgroundOverlay,
    borderRadius: BorderRadius.circular(25),
    border: Border.all(color: AppColors.whiteOverlayMedium, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  static BoxDecoration circleButtonDecoration = BoxDecoration(
    color: AppColors.backgroundOverlay,
    shape: BoxShape.circle,
  );

  // === 텍스트 스타일 ===
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
  );

  static const TextStyle headerStyle = TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static TextStyle bodyStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.9),
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}
