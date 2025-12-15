import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'elli_home_screen.dart';
import '../widgets/dashed_border.dart';
import '../widgets/hero_cards.dart';
import '../widgets/news_card.dart';
import '../widgets/routine_card.dart';
import '../widgets/thinq_play_card.dart';
import '../widgets/top_bar.dart';

class ThinQHomeScreen extends StatelessWidget {
  const ThinQHomeScreen({super.key});

  static const double _horizontalPadding = 24;
  
  // Figma 프레임 크기: 360x800
  static const double figmaWidth = 360;

  @override
  Widget build(BuildContext context) {
    // 상태바 스타일 설정 (Figma: 그라데이션 배경)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFEDF6F7), // Figma gradient end color
      statusBarIconBrightness: Brightness.dark, // Dark icons on light background
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final scale = screenWidth / figmaWidth;

    return Scaffold(
      backgroundColor: const Color(0xFFBDD2E6), // 하늘색 배경
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFBDD2E6), // #BDD2E6
              Color(0xFFDCEEF6), // #DCEEF6
              Color(0xFFE8F3F8), // #E8F3F8
              Color(0xFFEDF6F7), // #EDF6F7
              Color(0xFFEDF6F7), // #EDF6F7
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: Stack(
          children: [
          SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 140),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: _horizontalPadding, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const TopBar(),
                        const SizedBox(height: 28),
                        const HeroCards(),
                        const SizedBox(height: 32),
                        _buildSectionTitle(
                          '즐겨 찾는 제품',
                          '제품을 추가하면 홈 화면에서 바로 사용할 수 있어요.',
                        ),
                        const SizedBox(height: 12),
                        DashedBorder(
                          borderRadius: BorderRadius.circular(18),
                          dashWidth: 8,
                          dashGap: 4,
                          strokeWidth: 1.4,
                          color: Colors.black26, // 검은색 점선
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                '제품을 추가해주세요.',
                                style: TextStyle(
                                  color: Colors.black, // 검은색
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '제품을 즐겨 찾는 제품에 추가하면 홈 화면에서 바로 사용할 수 있어요.',
                                style: TextStyle(
                                  color: Colors.black54, // 검은색 (약간 투명)
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildSectionTitle(
                          'ThinQ PLAY',
                          '앱을 다운로드하여 제품과 공간을 업그레이드해보세요.',
                        ),
                        const SizedBox(height: 12),
                        const ThinqPlayCard(),
                        const SizedBox(height: 30),
                        _buildSectionTitle(
                          '스마트 루틴',
                          'AI가 알아서 rutin을 정리해줍니다.',
                        ),
                        const SizedBox(height: 12),
                        const RoutineCard(),
                        const SizedBox(height: 28),
                        _buildSectionTitle(
                          '새로운 소식',
                          '놓치고 싶지 않은 이야기를 모아봤어요.',
                        ),
                        const SizedBox(height: 12),
                        const NewsCard(),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
                // 플로팅 버튼 (Figma 디자인에 맞춤 - 오른쪽 하단)
                // Figma: left-[calc(75%+19px)] = 270+19 = 289px, top-[652px], size: 58x58
                // 화면 너비 360에서: right = 360 - 289 - 58 = 13px
                // 화면 높이 800에서: bottom = 800 - 652 - 58 = 90px
                Positioned(
                  right: 13 * scale,
                  bottom: 90 * scale,
                  child: _buildFloatingActionButton(context, scale),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black, // 검은색
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.black54, // 검은색 (약간 투명)
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, double scale) {
    // Figma 디자인: 원형 이미지, 크기 58x58, cornerRadius 31, shadow: 0px_4px_4px_0px_rgba(0,0,0,0.25)
    return GestureDetector(
      onTap: () {
        // 플로팅 버튼 클릭 시 ElliHomeScreen으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ElliHomeScreen()),
        );
      },
      child: Container(
        width: 58 * scale,
        height: 58 * scale,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(31 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4 * scale,
              offset: Offset(0, 4 * scale),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31 * scale),
          child: Image.asset(
            'assets/images/로고.png',
            width: 58 * scale,
            height: 58 * scale,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 이미지가 없을 경우 그라데이션 원형 버튼 사용
              return Container(
                width: 58 * scale,
                height: 58 * scale,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C3BFF), Color(0xFFB65CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(31 * scale),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 28 * scale,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

