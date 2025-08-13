import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:walk/src/core/services/log_service.dart';

/// 배경 영상을 재생하는 위젯
/// 자동으로 루프 재생되며, 음소거 상태로 재생됩니다.
class VideoBackground extends StatefulWidget {
  final String videoPath;
  final Widget? child;

  const VideoBackground({
    super.key,
    required this.videoPath,
    this.child,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset(widget.videoPath);
      
      // 초기화 전에 에러 리스너 추가
      _controller.addListener(() {
        if (_controller.value.hasError) {
          LogService.error('UI', 'VideoBackground: 재생 중 에러 - ${_controller.value.errorDescription}');
          if (mounted) {
            setState(() {
              _isInitialized = false;
            });
          }
        }
      });
      
      await _controller.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        // 음소거 및 루프 설정
        await _controller.setVolume(0.0);
        await _controller.setLooping(true);
        await _controller.play();
      }
    } catch (e) {
      LogService.error('UI', 'VideoBackground: 영상 초기화 실패', e);
      // 영상 로딩 실패 시에도 fallback으로 처리
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 영상이 준비되지 않았거나 실패한 경우 기본 배경 이미지 표시
        if (!_isInitialized)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nature_walk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        
        // 영상이 준비된 경우 영상 재생
        if (_isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
        
        // 자식 위젯 (UI 요소들)
        if (widget.child != null) widget.child!,
      ],
    );
  }
}