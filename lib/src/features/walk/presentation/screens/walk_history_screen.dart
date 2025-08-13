import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/domain/models/walk_session.dart';
import 'package:walk/src/features/walk/application/services/walk_session_service.dart';
import 'package:walk/src/features/walk/presentation/widgets/walk_history_item_widget.dart';
import 'package:walk/src/features/walk/presentation/screens/walk_diary_screen.dart';
import 'package:walk/src/features/walk/application/services/walk_state_manager.dart';
import 'package:geolocator/geolocator.dart';

/// 산책 기록 목록을 보여주는 화면
class WalkHistoryScreen extends StatefulWidget {
  const WalkHistoryScreen({Key? key}) : super(key: key);

  @override
  State<WalkHistoryScreen> createState() => _WalkHistoryScreenState();
}

class _WalkHistoryScreenState extends State<WalkHistoryScreen> {
  final WalkSessionService _walkSessionService = WalkSessionService();
  List<WalkSession> _walkSessions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 필터 상태
  String _selectedMateFilter = '전체';
  List<String> _availableMateFilters = ['전체'];

  @override
  void initState() {
    super.initState();
    _loadWalkSessions();
  }

  /// 산책 세션 목록 로드
  Future<void> _loadWalkSessions() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final sessions = await _walkSessionService
          .getUserWalkSessions(); // limit 제거하여 모든 데이터 가져오기

