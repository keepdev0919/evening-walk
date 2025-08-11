import 'package:flutter/material.dart';

/// 전역 토스트 서비스 (ScaffoldMessenger 기반)
class ToastService {
  static final ToastService _instance = ToastService._internal();
  factory ToastService() => _instance;
  ToastService._internal();

  static ToastService get instance => _instance;

  // 현재 컨텍스트를 저장하기 위한 글로벌 키
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  
  static GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey => _scaffoldMessengerKey;

  /// 성공 토스트 메시지
  static void showSuccess(String message) {
    _showCustomToast('✅ $message', const Duration(seconds: 2));
  }

  /// 오류 토스트 메시지
  static void showError(String message) {
    _showCustomToast('❌ $message', const Duration(seconds: 4));
  }

  /// 정보 토스트 메시지
  static void showInfo(String message) {
    _showCustomToast('💾 $message', const Duration(seconds: 2));
  }

  /// 진행 상황 토스트 메시지
  static void showProgress(String message) {
    _showCustomToast('⏳ $message', const Duration(seconds: 2));
  }

  /// 커스텀 토스트 메시지 표시
  static void _showCustomToast(String message, Duration duration) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger != null) {
      scaffoldMessenger.hideCurrentSnackBar(); // 기존 토스트 숨기기
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.0,
              fontFamily: 'Cafe24Oneprettynight',
              fontWeight: FontWeight.normal,
            ),
          ),
          backgroundColor: Colors.black.withOpacity(0.6),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      );
    }
  }

  /// 일반 토스트 메시지 (커스텀)
  static void show(
    String message, {
    Duration? duration,
    Color? backgroundColor,
    Color? textColor,
    double fontSize = 16.0,
  }) {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger != null) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: fontSize,
              fontFamily: 'Cafe24Oneprettynight',
              fontWeight: FontWeight.normal,
            ),
          ),
          backgroundColor: backgroundColor ?? Colors.black.withOpacity(0.6),
          duration: duration ?? const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 90),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      );
    }
  }

  /// 모든 토스트 취소
  static void cancelAll() {
    final scaffoldMessenger = _scaffoldMessengerKey.currentState;
    if (scaffoldMessenger != null) {
      scaffoldMessenger.hideCurrentSnackBar();
    }
  }
}