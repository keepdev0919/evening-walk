import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:walk/src/common/widgets/location_name_edit_dialog.dart';
import 'package:walk/src/walk/services/walk_state_manager.dart';
import 'package:walk/src/walk/services/pose_image_service.dart';
import 'package:walk/src/walk/services/walk_session_service.dart';
import 'package:walk/src/walk/services/photo_share_service.dart';
import 'package:walk/src/core/constants/app_constants.dart';
import 'package:walk/src/core/services/log_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:walk/src/walk/services/in_app_map_snapshot_service.dart';
import 'package:walk/src/walk/services/route_snapshot_service.dart';

/// 목적지 도착 후 포즈 추천 화면
class PoseRecommendationScreen extends StatefulWidget {
  final WalkStateManager walkStateManager;

  const PoseRecommendationScreen({
    Key? key,
    required this.walkStateManager,
  }) : super(key: key);

  @override
  State<PoseRecommendationScreen> createState() =>
      _PoseRecommendationScreenState();
}

class _PoseRecommendationScreenState extends State<PoseRecommendationScreen> {
  String? _recommendedPoseImageUrl;
  String? _userPhotoPath;
  bool _isLoadingPose = true;
  bool _isLoadingPhoto = false;
  String? _shareStartAddress;
  String? _shareDestAddress;
  int _remainingRefreshCount = 1; // 남은 새로고침 횟수

