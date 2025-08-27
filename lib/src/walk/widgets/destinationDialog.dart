import 'package:flutter/material.dart';
import 'dart:async';
import 'common_arrival_dialog.dart';
import '../services/interstitial_ad_service.dart';

class DestinationDialog {
  static Future<bool?> showDestinationArrivalDialog({
    required BuildContext context,
  }) {
    return CommonArrivalDialog.show<bool>(
      context: context,
      title: '목적지 도착!',
      icon: Icons.flag,
      iconColor: Colors.red,
      message: '추천포즈를 참고하여 사진을 \n남기고 SNS에 공유해보세요!',
      onEventConfirm: () async {
        // // 전면광고 표시 (미리 로드된 광고 사용)
        // final adService = InterstitialAdService();
        // await adService.showInterstitialAd();
        // // 광고 표시 후 다음 광고 미리 로드
        // unawaited(adService.loadInterstitialAd());

        // 이벤트 확인 시 외부에서 PoseRecommendationScreen으로 이동
      },
      // 목적지 도착 다이얼로그에는 "이벤트 확인" 버튼만 노출
      barrierDismissible: false,
    );
  }
}
