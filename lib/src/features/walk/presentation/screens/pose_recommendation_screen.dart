import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:walk/src/features/walk/application/services/pose_image_service.dart';
import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:walk/src/features/walk/application/services/photo_share_service.dart';
import 'package:walk/src/core/constants/app_constants.dart';
import 'package:walk/src/core/services/log_service.dart';
import 'dart:io';

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

  // 공유 기능을 위한 RepaintBoundary Key
  final GlobalKey _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadRecommendedPose();
    _userPhotoPath = widget.walkStateManager.photoPath;
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
      _showErrorSnackBar('사진 촬영에 실패했습니다: $e');
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
      // 1차 저장: 현재까지 수집된 모든 정보 저장 (소감 제외)
      final walkSessionService = WalkSessionService();
      final sessionId = await walkSessionService.saveWalkSessionWithoutPhoto(
        walkStateManager: widget.walkStateManager,
        walkReflection: null, // 소감은 나중에 작성
        weatherInfo: AppConstants.defaultWeather, // 기본값
        locationName: widget.walkStateManager
            .destinationBuildingName, // WalkStateManager에서 가져오기
      );

      if (sessionId != null) {
        LogService.info('PoseRecommendation', '1차 산책 세션 저장 완료: $sessionId');
        widget.walkStateManager.setSavedSessionId(sessionId);
      } else {
        LogService.warning('PoseRecommendation', '세션 저장 실패 - 그래도 출발지 복귀 감지 시작');
      }

      // 출발지 복귀 감지 시작
      LogService.event('완료 버튼 클릭 - 출발지 복귀 감지 시작');
      widget.walkStateManager.startReturningHome();

      // 이전 화면(지도)으로 돌아가기
      Navigator.pop(context);

      _showSuccessSnackBar('목적지 이벤트 완료! 출발지로 돌아가세요.');
    } catch (e) {
      LogService.error('PoseRecommendation', '완료 처리 중 오류', e);
      // 오류가 있어도 출발지 복귀는 시작
      widget.walkStateManager.startReturningHome();
      Navigator.pop(context);
      _showErrorSnackBar('일부 오류가 있지만 출발지로 돌아가세요.');
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

    // 임시로 공유용 위젯을 오프스크린에 렌더링
    await _captureAndShareDirectly();
  }

  /// 직접 공유하기
  Future<void> _captureAndShareDirectly() async {
    try {
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
      _showErrorSnackBar('공유 중 오류가 발생했습니다: $e');
      LogService.error('PoseRecommendation', '공유 오류', e);
    }
  }

  /// 공유용 콘텐츠 위젯
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              children: [
                // 상단: 제목
                _buildHashtagSection(),

                const SizedBox(height: 16),

                // 메인 콘텐츠
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // 산책 정보 (출발지, 목적지)
                        _buildWalkInfoSection(),

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
    );
  }

  /// 산책 정보 섹션 (출발지, 목적지)
  Widget _buildWalkInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 왼쪽: 산책 경로 제목
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
              // 오른쪽: 시간/거리 정보
              _buildTimeDistanceInfo(),
            ],
          ),
          const SizedBox(height: 12),

          // 출발지, 목적지 2열 배치
          Row(
            children: [
              // 출발지
              Expanded(
                child: FutureBuilder<String>(
                  future: widget.walkStateManager.getStartLocationAddress(),
                  builder: (context, snapshot) {
                    return _buildLocationInfo(
                      icon: Icons.home,
                      iconColor: Colors.blue,
                      label: '출발지',
                      address: snapshot.data ?? '로딩 중...',
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              // 목적지
              Expanded(
                child: FutureBuilder<String>(
                  future:
                      widget.walkStateManager.getDestinationLocationAddress(),
                  builder: (context, snapshot) {
                    return _buildLocationInfo(
                      icon: Icons.flag,
                      iconColor: Colors.red,
                      label: '목적지',
                      address: snapshot.data ?? '로딩 중...',
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 위치 정보 카드
  Widget _buildLocationInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
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
                    color: Colors.white.withOpacity(0.7),
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  address,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
  }

  /// 경유지 질문 섹션
  Widget _buildWaypointQuestionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.orange, size: 18),
              SizedBox(width: 6),
              Text(
                '경유지에서',
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

  /// 공유용 사용자 사진 섹션
  Widget _buildShareUserPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_userPhotoPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Text(
                        '사진을 불러올 수 없습니다',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 시간/거리 정보 표시
  Widget _buildTimeDistanceInfo() {
    final duration = widget.walkStateManager.actualDurationInMinutes;
    final distance = widget.walkStateManager.walkDistance;

    // 둘 다 null이면 빈 위젯 반환
    if (duration == null && distance == null) {
      return const SizedBox.shrink();
    }

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

    // 거리 정보 추가
    if (distance != null) {
      if (infoWidgets.isNotEmpty) {
        infoWidgets.addAll([
          const SizedBox(width: 12),
          Text(
            '•',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
        ]);
      }

      infoWidgets.addAll([
        const Icon(Icons.straighten, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          '${distance.round()}m',
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

  /// 해시태그 섹션
  Widget _buildHashtagSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
      ),
      child: const Text(
        AppConstants.walkHashtag,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

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
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.7),
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
                    _buildHeader(),
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
    );
  }

  /// 헤더 섹션
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white54, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '🎉',
            style: TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 8),
          const Text(
            '목적지 도착 완료!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '추천 포즈로 멋진 사진을 남기고 \n친구들과 공유해보세요',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 포즈 추천 섹션
  Widget _buildPoseRecommendationSection() {
    return _buildSection(
      title: '💫 추천 포즈',
      content: Container(
        width: double.infinity,
        height: AppConstants.defaultImageHeightLarge,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: _isLoadingPose
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _recommendedPoseImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: _recommendedPoseImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Center(
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
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                    : const Center(
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
                  backgroundColor: Colors.blue.withOpacity(0.8),
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
              backgroundColor: Colors.blue.withOpacity(0.7),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.withOpacity(0.3)),
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
              backgroundColor: Colors.green.withOpacity(0.8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green.withOpacity(0.3)),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
          backgroundColor: Colors.black.withOpacity(0.9),
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
                backgroundColor: Colors.red.withOpacity(0.8),
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
        content: Text(message),
        backgroundColor: Colors.green.withOpacity(0.8),
        duration: AppConstants.snackBarDuration,
      ),
    );
  }

  /// 에러 스낵바
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.withOpacity(0.8),
        duration: AppConstants.errorSnackBarDuration,
      ),
    );
  }
}
