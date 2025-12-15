import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'video_player_overlay_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String? videoUrl;

  const VideoPlayerScreen({super.key, this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // 비디오 URL이 있으면 컨트롤러 초기화
    if (widget.videoUrl != null) {
       // http로 시작하면 네트워크 URL, 아니면 로컬 에셋으로 처리
       if (widget.videoUrl!.startsWith('http')) {
         _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
       } else {
         _controller = VideoPlayerController.asset(widget.videoUrl!);
       }

       _controller!.initialize().then((_) {
           setState(() {
             _isInitialized = true;
           });
           _controller!.play();
         }).catchError((error) {
           print("Video initialization error: $error");
           // 영상 로드 실패 시 잠시 후 오버레이로 이동
           Future.delayed(const Duration(seconds: 2), _navigateToOverlay);
         });
       
       _controller!.addListener(() {
         if (_controller!.value.isInitialized &&
             !_controller!.value.isPlaying &&
             _controller!.value.position >= _controller!.value.duration) {
           _navigateToOverlay();
         }
       });
    } else {
      // URL이 없는 경우 5초 후 이동 (테스트용)
      Future.delayed(const Duration(seconds: 5), _navigateToOverlay);
    }
  }

  void _navigateToOverlay() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => VideoPlayerOverlayScreen(videoUrl: widget.videoUrl)),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }


  // Figma 프레임 크기: 360x800
  static const double figmaWidth = 360;

  @override
  Widget build(BuildContext context) {
    // 상태바 스타일 설정 (Figma: #faf9fd 배경)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFFAF9FD),
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFBAA6F7),
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    
    // 화면에 딱 맞게 스케일 계산 (Figma 360x800 기준)
    final scale = screenWidth / figmaWidth;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          children: [
            // Rectangle 287 배경 그라데이션 (전체 메인 콘텐츠 영역) - 피그마: h-[776px], 화면 하단까지 채움
            // Figma: Rectangle 287, x=0, y=24, width=360, height=776
            // 그라데이션: F3F1FB 42%, 7145F1 100%
            Positioned(
              top: 24 * scale,
              left: 0,
              right: 0,
              bottom: 0, // 화면 하단까지 채움
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF3F1FB), // F3F1FB
                      Color(0xFF7145F1), // 7145F1
                    ],
                    stops: [0.42, 1.0], // F3F1FB 42%, 7145F1 100%
                  ),
                ),
              ),
            ),
            // 상단 상태바 영역 (Status Bar/Android)
            // Figma: height:24, 색상: #faf9fd
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24 * scale,
              child: Container(
                color: const Color(0xFFFAF9FD),
              ),
            ),
            // 뒤로가기 버튼
            // Figma: top:40, left:12, width:24, height:24
            Positioned(
              top: 40 * scale,
              left: 12 * scale,
              child: IconButton(
                icon: Icon(Icons.arrow_back, size: 24 * scale, color: Colors.black),
                onPressed: () {
                  Navigator.pop(context);
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),
            // 비디오 영역
            Positioned(
              top: 80 * scale,
              left: 0,
              right: 0,
              height: 672 * scale,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFF0),
                  border: Border.all(
                    color: const Color(0xFFAFB1B6),
                    width: 2 * scale,
                  ),
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: _isInitialized && _controller != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6 * scale),
                        child: SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.size.width,
                              height: _controller!.value.size.height,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