  // 공유 기능을 위한 RepaintBoundary Key
  final GlobalKey _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadRecommendedPose();
    _userPhotoPath = widget.walkStateManager.photoPath;
    // 목적지 화면 진입 시 경로 스냅샷이 없다면 미리 생성 시도 (사용자가 즉시 확인 가능)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureRouteSnapshotGenerated();
    });
  }

  /// 추천 포즈 이미지 로드 (기존 포즈가 있으면 재사용)
  Future<void> _loadRecommendedPose() async {
    try {
      setState(() {
        _isLoadingPose = true;
      });

      // 기존에 생성된 포즈 URL이 있는지 확인
      final existingPoseUrl = widget.walkStateManager.poseImageUrl;

      if (existingPoseUrl != null && existingPoseUrl.isNotEmpty) {
        // 기존 포즈 URL 재사용
        LogService.pose('기존 포즈 이미지 재사용: $existingPoseUrl');
        setState(() {
          _recommendedPoseImageUrl = existingPoseUrl;
        });
      } else {
        // 새로운 포즈 이미지 생성
        final selectedMate = widget.walkStateManager.selectedMate ?? '혼자';
        final poseImageUrl =
            await PoseImageService.fetchRandomImageUrl(selectedMate);

        if (poseImageUrl != null) {
          widget.walkStateManager.savePoseImageUrl(poseImageUrl);
          setState(() {
            _recommendedPoseImageUrl = poseImageUrl;
          });
          LogService.pose('새로운 포즈 이미지 생성: $poseImageUrl');
        }
      }
    } catch (e) {
      LogService.error('PoseRecommendation', '포즈 이미지 로드 실패', e);
    } finally {
      setState(() {
        _isLoadingPose = false;
      });
    }
  }

  /// 새로운 추천 포즈 로드 (새로고침)
  Future<void> _refreshRecommendedPose() async {
    if (_remainingRefreshCount <= 0) return;

    try {
      setState(() {
        _isLoadingPose = true;
        _remainingRefreshCount--;
      });

      // 기존 포즈 URL을 무시하고 새로운 포즈 강제 로드
      final selectedMate = widget.walkStateManager.selectedMate ?? '혼자';
      final poseImageUrl =
          await PoseImageService.fetchRandomImageUrl(selectedMate);

      if (poseImageUrl != null) {
        widget.walkStateManager.savePoseImageUrl(poseImageUrl);
        setState(() {
          _recommendedPoseImageUrl = poseImageUrl;
        });
        LogService.pose('새로운 포즈 이미지 로드: $poseImageUrl');
      }
    } catch (e) {
      LogService.error('PoseRecommendation', '포즈 새로고침 실패', e);
      _showErrorSnackBar('새로운 포즈를 불러오는데 실패했습니다. ✨');
    } finally {
      setState(() {
        _isLoadingPose = false;
      });
    }
  }

  /// 사진 촬영
  Future<void> _takePhoto() async {
    setState(() {
      _isLoadingPhoto = true;
    });

    try {
      final photoPath = await widget.walkStateManager.takePhoto();
      if (photoPath != null) {
        widget.walkStateManager.saveAnswerAndPhoto(photoPath: photoPath);
        setState(() {
          _userPhotoPath = photoPath;
        });
      }
    } catch (e) {
      _showErrorSnackBar('사진 촬영에 실패했습니다: $e ✨');
    } finally {
      setState(() {
        _isLoadingPhoto = false;
      });
    }
  }

  /// 사진 재촬영
  Future<void> _retakePhoto() async {
    await _takePhoto();
  }

  /// 사진 삭제
  void _deletePhoto() {
    _showDeleteConfirmDialog(
      title: '사진 삭제',
      content: '촬영한 사진을 삭제하시겠습니까?',
      onConfirm: () {
        widget.walkStateManager.saveAnswerAndPhoto(clearPhoto: true);
        setState(() {
          _userPhotoPath = null;
        });
        _showSuccessSnackBar('사진이 삭제되었습니다.');
      },
    );
  }

  /// 완료 버튼 - 세션 저장 후 출발지 복귀 감지 시작
  Future<void> _onCompletePressed() async {
    try {
      final walkSessionService = WalkSessionService();

      // 1) 세션이 없다면 새로 저장 (소감 제외)
      String? sessionId = widget.walkStateManager.savedSessionId;
      if (sessionId == null) {
        sessionId = await walkSessionService.saveWalkSessionWithoutPhoto(
          walkStateManager: widget.walkStateManager,
          walkReflection: null,
          locationName: widget.walkStateManager.destinationBuildingName,
        );
        if (sessionId != null) {
          widget.walkStateManager.setSavedSessionId(sessionId);
        }
      }

      // 2) 종료 시간/총 시간/총 거리 업데이트 (완료 시점 기준)
      final DateTime endTime = DateTime.now();
      int? totalDuration;
      final start = widget.walkStateManager.actualStartTime;
      if (start != null) {
        totalDuration = endTime.difference(start).inMinutes;
      } else {
        totalDuration = widget.walkStateManager.actualDurationInMinutes;
      }

      if (sessionId != null) {
        await walkSessionService.updateWalkSession(sessionId, {
          'endTime': endTime.toIso8601String(),
          'totalDuration': totalDuration,
          'totalDistance': widget.walkStateManager.accumulatedDistanceKm,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // 3) 홈 화면으로 이동 (스택 제거)
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/homescreen',
          (route) => false,
          arguments: {'showSuccessMessage': '산책이 완료되어 일기에 저장되었습니다. ✨'},
        );
      }
    } catch (e) {
      LogService.error('PoseRecommendation', '완료 처리 중 오류', e);
      if (!mounted) return;
      _showErrorSnackBar('완료 처리 중 오류가 발생했습니다. 다시 시도해주세요. ✨');
    }
  }

  /// 공유하기 - 바로 공유 실행
  Future<void> _onSharePressed() async {
    LogService.share('공유 버튼 클릭 - _userPhotoPath: $_userPhotoPath');
    LogService.share(
        '공유 버튼 클릭 - _recommendedPoseImageUrl: $_recommendedPoseImageUrl');

    final bool hasValidPhoto =
        _userPhotoPath != null && File(_userPhotoPath!).existsSync();
    LogService.share('공유 버튼 클릭 - 유효한 사진 파일 존재: $hasValidPhoto');

    if (_recommendedPoseImageUrl == null && !hasValidPhoto) {
      _showErrorSnackBar('공유할 내용이 없습니다. 포즈 이미지나 사진을 확인해주세요.');
      return;
    }

    // 공유 전에 경로 스냅샷이 없다면 한 번 생성 시도 (in-app 우선 → static maps)
    if (widget.walkStateManager.routeSnapshotPng == null &&
        widget.walkStateManager.startLocation != null &&
        widget.walkStateManager.destinationLocation != null) {
      try {
        Uint8List? png = await InAppMapSnapshotService.captureRouteSnapshot(
          context: context,
          start: widget.walkStateManager.startLocation!,
          waypoint: widget.walkStateManager.waypointLocation,
          destination: widget.walkStateManager.destinationLocation!,
          width: 900,
          height: 600,
        );
        png ??= await RouteSnapshotService.generateRouteSnapshot(
          start: widget.walkStateManager.startLocation!,
          waypoint: widget.walkStateManager.waypointLocation,
          destination: widget.walkStateManager.destinationLocation!,
          width: 900,
          height: 600,
        );
        if (png != null) {
          widget.walkStateManager.saveRouteSnapshot(png);
        }
      } catch (e) {
        LogService.warning('Share', '경로 스냅샷 생성 실패 (무시 가능)');
      }
    }

    // 주소를 먼저 미리 로드하여 캡처 시점에 반영되도록 함
    try {
      _shareStartAddress =
          await widget.walkStateManager.getStartLocationAddress();
      _shareDestAddress =
          await widget.walkStateManager.getDestinationLocationAddress();
    } catch (_) {}

    // 임시로 공유용 위젯을 오프스크린에 렌더링
    await _captureAndShareDirectly();
  }

  /// 경로 스냅샷이 없으면 in-app 캡처 우선 생성 (실패 시 Static Maps)
  Future<void> _ensureRouteSnapshotGenerated() async {
    if (widget.walkStateManager.routeSnapshotPng != null) return;
    if (widget.walkStateManager.startLocation == null ||
        widget.walkStateManager.destinationLocation == null) return;

    try {
      Uint8List? png = await InAppMapSnapshotService.captureRouteSnapshot(
        context: context,
        start: widget.walkStateManager.startLocation!,
        waypoint: widget.walkStateManager.waypointLocation,
        destination: widget.walkStateManager.destinationLocation!,
        width: 900,
        height: 600,
      );
      png ??= await RouteSnapshotService.generateRouteSnapshot(
        start: widget.walkStateManager.startLocation!,
        waypoint: widget.walkStateManager.waypointLocation,
        destination: widget.walkStateManager.destinationLocation!,
        width: 900,
        height: 600,
      );
      if (png != null) {
        widget.walkStateManager.saveRouteSnapshot(png);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  /// 직접 공유하기
  Future<void> _captureAndShareDirectly() async {
    try {
      // 로딩 다이얼로그 표시: 공유 준비 중
      _showBlockingLoadingDialog('공유 준비 중...');

      // 임시 RepaintBoundary를 사용하여 오프스크린 캡처
      final shareWidget = _buildShareContent();

      // 오버레이를 사용하여 화면 밖에서 위젯 렌더링
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -9999, // 화면 밖으로 이동
          top: -9999,
          child: Material(
            color: Colors.transparent,
            child: RepaintBoundary(
              key: _shareKey,
              child: shareWidget,
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);

      // 렌더링이 완료될 때까지 잠시 대기
      await Future.delayed(AppConstants.renderingDelay);

      // 캡처 및 공유
      await PhotoShareService.captureAndShareWidget(
        repaintBoundaryKey: _shareKey,
        customMessage: AppConstants.walkHashtag,
        pixelRatio: 3.0,
      );

      // 오버레이 제거
      overlayEntry.remove();
    } catch (e) {
      _showErrorSnackBar('공유 중 오류가 발생했습니다: $e ✨');
      LogService.error('PoseRecommendation', '공유 오류', e);
    } finally {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  /// 공유 준비/진행 동안 사용자 혼란을 막기 위한 블로킹 로딩 다이얼로그 표시
  void _showBlockingLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: Colors.black.withValues(alpha: 0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white54, width: 1),
            ),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 공유용 콘텐츠 위젯 (워터마크 적용, 해시태그 배지 제거)
  Widget _buildShareContent() {
    return Container(
      width: AppConstants.shareContentWidth,
      height: AppConstants.shareContentHeight, // 9:16 비율
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(AppConstants.backgroundImagePath),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // 은은한 워터마크 (#저녁산책 반복 텍스트), 터치 막음
          IgnorePointer(
            ignoring: true,
            child: Opacity(
              opacity: 0.13,
              child: const CustomPaint(
                painter: _WatermarkPainter(text: '#저녁산책'),
                size: Size.infinite,
              ),
            ),
          ),
          // 상하 그라디언트 + 실제 컨텐츠
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: Column(
                  children: [
                    // 메인 콘텐츠
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // 산책 경로: 좌측 정보(a) + 우측 지도(동일 높이)
                            _buildShareRouteCombinedSection(),

                            const SizedBox(height: 16),

                            // 경유지 질문 (있을 때만)
                            if (widget.walkStateManager.waypointQuestion !=
                                null) ...[
                              _buildWaypointQuestionSection(),
                              const SizedBox(height: 16),
                            ],

                            // 사용자 촬영 사진
                            if (_userPhotoPath != null &&
                                File(_userPhotoPath!).existsSync())
                              _buildShareUserPhotoSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 기존 산책 정보 섹션은 통합 UI로 대체되어 제거했습니다.

  /// 공유용 경로 스냅샷 섹션 (목적지 화면): 산책일기 UI와 동일한 구성
  Widget _buildShareRouteCombinedSection() {
    final png = widget.walkStateManager.routeSnapshotPng;
    final preloadedStart = _shareStartAddress;
    final preloadedDest = _shareDestAddress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목(좌) + 시간/거리(우)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🗺️', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 6),
                  Text(
                    '산책 경로',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              _buildTimeDistanceInfo(),
            ],
          ),
          const SizedBox(height: 16),
          // 좌: 출발지/목적지, 우: 지도 PNG (일기 화면과 동일 배치)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preloadedStart != null)
                      _buildLocationInfo(
                        icon: Icons.home,
                        iconColor: Colors.blue,
                        label: '출발지',
                        address: preloadedStart,
                        isLoading: false,
                        onTap: () {
                          final initial =
                              widget.walkStateManager.customStartName ??
                                  preloadedStart;
                          showLocationNameEditDialog(
                            context: context,
                            title: '출발지 이름 수정',
                            initialValue: initial,
                            onSave: (value) {
                              widget.walkStateManager.setCustomStartName(value);
                              setState(() {
                                _shareStartAddress = null; // 다음 캡처 전 재해결
                              });
                            },
                          );
                        },
                      )
                    else
                      FutureBuilder<String>(
                        future:
                            widget.walkStateManager.getStartLocationAddress(),
                        builder: (context, snapshot) {
                          return _buildLocationInfo(
                            icon: Icons.home,
                            iconColor: Colors.blue,
                            label: '출발지',
                            address: snapshot.data ?? '로딩 중...',
                            isLoading: snapshot.connectionState ==
                                ConnectionState.waiting,
                            onTap: snapshot.connectionState ==
                                    ConnectionState.waiting
                                ? null
                                : () {
                                    final initial = widget
                                            .walkStateManager.customStartName ??
                                        (snapshot.data ?? '');
                                    showLocationNameEditDialog(
                                      context: context,
                                      title: '출발지 이름 수정',
                                      initialValue: initial,
                                      onSave: (value) {
                                        widget.walkStateManager
                                            .setCustomStartName(value);
                                        setState(() {});
                                      },
                                    );
                                  },
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    if (preloadedDest != null)
                      _buildLocationInfo(
                        icon: Icons.flag,
                        iconColor: Colors.red,
                        label: '목적지',
                        address: preloadedDest,
                        isLoading: false,
                        onTap: () {
                          final initial =
                              widget.walkStateManager.destinationBuildingName ??
                                  preloadedDest;
                          showLocationNameEditDialog(
                            context: context,
                            title: '목적지 이름 수정',
                            initialValue: initial,
                            onSave: (value) {
                              widget.walkStateManager
                                  .setDestinationBuildingName(value);
                              setState(() {
                                _shareDestAddress = null; // 다음 캡처 전 재해결
                              });
                            },
                          );
                        },
                      )
                    else
                      FutureBuilder<String>(
                        future: widget.walkStateManager
                            .getDestinationLocationAddress(),
                        builder: (context, snapshot) {
                          return _buildLocationInfo(
                            icon: Icons.flag,
                            iconColor: Colors.red,
                            label: '목적지',
                            address: snapshot.data ?? '로딩 중...',
                            isLoading: snapshot.connectionState ==
                                ConnectionState.waiting,
                            onTap: snapshot.connectionState ==
                                    ConnectionState.waiting
                                ? null
                                : () {
                                    final initial = widget.walkStateManager
                                            .destinationBuildingName ??
                                        (snapshot.data ?? '');
                                    showLocationNameEditDialog(
                                      context: context,
                                      title: '목적지 이름 수정',
                                      initialValue: initial,
                                      onSave: (value) {
                                        widget.walkStateManager
                                            .setDestinationBuildingName(value);
                                        setState(() {});
                                      },
                                    );
                                  },
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (png != null)
                GestureDetector(
                  onTap: () => _showFullScreenRouteSnapshot(png),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      png,
                      width: 180,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 180,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    '경로 이미지를 준비 중...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 전체 화면 경로 스냅샷 보기 (목적지 화면)
  void _showFullScreenRouteSnapshot(Uint8List pngBytes) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                panEnabled: true, // 이동 허용
                scaleEnabled: true, // 확대/축소 허용
                minScale: 0.5, // 최소 축소 비율
                maxScale: 4.0, // 최대 확대 비율
                child: Center(
                  child: Image.memory(
                    pngBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // 상단 컨트롤 바
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 안내 아이콘과 텍스트
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.touch_app,
                        color: Colors.blue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '확대/축소 및 드래그하여 탐색하세요',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 닫기 버튼
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 전체 화면 네트워크 이미지 보기 (추천 포즈)
  void _showFullScreenNetworkImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (c, u) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (c, u, e) => const Center(
                  child: Icon(Icons.error_outline,
                      color: Colors.white70, size: 42),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 개별 구현 제거: 공통 다이얼로그 사용

  /// 위치 정보 카드
  Widget _buildLocationInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          isLoading
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    color: Colors.white.withValues(alpha: 0.7),
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  address,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );

    return onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            child: content,
          );
  }

  /// 경유지 질문 섹션
  Widget _buildWaypointQuestionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              const Text(
                '경유지에서',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.walkStateManager.selectedMate != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _mateEmoji(_normalizedMate(
                            widget.walkStateManager.selectedMate!)),
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _normalizedMate(widget.walkStateManager.selectedMate!),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Q. ${widget.walkStateManager.waypointQuestion}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _normalizedMate(String mate) {
    return mate.startsWith('친구') ? '친구' : mate;
  }

  String _mateEmoji(String mate) {
    switch (mate) {
      case '혼자':
        return '🌙';
      case '연인':
        return '💕';
      case '친구':
        return '👫';
      case '반려견':
        return '🐕';
      default:
        return '🚶';
    }
  }

  /// 공유용 사용자 사진 섹션
  Widget _buildShareUserPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text(
                '목적지에서',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 사진 카드 (목적지 화면과 동일한 테두리/반경 재사용)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(_userPhotoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.black.withValues(alpha: 0.3),
                              child: const Center(
                                child: Text(
                                  '사진을 불러올 수 없습니다',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            );
                          },
                        ),
                        // 살짝 어둡게 보이도록 오버레이 (일관 유지)
                        IgnorePointer(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 시간과 거리 정보 표시
  Widget _buildTimeDistanceInfo() {
    final duration = widget.walkStateManager.actualDurationInMinutes;
    final distance = widget.walkStateManager.accumulatedDistanceKm;

    // 시간과 거리 모두 없으면 빈 위젯
    if (duration == null && distance == null) return const SizedBox.shrink();

    List<Widget> infoWidgets = [];

    // 시간 정보 추가
    if (duration != null) {
      String durationText;
      if (duration <= 0) {
        durationText = '1분 미만';
      } else {
        durationText = '${duration}분';
      }

      infoWidgets.addAll([
        const Icon(Icons.access_time, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          durationText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]);
    }

    // 거리 정보 추가 (시간과 거리 사이에 구분자 추가)
    if (distance != null && infoWidgets.isNotEmpty) {
      infoWidgets.addAll([
        const SizedBox(width: 12),
        const Text('•', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(width: 12),
      ]);
    }

    if (distance != null) {
      String distanceText;
      if (distance < 0.1) {
        distanceText = '0.1km 미만';
      } else {
        distanceText = '${distance.toStringAsFixed(1)}km';
      }

      infoWidgets.addAll([
        const Icon(Icons.directions_walk, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          distanceText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: infoWidgets,
    );
  }

  // 해시태그 배지는 워터마크로 대체되어 제거했습니다.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppConstants.backgroundImagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 어두운 오버레이
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
          // 콘텐츠
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 산책 경로 UI (좌측 정보 a + 우측 지도)
                    _buildShareRouteCombinedSection(),
                    const SizedBox(height: 24),
                    _buildPoseRecommendationSection(),
                    const SizedBox(height: 24),
                    _buildUserPhotoSection(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 앱바 구성
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 24,
          shadows: [
            Shadow(
              blurRadius: 4.0,
              color: Colors.black54,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        '📍 목적지 도착!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              blurRadius: 4.0,
              color: Colors.black54,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white, size: 24),
          tooltip: '도움말',
          onPressed: _showHelpDialog,
        )
      ],
    );
  }

  // 기존 헤더 섹션은 산책 경로 UI로 대체되어 제거했습니다.

  /// 포즈 추천 섹션
  Widget _buildPoseRecommendationSection() {
    return _buildSectionWithAction(
      title: '💫 추천 포즈',
      action: _remainingRefreshCount > 0
          ? GestureDetector(
              onTap: _refreshRecommendedPose,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      color: Colors.blue,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_remainingRefreshCount',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: AppConstants.defaultImageHeightLarge,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: _isLoadingPose
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _recommendedPoseImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GestureDetector(
                          onTap: () => _showFullScreenNetworkImage(
                            _recommendedPoseImageUrl!,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: _recommendedPoseImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.white70, size: 48),
                                      SizedBox(height: 8),
                                      Text(
                                        '이미지를 불러올 수 없습니다',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_camera_outlined,
                                color: Colors.white70, size: 48),
                            SizedBox(height: 8),
                            Text(
                              '추천 포즈를 불러오는 중입니다...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.95),
                Colors.black.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '도움말',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 내용
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildHelpItem(
                      number: '1',
                      title: '위치 수정',
                      description: '출발지와 목적지는 클릭하여 수정할 수 있어요.',
                      icon: Icons.edit_location_alt,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 20),
                    _buildHelpItem(
                      number: '2',
                      title: '포즈 참고',
                      description: '추천 포즈를 참고하여 사진을 찍어보세요.',
                      icon: Icons.camera_alt,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 20),
                    _buildHelpItem(
                      number: '3',
                      title: 'SNS 공유',
                      description: '오늘의 산책 기록을 SNS에 공유해보세요!',
                      icon: Icons.share,
                      color: Colors.pink,
                    ),
                  ],
                ),
              ),

              // 하단 버튼
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.4,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 사용자 촬영 사진 섹션
  Widget _buildUserPhotoSection() {
    return _buildSection(
      title: '📸 내가 찍은 사진',
      content: Column(
        children: [
          Container(
            width: double.infinity,
            height: AppConstants.defaultImageHeightLarge,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: _isLoadingPhoto
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _userPhotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GestureDetector(
                          onTap: () => _showFullScreenPhoto(_userPhotoPath!),
                          child: Image.file(
                            File(_userPhotoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red, size: 48),
                                    SizedBox(height: 8),
                                    Text(
                                      '사진을 불러올 수 없습니다',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _takePhoto,
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox.expand(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: Colors.white70, size: 48),
                                SizedBox(height: 8),
                                Text(
                                  '추천 포즈를 참고해서 사진을 찍어보세요!',
                                  style: TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 16),
          // 사진 관련 버튼들
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 360;

              final Widget primaryButton = ElevatedButton.icon(
                icon: Icon(
                  _userPhotoPath == null
                      ? Icons.camera_alt
                      : Icons.camera_alt_outlined,
                  color: Colors.white,
                ),
                label: Text(
                  _userPhotoPath == null ? '사진 촬영' : '다시 촬영',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                onPressed: _userPhotoPath == null ? _takePhoto : _retakePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );

              final Widget? deleteButton = _userPhotoPath != null
                  ? TextButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white70),
                      label: const Text('삭제',
                          style: TextStyle(color: Colors.white70)),
                      onPressed: _deletePhoto,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 24),
                      ),
                    )
                  : null;

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primaryButton,
                    if (deleteButton != null) ...[
                      const SizedBox(height: 8),
                      deleteButton,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: primaryButton),
                  if (deleteButton != null) ...[
                    const SizedBox(width: 12),
                    deleteButton,
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 액션 버튼들
  Widget _buildActionButtons() {
    return Row(
      children: [
        // 공유하기 버튼
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text(
              '공유하기',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _onSharePressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withValues(alpha: 0.7),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // 완료 버튼
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text(
              '완료',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _onCompletePressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.withValues(alpha: 0.8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 섹션 빌더
  Widget _buildSection({required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  /// 액션 버튼이 있는 섹션 빌더
  Widget _buildSectionWithAction(
      {required String title, required Widget content, Widget? action}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  /// 전체 화면 사진 보기
  void _showFullScreenPhoto(String photoPath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(
                File(photoPath),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white54, width: 1),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.8),
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  /// 성공 스낵바
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        behavior: SnackBarBehavior.floating,
        duration: AppConstants.snackBarDuration,
      ),
    );
  }

  /// 에러 스낵바
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        duration: AppConstants.errorSnackBarDuration,
      ),
    );
  }
}

/// 반복 워터마크 페인터
class _WatermarkPainter extends CustomPainter {
  final String text;
  const _WatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    // Paint 인스턴스는 현재 필요하지 않습니다.
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const double stepX = 160;
    const double stepY = 80;
    const double angle = -0.35; // 라디안 단위 근사 (약 -20도)

    for (double y = -stepY; y < size.height + stepY; y += stepY) {
      for (double x = -stepX; x < size.width + stepX; x += stepX) {
        final span = TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        );
        textPainter.text = span;
        textPainter.layout();

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