      setState(() {
        _walkSessions = sessions;
        _updateAvailableMateFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '산책 기록을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  /// 사용 가능한 메이트 필터 업데이트
  void _updateAvailableMateFilters() {
    // 실제 기록이 있는 메이트 종류만 추출
    final uniqueMates =
        _walkSessions.map((session) => session.selectedMate).toSet().toList();

    // '전체'를 맨 앞에 추가하고 나머지는 정렬
    _availableMateFilters = ['전체', ...uniqueMates];

    // 현재 선택된 필터가 사용 가능한 필터에 없으면 '전체'로 변경
    if (!_availableMateFilters.contains(_selectedMateFilter)) {
      _selectedMateFilter = '전체';
    }
  }

  /// 필터된 산책 세션 목록 반환
  List<WalkSession> get _filteredWalkSessions {
    if (_selectedMateFilter == '전체') {
      return _walkSessions;
    }
    return _walkSessions
        .where((session) => session.selectedMate == _selectedMateFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // body를 AppBar 뒤까지 확장
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nature_walk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 콘텐츠
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(),
            body: SafeArea(
              child: Column(
                children: [
                  _buildStatisticsHeader(),
                  // 필터 탭과 목록 사이에 상하 여백을 충분히 둬서 드래그 시 겹쳐 보이지 않도록 완충 간격 추가
                  _buildFilterTabs(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildWalkSessionsList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 앱바 구성 - 감성적 스타일
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        '산책 기록',
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
      leading: IconButton(
        icon: const Icon(
          Icons.home,
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
        onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
          '/homescreen',
          (route) => false,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.refresh,
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
          onPressed: _loadWalkSessions,
        ),
      ],
    );
  }

  /// 통계 헤더 위젯
  Widget _buildStatisticsHeader() {
    final totalSessions = _walkSessions.length;
    final totalDuration = _walkSessions.fold<int>(
        0, (sum, session) => sum + (session.durationInMinutes ?? 0));
    final totalDistance = _walkSessions.fold<double>(0, (sum, session) {
      return sum + _sessionDistanceKm(session);
    });

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // 다이얼로그 스타일 참고한 반투명 검정 배경
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white54,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            emoji: '🚶‍♀️',
            label: '총 산책',
            value: '$totalSessions번',
          ),
          _buildStatItem(
            emoji: '⏰',
            label: '총 시간',
            value: '${totalDuration}분',
          ),
          _buildStatItem(
            emoji: '👣',
            label: '총 거리',
            value: '${totalDistance.toStringAsFixed(1)}km',
          ),
        ],
      ),
    );
  }

  /// 세션별 거리(km): 저장된 실제 이동거리 우선, 없으면 출발지→목적지 직선거리로 대체
  double _sessionDistanceKm(WalkSession session) {
    if (session.totalDistance != null) return session.totalDistance!;
    final meters = Geolocator.distanceBetween(
      session.startLocation.latitude,
      session.startLocation.longitude,
      session.destinationLocation.latitude,
      session.destinationLocation.longitude,
    );
    return meters / 1000.0;
  }

  /// 통계 항목 위젯 - 감성적 스타일
  Widget _buildStatItem({
    required String emoji,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                blurRadius: 2.0,
                color: Colors.black54,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                blurRadius: 2.0,
                color: Colors.black54,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 필터 탭 위젯 - 동적 필터 + 가로 스크롤
  Widget _buildFilterTabs() {
    if (_availableMateFilters.length <= 1) {
      // 필터가 '전체'만 있으면 필터 탭을 표시하지 않음
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), // iOS 스타일 스크롤
        itemCount: _availableMateFilters.length,
        itemBuilder: (context, index) {
          final filter = _availableMateFilters[index];
          final isSelected = _selectedMateFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedMateFilter = filter;
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                right: index < _availableMateFilters.length - 1 ? 12 : 16,
                left: index == 0 ? 0 : 0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.8)
                    : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.white54,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getMateEmoji(filter),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        shadows: [
                          Shadow(
                            blurRadius: 2.0,
                            color: Colors.black54,
                            offset: const Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 메이트별 이모지 반환
  String _getMateEmoji(String mate) {
    switch (mate) {
      case '전체':
        return '🌟';
      case '혼자':
        return '🌙';
      case '연인':
        return '💕';
      case '친구':
        return '👫';
      default:
        return '🚶'; // 기본 걷기
    }
  }

  /// 산책 세션 목록 위젯
  Widget _buildWalkSessionsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWalkSessions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withValues(alpha: 0.8),
              ),
              child: const Text('다시 시도', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final filteredSessions = _filteredWalkSessions;

    if (filteredSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_walk_outlined,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedMateFilter == '전체'
                  ? '아직 산책 기록이 없습니다'
                  : '해당 필터의 산책 기록이 없습니다',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '첫 산책을 시작해보세요!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWalkSessions,
      color: Colors.blue,
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 20),
        itemCount: filteredSessions.length,
        itemBuilder: (context, index) {
          final session = filteredSessions[index];
          return WalkHistoryItemWidget(
            walkSession: session,
            onTap: () => _showWalkSessionDetail(session),
            onDelete: () => _deleteWalkSession(session),
          );
        },
      ),
    );
  }

  /// 산책 세션 상세보기 (기존 다이얼로그 재활용)
  void _showWalkSessionDetail(WalkSession session) {
    // WalkStateManager를 세션 데이터로 초기화
    final walkStateManager = WalkStateManager();

    // 세션 데이터를 WalkStateManager에 설정
    // 좌표 복원: 저장된 경로가 그대로 보이도록 주입
    walkStateManager.setLocationsForRestore(
      start: session.startLocation,
      waypoint: session.waypointLocation,
      destination: session.destinationLocation,
    );
    // 목적지 표시명 복원 (있을 경우 주소보다 우선 표시)
    if (session.locationName != null && session.locationName!.isNotEmpty) {
      walkStateManager.setDestinationBuildingName(session.locationName);
    }
    walkStateManager.setWaypointQuestion(session.waypointQuestion);
    walkStateManager.saveAnswerAndPhoto(
      answer: session.waypointAnswer,
      photoPath: session.takenPhotoPath,
    );
    walkStateManager.saveReflection(session.walkReflection);
    // 세션에 저장된 추천 포즈 URL도 매니저에 주입하여 기록 보기에서 동일 이미지를 표시
    walkStateManager.savePoseImageUrl(session.poseImageUrl);

    // 편집 가능 모드로 페이지 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkDiaryScreen(
          walkStateManager: walkStateManager,
          isViewMode: false, // 편집 가능 모드로 변경
          sessionId: session.id, // 업로드 상태 연동
          selectedMate: session.selectedMate, // 추천 포즈 로딩용
          returnRoute: '/walk_history', // 산책 기록 화면으로 돌아가도록 설정
          onWalkCompleted: (completed) {
            // 수정 완료 후 목록 새로고침
            if (completed) {
              _loadWalkSessions();
            }
          },
        ),
      ),
    );
  }

  /// 산책 세션 삭제
  Future<void> _deleteWalkSession(WalkSession session) async {
    try {
      // 삭제 진행 중 로딩 표시
      setState(() {
        _isLoading = true;
      });

      final success = await _walkSessionService.deleteWalkSession(session.id);

      if (success) {
        // 삭제 성공 시 목록에서 제거
        setState(() {
          _walkSessions.removeWhere((s) => s.id == session.id);
          _updateAvailableMateFilters(); // 필터 업데이트
          _isLoading = false;
        });

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Text('✅', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text('산책 기록이 삭제되었습니다.'),
                ],
              ),
              backgroundColor: Colors.black.withOpacity(0.6),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 삭제 실패 시
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Text('❌', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Expanded(child: Text('삭제에 실패했습니다. 다시 시도해주세요.')),
                ],
              ),
              backgroundColor: Colors.black.withOpacity(0.6),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('삭제 중 오류가 발생했습니다: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.black.withOpacity(0.6),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
