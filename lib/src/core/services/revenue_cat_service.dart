import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'log_service.dart';

/// RevenueCat을 통한 인앱 구매 관리 서비스
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;
  Offerings? _currentOfferings;

  /// RevenueCat SDK 초기화
  Future<void> initialize() async {
    if (_isInitialized) {
      LogService.debug('RevenueCat', 'Already initialized');
      return;
    }

    try {
      final apiKey = dotenv.env['REVENUE_CAT_PUBLIC_API_KEY'] ?? '';
      if (apiKey.isEmpty || apiKey == 'your_revenuecat_public_api_key_here') {
        LogService.error('RevenueCat', 'RevenueCat API key not configured');
        return;
      }

      // RevenueCat 구성 (v9+ API 사용)
      await Purchases.configure(PurchasesConfiguration(apiKey));

      // 디버그 로그 활성화
      await Purchases.setLogLevel(LogLevel.debug);

      _isInitialized = true;
      LogService.debug('RevenueCat', 'Initialized successfully');

      // 초기 offerings 로드
      await _loadOfferings();
    } catch (e) {
      LogService.error('RevenueCat', 'Failed to initialize: $e');
    }
  }

  /// 사용 가능한 상품 목록 로드
  Future<void> _loadOfferings() async {
    try {
      _currentOfferings = await Purchases.getOfferings();
      if (_currentOfferings?.current != null) {
        LogService.debug('RevenueCat', 
          'Loaded ${_currentOfferings!.current!.availablePackages.length} packages');
      }
    } catch (e) {
      LogService.error('RevenueCat', 'Failed to load offerings: $e');
    }
  }

  /// 현재 사용 가능한 후원 상품 목록 반환
  List<Package> getDonationPackages() {
    if (!_isInitialized || _currentOfferings?.current == null) {
      return [];
    }

    return _currentOfferings!.current!.availablePackages;
  }

  /// 후원 상품 구매 실행
  Future<PurchaseResult> makeDonation(Package package) async {
    if (!_isInitialized) {
      return PurchaseResult.error('RevenueCat이 초기화되지 않았습니다.');
    }

    try {
      LogService.debug('RevenueCat', 'Starting purchase for ${package.storeProduct.identifier}');
      
      final purchaseResult = await Purchases.purchasePackage(package);
      
      // RevenueCat v9에서는 purchaseResult가 CustomerInfo를 포함
      if (purchaseResult.customerInfo.allPurchasedProductIdentifiers.isNotEmpty) {
        LogService.debug('RevenueCat', 'Purchase successful');
        return PurchaseResult.success('후원해주셔서 감사합니다! ☕');
      } else {
        LogService.warning('RevenueCat', 'Purchase completed but no transactions found');
        return PurchaseResult.error('구매가 완료되지 않았습니다.');
      }
    } on PlatformException catch (e) {
      LogService.error('RevenueCat', 'Purchase failed: ${e.message}');
      
      // RevenueCat v9+ 에러 처리
      if (e.code == 'user_cancelled') {
        return PurchaseResult.cancelled();
      } else if (e.code == 'payment_pending') {
        return PurchaseResult.pending('결제가 진행 중입니다.');
      } else if (e.code == 'product_not_available_for_purchase') {
        return PurchaseResult.error('상품을 구매할 수 없습니다.');
      } else if (e.code == 'purchase_not_allowed') {
        return PurchaseResult.error('구매가 허용되지 않습니다.');
      } else {
        return PurchaseResult.error('구매 중 오류가 발생했습니다: ${e.message}');
      }
    } catch (e) {
      LogService.error('RevenueCat', 'Unexpected error during purchase: $e');
      return PurchaseResult.error('예상치 못한 오류가 발생했습니다.');
    }
  }

  /// 구매 복원
  Future<RestoreResult> restorePurchases() async {
    if (!_isInitialized) {
      return RestoreResult.error('RevenueCat이 초기화되지 않았습니다.');
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      LogService.debug('RevenueCat', 'Purchases restored successfully');
      
      return RestoreResult.success(
        '구매 내역이 복원되었습니다.',
        customerInfo.allPurchasedProductIdentifiers.length,
      );
    } catch (e) {
      LogService.error('RevenueCat', 'Failed to restore purchases: $e');
      return RestoreResult.error('구매 복원 중 오류가 발생했습니다.');
    }
  }

  /// 고객 정보 조회
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_isInitialized) return null;

    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      LogService.error('RevenueCat', 'Failed to get customer info: $e');
      return null;
    }
  }

  /// 사용자 ID 설정 (로그인 시)
  Future<void> identifyUser(String userId) async {
    if (!_isInitialized) return;

    try {
      await Purchases.logIn(userId);
      LogService.debug('RevenueCat', 'User identified: $userId');
    } catch (e) {
      LogService.error('RevenueCat', 'Failed to identify user: $e');
    }
  }

  /// 로그아웃 시 사용자 정보 리셋
  Future<void> reset() async {
    if (!_isInitialized) return;

    try {
      await Purchases.logOut();
      LogService.debug('RevenueCat', 'User logged out');
    } catch (e) {
      LogService.error('RevenueCat', 'Failed to log out user: $e');
    }
  }

  /// offerings 새로고침
  Future<void> refreshOfferings() async {
    await _loadOfferings();
  }
}

/// 구매 결과를 나타내는 클래스
class PurchaseResult {
  final bool isSuccess;
  final bool isCancelled;
  final bool isPending;
  final String message;

  const PurchaseResult._(this.isSuccess, this.isCancelled, this.isPending, this.message);

  factory PurchaseResult.success(String message) => 
    PurchaseResult._(true, false, false, message);
  
  factory PurchaseResult.error(String message) => 
    PurchaseResult._(false, false, false, message);
  
  factory PurchaseResult.cancelled() => 
    const PurchaseResult._(false, true, false, '구매가 취소되었습니다.');
  
  factory PurchaseResult.pending(String message) => 
    PurchaseResult._(false, false, true, message);
}

/// 구매 복원 결과를 나타내는 클래스
class RestoreResult {
  final bool isSuccess;
  final String message;
  final int restoredCount;

  const RestoreResult._(this.isSuccess, this.message, this.restoredCount);

  factory RestoreResult.success(String message, int count) => 
    RestoreResult._(true, message, count);
  
  factory RestoreResult.error(String message) => 
    RestoreResult._(false, message, 0);
}