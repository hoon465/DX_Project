import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'chat_screen.dart';

class CustomerServiceScreen extends StatelessWidget {
  const CustomerServiceScreen({super.key});

  // Figma 프레임 크기: 360x800
  static const double figmaWidth = 360;
  static const double figmaHeight = 800;

  @override
  Widget build(BuildContext context) {
    // 상태바 스타일 설정
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFFAF9FE),
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFBBA6F7),
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    // 화면에 딱 맞게 스케일 계산 (Figma 360x800 기준)
    final scale = screenWidth / figmaWidth;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 배경 그라데이션 (live_screen과 동일)
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
          // 상단 상태바
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
          Positioned(
            top: 70 * scale,
            left: 23 * scale,
            child: Row(
              children: [
                Container(
                  width: 9 * scale,
                  height: 9 * scale,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF0004),
                  ),
                ),
                SizedBox(width: 10 * scale),
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
          Positioned(
            top: 68 * scale,
            left: 271 * scale,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
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
                SizedBox(width: 15 * scale),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
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
            ),
          ),
          // 어두운 오버레이 (모달 상자 아래에 배치)
          // Figma: bg-[rgba(0,0,0,0.4)], h-[776px], left-[-3px], top-[24px], w-[362px]
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
          // 고객센터 연결 모달
          // Figma: left-[14px], top-[311px], width-[332px], height-[178px]
          Positioned(
            top: 311 * scale,
            left: 14 * scale,
            child: Container(
              width: 332 * scale,
              height: 178 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFF4F2FD),
                  width: 3 * scale,
                ),
                borderRadius: BorderRadius.circular(20.22 * scale),
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
                  // 텍스트들 (왼쪽)
                  // Figma: left-[76px]
                  Positioned(
                    top: 51 * scale,
                    left: 76 * scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "고객센터 연결" 텍스트
                        // Figma: top-[362px], fontSize:16, fontWeight:Medium
                        Text(
                          '고객센터 연결',
                          style: TextStyle(
                            fontFamily: 'Noto Sans',
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                            letterSpacing: 0.2 * scale,
                          ),
                        ),
                        SizedBox(height: 11 * scale),
                        // "연결 중 입니다..." 텍스트
                        // Figma: top-[402px], fontSize:13, fontWeight:Regular
                        Text(
                          '연결 중 입니다...',
                          style: TextStyle(
                            fontFamily: 'Noto Sans',
                            fontSize: 13 * scale,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                            letterSpacing: 0.2 * scale,
                          ),
                        ),
                        SizedBox(height: 7 * scale),
                        // "(대기인원 : 3명)" 텍스트
                        // Figma: top-[420px], fontSize:12, color:#a8a8a8
                        Text(
                          '(대기인원 : 3명)',
                          style: TextStyle(
                            fontFamily: 'Noto Sans',
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFA8A8A8),
                            letterSpacing: 0.2 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 닫기 아이콘 (오른쪽 상단) - 고객센터2.svg 사용
                  // Figma: inset-[40.63%_8.22%_57.45%_87.5%]
                  Positioned(
                    top: 12 * scale,
                    right: 12 * scale,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: SvgPicture.asset(
                        'assets/images/고객센터2.svg',
                        width: 12 * scale,
                        height: 12 * scale,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 이미지 (오른쪽) - 고객센터 연결1.svg (모달 위에 배치하여 맨 앞에 표시)
          // Figma: left-[calc(50%+19px)], top-[344px], width-[85px], height-[111px]
          Positioned(
            top: (311 + 33) * scale, // 모달 top + 모달 내부 top
            right: (14 + 19) * scale, // 모달 left + 모달 내부 right
            child: SvgPicture.asset(
              'assets/images/고객센터 연결1.svg',
              width: 85 * scale,
              height: 111 * scale,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

