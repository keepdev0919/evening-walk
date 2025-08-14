import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'log_service.dart';

/// 개발자에게 연락하는 기능을 제공하는 서비스 클래스
class ContactDeveloperService {
  static const String _developerEmail =
      'keepdev0919@gmail.com'; // 실제 개발자 이메일로 변경 필요

  /// 이메일 앱을 통해 개발자에게 연락
  static Future<bool> contactDeveloper({
    required String subject,
    required String body,
    String? userInfo,
  }) async {
    try {
      LogService.info('SERVICE', 'ContactDeveloperService: 개발자 연락 시작');

      // 이메일 본문 구성
      String emailBody = body;
      if (userInfo != null && userInfo.isNotEmpty) {
        emailBody += '\n\n--- 사용자 정보 ---\n$userInfo';
      }

      // mailto URL 구성
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: _developerEmail,
        queryParameters: {
          'subject': subject,
          'body': emailBody,
        },
      );

      LogService.debug('SERVICE', 'ContactDeveloperService: 이메일 URI 생성 완료');

      // URL 실행 가능성 확인
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        LogService.info('SERVICE', 'ContactDeveloperService: 이메일 앱 실행 성공');
        return true;
      } else {
        LogService.warning(
            'SERVICE', 'ContactDeveloperService: 이메일 앱을 실행할 수 없음');
        return false;
      }
    } catch (e) {
      LogService.error('SERVICE', 'ContactDeveloperService: 이메일 실행 실패', e);
      return false;
    }
  }

  /// 기기 정보를 수집하여 문자열로 반환
  static String getDeviceInfo() {
    try {
      // 기본적인 플랫폼 정보만 수집 (개인정보 보호)
      return '앱: 저녁산책\n플랫폼: Flutter';
    } catch (e) {
      LogService.error('SERVICE', 'ContactDeveloperService: 기기 정보 수집 실패', e);
      return '기기 정보를 수집할 수 없습니다.';
    }
  }

  /// 빠른 버그 신고
  static Future<bool> reportBug(String description) async {
    return await contactDeveloper(
      subject: '[저녁산책] 버그 신고',
      body: '버그 내용:\n$description',
      userInfo: getDeviceInfo(),
    );
  }

  /// 기능 제안
  static Future<bool> suggestFeature(String suggestion) async {
    return await contactDeveloper(
      subject: '[저녁산책] 기능 제안',
      body: '제안 내용:\n$suggestion',
      userInfo: getDeviceInfo(),
    );
  }

  /// 일반 문의
  static Future<bool> generalInquiry(String message) async {
    return await contactDeveloper(
      subject: '[저녁산책] 문의사항',
      body: '문의 내용:\n$message',
      userInfo: getDeviceInfo(),
    );
  }
}
