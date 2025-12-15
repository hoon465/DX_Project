import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'video_production_screen.dart';
import 'chat_screen.dart';
import 'elli_home_screen.dart';
import '../services/live_camera_service.dart';

class LiveScreenWithButtons extends StatefulWidget {
  const LiveScreenWithButtons({super.key});

  @override
  State<LiveScreenWithButtons> createState() => _LiveScreenWithButtonsState();
}

class _LiveScreenWithButtonsState extends State<LiveScreenWithButtons> {
  final LiveCameraService _cameraService = LiveCameraService();
  bool _isStreaming = false;
  
  @override
  void initState() {
    super.initState();
    // 엘리홈으로 이동 콜백 설정
    _cameraService.setOnExitRequested(() {
      if (mounted) {
        // 사용종료 시 WebSocket을 유지하기 위해 closeWebSocket=false
        _cameraService.stopStreaming(closeWebSocket: false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ElliHomeScreen()),
          (route) => false,
        );
      }
    });
  }

  // Figma 프레임 크기: 360x800
  static const double figmaWidth = 360;
  static const double figmaHeight = 800;

  @override
  Widget build(BuildContext context) {
    // 상태바 스타일 설정 (Figma: #faf9fe 배경)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFFAF9FE),
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFBBA6F7),
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
            // 배경 그라데이션 (Rectangle 287)
            // Figma: x=0, y=24, width=360, height=776
            // 그라데이션: F3F1FB 42%, 7145F1 100%
            Positioned(
              top: 24 * scale,
              left: 0,
              right: 0,
              bottom: 0,
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
            // 상단 상태바 (Status Bar/Android)
            // Figma: bg-[#faf9fe], px-[16px] py-[4px], top:0, width:360, height:24
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24 * scale,
              child: Container(
                color: const Color(0xFFFAF9FE),
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: 4 * scale,
                ),
              ),
            ),
            // "실시간 진단" 텍스트와 빨간 점
            // Figma: left-[23px], top-[70px]
            Positioned(
              top: 70 * scale,
              left: 23 * scale,
              child: Row(
                children: [
                  // 빨간 점 (Ellipse 4765)
                  // Figma: left-[23px], top-[77px], size-[9px]
                  Container(
                    width: 9 * scale,
                    height: 9 * scale,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF0004),
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  // "실시간 진단" 텍스트
                  // Figma: left-[43px], top-[70px], fontSize:16, fontWeight:Medium
                  Text(
                    '실시간 진단',
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      letterSpacing: 0.016 * scale,
                      height: 21.792 / 16,
                    ),
                  ),
                ],
              ),
            ),
            // 오른쪽 상단 아이콘 버튼들
            // Figma: left-[271px], top-[68px], gap-[15px]
            Positioned(
              top: 68 * scale,
              left: 271 * scale,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 채팅 아이콘 (message-text-02)
                  // Figma: size-[24px]
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChatScreen()),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/images/라이브상단아이콘.svg',
                      width: 24 * scale,
                      height: 24 * scale,
                    ),
                  ),
                  SizedBox(width: 15 * scale), // gap-[15px]
                  // 헤드셋 아이콘 (Group)
                  // Figma: size-[22.286px]
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const VideoProductionScreen()),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/images/라이브상단아이콘2.svg',
                      width: 22.286 * scale,
                      height: 22.286 * scale,
                    ),
                  ),
                ],
              ),
            ),
            // 중앙 비디오 영역 (Placeholder)
            // Figma: top:112, left:0, width:360, height:554
            Positioned(
              top: 112 * scale,
              left: 0,
              right: 0,
              height: 554 * scale,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFF0),
                  border: Border.all(
                    color: const Color(0xFFAFB1B6),
                    width: 2 * scale,
                  ),
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: Center(
                  child: Icon(
                    Icons.videocam,
                    size: 60 * scale,
                    color: const Color(0xFFAFB1B6),
                  ),
                ),
              ),
            ),
            // 왼쪽 하단 캐릭터 이미지
            // Figma: top:509, left:19, width:95, height:143
            Positioned(
              top: 509 * scale,
              left: 19 * scale,
              child: Image.asset(
                'assets/images/캐릭터 정지.png',
                width: 95 * scale,
                height: 143 * scale,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 95 * scale,
                    height: 143 * scale,
                    color: Colors.grey.withValues(alpha: 0.3),
                    child: Icon(Icons.person, size: 40 * scale, color: Colors.grey),
                  );
                },
              ),
            ),
            // 말풍선
            // Figma: top:509, left:113, width:223, height:80
            Positioned(
              top: 509 * scale,
              left: 113 * scale,
              child: Container(
                width: 223 * scale,
                height: 80 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9).withValues(alpha: 0.49),
                  borderRadius: BorderRadius.circular(15 * scale),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: 22 * scale,
                ),
                child: Center(
                  child: Text(
                    '해결 과정이 담긴 AI 제작 영상을 보시겠어요?',
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      letterSpacing: 0.2 * scale,
                      height: 17.706 / 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // 예/아니오 버튼들
            // Figma: top:597, left:129, width:191, height:37
            Positioned(
              top: 597 * scale,
              left: 129 * scale,
              child: Container(
                width: 191 * scale,
                height: 37 * scale,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4 * scale,
                      offset: Offset(0, 4 * scale),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // "예" 버튼
                    // Figma: width:90, height:37
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const VideoProductionScreen()),
                        );
                      },
                      child: Container(
                        width: 90 * scale,
                        height: 37 * scale,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6F42EE),
                          borderRadius: BorderRadius.circular(6 * scale),
                        ),
                        child: Center(
                          child: Text(
                            '예',
                            style: TextStyle(
                              fontFamily: 'Noto Sans',
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              letterSpacing: 0.2 * scale,
                              height: 23 / 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 11 * scale),
                    // "아니오" 버튼
                    // Figma: width:90, height:37
                    Container(
                      width: 90 * scale,
                      height: 37 * scale,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6 * scale),
                      ),
                      child: Center(
                        child: Text(
                          '아니오',
                          style: TextStyle(
                            fontFamily: 'Noto Sans',
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6F42EE),
                            letterSpacing: 0.2 * scale,
                            height: 23 / 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 하단 컨트롤 버튼들 (3개)
            // Figma: top:687, left:57, gap:24px
            // 첫 번째 버튼 (비디오 카메라)
            Positioned(
              top: 687 * scale,
              left: 57 * scale,
              child: GestureDetector(
                onTap: () async {
                  if (_isStreaming) {
                    // 스트리밍 중지
                    await _cameraService.stopStreaming();
                    setState(() {
                      _isStreaming = false;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('라이브 스트리밍이 중지되었습니다.')),
                      );
                    }
                  } else {
                    // 스트리밍 시작
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('라이브 스트리밍을 시작합니다...')),
                      );
                    }
                    final success = await _cameraService.startStreaming(context);
                    if (success) {
                      setState(() {
                        _isStreaming = true;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('라이브 스트리밍이 시작되었습니다.')),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('라이브 스트리밍 시작에 실패했습니다. 권한을 확인해주세요.')),
                        );
                      }
                    }
                  }
                },
                child: Container(
                  width: 66 * scale,
                  height: 44 * scale,
                  decoration: BoxDecoration(
                    color: _isStreaming ? Colors.red : Colors.white,
                    borderRadius: BorderRadius.circular(19.5 * scale),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4 * scale,
                        offset: Offset(0, 4 * scale),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isStreaming ? Icons.stop : Icons.videocam,
                      size: 24 * scale,
                      color: _isStreaming ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            // 두 번째 버튼 (재생/일시정지)
            Positioned(
              top: 687 * scale,
              left: 147 * scale, // 57 + 90 = 147
              child: Container(
                width: 66 * scale,
                height: 44 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFF29344E).withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(19.5 * scale),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4 * scale,
                      offset: Offset(0, 4 * scale),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19.5 * scale),
                  child: Image.asset(
                    'assets/images/라이브 재생 버튼.png',
                    width: 66 * scale,
                    height: 44 * scale,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 66 * scale,
                        height: 44 * scale,
                        decoration: BoxDecoration(
                          color: const Color(0xFF29344E).withValues(alpha: 0.54),
                          borderRadius: BorderRadius.circular(19.5 * scale),
                        ),
                        child: Icon(
                          Icons.pause,
                          size: 24 * scale,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // 세 번째 버튼 (종료)
            // X 버튼: 진단 화면 종료 및 엘리홈으로 이동
            Positioned(
              top: 687 * scale,
              left: 237 * scale, // 57 + 180 = 237
              child: GestureDetector(
                onTap: () {
                  // 1. WebSocket 서비스에 종료 신호 전송
                  _cameraService.closeDiagnosisAndExit();
                  
                  // 2. 잠시 대기 후 엘리홈으로 이동 (서버 응답을 기다리지 않고 즉시 이동)
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      // 스트리밍 중지
                      _cameraService.stopStreaming();
                      // 엘리홈으로 이동
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const ElliHomeScreen()),
                        (route) => false,
                      );
                    }
                  });
                },
                child: Container(
                  width: 66 * scale,
                  height: 44 * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF41919),
                    borderRadius: BorderRadius.circular(19.5 * scale),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4 * scale,
                        offset: Offset(0, 4 * scale),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.close,
                      size: 24 * scale,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _cameraService.stopStreaming();
    super.dispose();
  }
}
