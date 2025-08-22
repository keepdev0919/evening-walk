import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 전면광고 관리를 위한 서비스 (싱글톤)
class InterstitialAdService {
  static final InterstitialAdService _instance = InterstitialAdService._internal();
  factory InterstitialAdService() => _instance;
  InterstitialAdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  /// 전면광고 로드
  Future<void> loadInterstitialAd() async {
    try {
      await InterstitialAd.load(
        adUnitId: _getAdUnitId(),
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _isAdLoaded = true;
            print('전면광고 로드 완료');
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('전면광고 로드 실패: $error');
            _isAdLoaded = false;
          },
        ),
      );
    } catch (e) {
      print('전면광고 로드 중 오류: $e');
      _isAdLoaded = false;
    }
  }

  /// 전면광고 표시
  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null && _isAdLoaded) {
      try {
        await _interstitialAd!.show();
        _isAdLoaded = false;
        _disposeAd();
      } catch (e) {
        print('전면광고 표시 중 오류: $e');
      }
    } else {
      print('전면광고가 로드되지 않음');
    }
  }

  /// 광고 해제
  void _disposeAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  /// AdMob ID 반환 (테스트용 광고 단위 ID 사용)
  String _getAdUnitId() {
    // 테스트용 광고 ID - AdMob 계정 승인 후 실제 ID로 변경 필요
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // 테스트용 Android 전면광고
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // 테스트용 iOS 전면광고
    }
    return '';
  }

  /// 서비스 해제
  void dispose() {
    _disposeAd();
  }
}
