import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'live_screen.dart';
import 'chat_screen.dart';

class ElliHomeScreen extends StatefulWidget {
  const ElliHomeScreen({super.key});

  @override
  State<ElliHomeScreen> createState() => _ElliHomeScreenState();
}

class _ElliHomeScreenState extends State<ElliHomeScreen> {
  bool _isMenuOpen = false; // 메뉴 열림/닫힘 상태

  // Figma 프레임 크기: 360x800
  static const double figmaWidth = 360;

  @override
  Widget build(BuildContext context) {
    // 상태바 스타일 설정 (Figma: #faf9fd 배경)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFFAF9FD),
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFBBA7F7),
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    
    // 화면에 딱 맞게 스케일 계산 (Figma 360x800 기준)
    final scale = screenWidth / figmaWidth;

    return Scaffold(
      backgroundColor: Colors.white, // Figma: bg-white
      body: SizedBox(
        width: screenWidth,
        height: screenHeight,
        child: Stack(
          children: [
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
            // 배경 그라데이션 (메인 콘텐츠 영역) - 피그마: h-[776px], 화면 하단까지 채움
            // Figma: top:24부터 시작, height:776px
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
                      Color(0xFFF3F1FB), // #f3f1fb
                      Color(0xFF7145F1), // #7145f1
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // 상단 바 (Frame 1686558293)
            // Figma: top:39, left:12, width:348, height:24
            Positioned(
              top: 39 * scale,
              left: 12 * scale,
              child: SizedBox(
                width: 348 * scale,
                height: 24 * scale,
                child: Row(
                  children: [
                    // 뒤로가기 아이콘 (24x24) - 전 화면으로 돌아가기
                    // Figma: left:0, size:24x24
                    IconButton(
                      icon: Icon(Icons.arrow_back, size: 24 * scale, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context); // 전 화면으로 돌아가기
                      },
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 24 * scale,
                        minHeight: 24 * scale,
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    // ELLI 텍스트
                    // Figma: left:32, top:3, fontSize:18, fontWeight:Bold
                    Padding(
                      padding: EdgeInsets.only(top: 3 * scale),
                      child: Text(
                        'ELLI',
                        style: TextStyle(
                          fontFamily: 'Noto Sans',
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: 0.2 * scale,
                          height: 16 / 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 메뉴 아이콘 (24x24)
                    // Figma: left:309, top:3, size:24x24
                    // 수평 정렬을 위해 위로 올림
                    Padding(
                      padding: EdgeInsets.only(top: 0),
                      child: IconButton(
                        icon: Icon(Icons.menu, size: 24 * scale, color: Colors.black),
                        onPressed: () {
                          setState(() {
                            _isMenuOpen = true; // 메뉴 열기
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 24 * scale,
                          minHeight: 24 * scale,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 프로필 이미지 (Mask group)
            // Figma: top:142, 중앙 정렬, width:120, height:120
            Positioned(
              top: 142 * scale,
              left: (screenWidth - 120 * scale) / 2,
              child: _buildProfileImage(scale),
            ),
            // 인사말 텍스트
            // Figma: top:299, 중앙 정렬
            Positioned(
              top: 299 * scale,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '지현님. 좋은 아침이에요.',
                  style: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: 0.2 * scale,
                    height: 16 / 16,
                  ),
                ),
              ),
            ),
            // 설명 텍스트
            // Figma: top:345, 중앙 정렬
            Positioned(
              top: 345 * scale,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                  child: Text(
                    '생성형 AI를 활용한 가전 전문 어시스턴트 엘리예요.\n함께 문제를 바로 해결헤요!',
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      letterSpacing: 0.2 * scale,
                      height: 19.068 / 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // 하단 버튼들 (Frame 1686558312)
            // Figma: bottom:76 (800 - 601 - 123 = 76), 중앙 정렬
            Positioned(
              bottom: 76 * scale,
              left: (screenWidth - 328 * scale) / 2,
              child: Material(
                color: Colors.transparent,
                child: _buildActionButtons(context, scale),
              ),
            ),
            // 사이드 메뉴 (메뉴 아이콘 클릭 시 표시)
            if (_isMenuOpen) _buildSideMenu(context, scale, screenWidth, screenHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(double scale) {
    final size = 120 * scale;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFD9D9D9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8 * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/캐릭터 프사.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD9D9D9),
              ),
              child: Icon(
                Icons.person,
                size: 60 * scale,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, double scale) {
    final buttonWidth = 328 * scale;
    final buttonHeight = 54 * scale;
    final borderRadius = 16 * scale;
    final fontSize = 16 * scale;
    
    return SizedBox(
      width: buttonWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라이브 문제 해결 버튼
          SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LiveScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F42EE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                elevation: 0,
              ),
              child: Text(
                '라이브 문제 해결',
                style: TextStyle(
                  fontFamily: 'Noto Sans',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.2 * scale,
                  height: 16 / 16,
                ),
              ),
            ),
          ),
          SizedBox(height: 15 * scale),
          // 채팅 문의 버튼
          SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: const Color(0xFF6F40EE), width: 1 * scale),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                elevation: 0,
              ),
              child: Text(
                '채팅 문의',
                style: TextStyle(
                  fontFamily: 'Noto Sans',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6F40EE),
                  letterSpacing: 0.2 * scale,
                  height: 16 / 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 사이드 메뉴 빌더
  Widget _buildSideMenu(BuildContext context, double scale, double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // 어두운 오버레이 (화면 전체)
        // Figma: bg-[rgba(0,0,0,0.28)]
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isMenuOpen = false; // 메뉴 닫기
              });
            },
            child: Container(
              color: const Color.fromRGBO(0, 0, 0, 0.28),
            ),
          ),
        ),
        // 오른쪽 사이드 패널
        // Figma: left:82, width:278, height:776, rounded-bl-[19px], rounded-tl-[19px]
        Positioned(
          left: 82 * scale,
          top: 24 * scale,
          bottom: 0,
          width: 278 * scale,
          child: GestureDetector(
            onTap: () {
              // 패널 내부 클릭은 메뉴를 닫지 않음
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(19 * scale),
                  bottomLeft: Radius.circular(19 * scale),
                ),
              ),
              child: _buildMenuContent(context, scale, screenWidth),
            ),
          ),
        ),
      ],
    );
  }

  // 메뉴 내용 빌더
  Widget _buildMenuContent(BuildContext context, double scale, double screenWidth) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 검색 바
          // Figma: top:45 (전체 화면 기준), 사이드 패널 내부에서는 top:21 (45-24)
          Padding(
            padding: EdgeInsets.only(
              top: 21 * scale, // 45 - 24 (상단 상태바 높이)
              left: 17 * scale,
              right: 17 * scale,
            ),
            child: Container(
              height: 36 * scale,
              width: 228 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAEB),
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              child: Row(
                children: [
                  SizedBox(width: 8 * scale),
                  Icon(Icons.search, size: 17 * scale, color: const Color(0xFF9A9A9A)),
                  SizedBox(width: 8 * scale),
                  Text(
                    '검색',
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9A9A9A),
                      letterSpacing: 0.2 * scale,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 아이콘들 (설정, 고객 센터, 도움말)
          // Figma: top:113 (전체 화면 기준), 사이드 패널 내부에서는 top:89 (113-24)
          Padding(
            padding: EdgeInsets.only(
              top: 32 * scale, // 113 - 24 - 45 - 36 = 8, 하지만 간격 조정
              left: 15 * scale,
              right: 15 * scale,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMenuIcon(scale, 'assets/images/Group 1686558373.svg', '설정'),
                _buildMenuIcon(scale, 'assets/images/Group 1686558371.svg', '고객 센터'),
                _buildMenuIcon(scale, 'assets/images/Group 1686558372.svg', '도움말'),
              ],
            ),
          ),
          // 대화 목록 제목
          // Figma: top:243 (전체 화면 기준), 사이드 패널 내부에서는 top:219 (243-24)
          Padding(
            padding: EdgeInsets.only(
              top: 66 * scale, // 243 - 24 - 45 - 36 - 59 - 20 = 59, 간격 조정
              left: 17 * scale,
              bottom: 8 * scale,
            ),
            child: Text(
              '대화 목록',
              style: TextStyle(
                fontFamily: 'Noto Sans',
                fontSize: 15 * scale,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF565656),
                letterSpacing: 0.2 * scale,
              ),
            ),
          ),
          // 대화 목록 항목들
          // 간단한 예시로 몇 개만 표시
          _buildConversationItem(scale, '세탁기 UE 오류 코드 해결', '12.12 금 오전 01:30', 'assets/images/Group 1686558395.svg'),
          _buildConversationItem(scale, '세탁 중 소음 발생 확인', '12.08 월 오후 10:12', 'assets/images/Group 1686558396.svg'),
          _buildConversationItem(scale, '니트류 세제 질문', '12.08 월 오후 10:04', 'assets/images/Group 1686558395.svg'),
          _buildConversationItem(scale, '세탁물 양에 맞는 세제 양 질문', '12.01 월 오후 01:30', 'assets/images/Group 1686558394.svg'),
          _buildConversationItem(scale, '세탁기 아기 옷 세탁 기능 추천', '11.28 금 오후 04:30', 'assets/images/Group 1686558396.svg'),
          _buildConversationItem(scale, '세탁기 관리제 구매 시기 알림', '11.01 토 오후 09:15', 'assets/images/Group 1686558394.svg'),
          _buildConversationItem(scale, '세탁기 첫 사용 방법', '11.01 토 오후 09:15', 'assets/images/Group 1686558394.svg'),
        ],
      ),
    );
  }

  // 메뉴 아이콘 빌더
  Widget _buildMenuIcon(double scale, String svgPath, String label) {
    return Column(
      children: [
        SizedBox(
          width: 59 * scale,
          height: 59 * scale,
          child: SvgPicture.asset(
            svgPath,
            width: 59 * scale,
            height: 59 * scale,
            fit: BoxFit.contain,
            placeholderBuilder: (context) {
              print('⚠️ [ElliHomeScreen] SVG 로드 실패: $svgPath');
              return Container(
                width: 59 * scale,
                height: 59 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: Icon(Icons.error, size: 24 * scale, color: Colors.grey),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('❌ [ElliHomeScreen] SVG 에러: $svgPath, 에러: $error');
              return Container(
                width: 59 * scale,
                height: 59 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: Icon(Icons.error, size: 24 * scale, color: Colors.red),
              );
            },
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Noto Sans',
            fontSize: 12 * scale,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF696A6F),
            letterSpacing: 0.2 * scale,
          ),
        ),
      ],
    );
  }

  // 대화 목록 항목 빌더
  Widget _buildConversationItem(double scale, String title, String timestamp, String svgPath) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMenuOpen = false; // 항목 클릭 시 메뉴 닫기
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 17 * scale, vertical: 4 * scale),
        padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 10 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDFB),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10 * scale),
            bottomLeft: Radius.circular(10 * scale),
          ),
        ),
        child: Row(
          children: [
            // 아이콘
            SizedBox(
              width: 40 * scale,
              height: 40 * scale,
              child: SvgPicture.asset(
                svgPath,
                width: 40 * scale,
                height: 40 * scale,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => Container(
                  width: 40 * scale,
                  height: 40 * scale,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD9D9D9),
                  ),
                  child: Icon(Icons.error, size: 21 * scale, color: const Color(0xFF6F42EE)),
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
            // 제목과 타임스탬프
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      letterSpacing: 0.2 * scale,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    timestamp,
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      letterSpacing: 0.2 * scale,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
