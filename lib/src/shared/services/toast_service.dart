import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 전역 토스트 서비스
class ToastService {
  static final ToastService _instance = ToastService._internal();
  factory ToastService() => _instance;
  ToastService._internal();

  static ToastService get instance => _instance;

  /// 성공 토스트 메시지
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: '✅ $message',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green.withOpacity(0.9),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// 오류 토스트 메시지
  static void showError(String message) {
    Fluttertoast.showToast(
      msg: '❌ $message',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red.withOpacity(0.9),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// 정보 토스트 메시지
  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: '💾 $message',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.blue.withOpacity(0.9),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// 진행 상황 토스트 메시지
  static void showProgress(String message) {
    Fluttertoast.showToast(
      msg: '⏳ $message',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.orange.withOpacity(0.9),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// 일반 토스트 메시지 (커스텀)
  static void show(
    String message, {
    Toast duration = Toast.LENGTH_SHORT,
    ToastGravity gravity = ToastGravity.BOTTOM,
    Color? backgroundColor,
    Color? textColor,
    double fontSize = 16.0,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: duration,
      gravity: gravity,
      backgroundColor: backgroundColor ?? Colors.black87,
      textColor: textColor ?? Colors.white,
      fontSize: fontSize,
    );
  }

  /// 모든 토스트 취소
  static void cancelAll() {
    Fluttertoast.cancel();
  }
}