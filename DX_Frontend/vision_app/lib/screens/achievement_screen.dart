import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'elli_home_screen.dart';

class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  // Figma 프레임 크기: 360x800
  static const double figmaWidth = 360;
  static const double figmaHeight = 800;

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
            // 팝업 다이얼로그
            // Figma: x=29, y=209, width=302, height=357.277
            Positioned(
              top: 209 * scale,
              left: 29 * scale,
              child: Container(
                width: 302 * scale,
                height: 357.277 * scale,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.223 * scale),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4 * scale,
                      offset: Offset(0, 4 * scale),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 닫기 버튼 (우측 상단)
                    // Figma: x=122, y=12, width=16, height=16
                    Positioned(
                      top: 12 * scale,
                      right: 12 * scale,
                      child: GestureDetector(
                        onTap: () {
                          // 모든 화면을 제거하고 홈 화면으로 이동
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const ElliHomeScreen()),
                            (route) => false, // 모든 이전 라우트 제거
                          );
                        },
                        child: Container(
                          width: 16 * scale,
                          height: 16 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF7145F1),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 12 * scale,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // 칭호 아이콘 이미지
                    // 위로 이동하여 버튼과 간격 확보
                    Positioned(
                      top: 20 * scale, // 35 -> 20
                      left: 85 * scale,
                      child: Image.asset(
                        'assets/images/칭호 아이콘.png',
                        width: 133 * scale,
                        height: 144.339 * scale,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 133 * scale,
                            height: 144.339 * scale,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8 * scale),
                            ),
                            child: Icon(
                              Icons.emoji_events,
                              size: 80 * scale,
                              color: Colors.amber,
                            ),
                          );
                        },
                      ),
                    ),
                    // "꼼꼼한 질문쟁이 칭호를 획득했어요!" 텍스트
                    // 위로 이동
                    Positioned(
                      top: 175 * scale, // 203 -> 175
                      left: 42 * scale,
                      right: 36 * scale,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Noto Sans',
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: -0.8 * scale,
                          ),
                          children: [
                            TextSpan(
                              text: '꼼꼼한 질문쟁이',
                              style: TextStyle(
                                color: const Color(0xFF7145F1),
                              ),
                            ),
                            TextSpan(text: ' 칭호를 획득했어요!'),
                          ],
                        ),
                      ),
                    ),
                    // "이번달 엘리와 5번 오류를 해결했어요. 앞으로도 제가 도와드릴게요!" 텍스트
                    // 위 문장과 간격 확보를 위해 조금 아래로 이동
                    Positioned(
                      top: 220 * scale, // 205 -> 220
                      left: 30 * scale,
                      right: 30 * scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 첫 번째 문장: 한 줄로 표시
                          Text(
                            '이번달 엘리와 5번 오류를 해결했어요.',
                            style: TextStyle(
                              fontFamily: 'Noto Sans',
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6B6B6B), // 더 진한 회색
                              letterSpacing: -0.24 * scale,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                          ),
                          SizedBox(height: 4 * scale),
                          // 두 번째 문장: 다음 줄에 표시
                          Text(
                            '앞으로도 제가 도와드릴게요!',
                            style: TextStyle(
                              fontFamily: 'Noto Sans',
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6B6B6B), // 더 진한 회색
                              letterSpacing: -0.24 * scale,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    // "확인하러 가기" 버튼
                    // Figma: x=72, y=283, width=158, height=40
                    Positioned(
                      top: 283 * scale,
                      left: 72 * scale,
                      child: GestureDetector(
                        onTap: () {
                          // 모든 화면을 제거하고 홈 화면으로 이동
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const ElliHomeScreen()),
                            (route) => false, // 모든 이전 라우트 제거
                          );
                        },
                        child: Container(
                          width: 158 * scale,
                          height: 40 * scale,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7145F1),
                            borderRadius: BorderRadius.circular(40 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 4 * scale,
                                offset: Offset(0, 4 * scale),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '확인하러 가기',
                                style: TextStyle(
                                  fontFamily: 'Noto Sans',
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                  letterSpacing: -0.8 * scale,
                                ),
                              ),
                              SizedBox(width: 8 * scale),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 10.667 * scale,
                                color: Colors.white,
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
          ],
        ),
      ),
    );
  }
}

