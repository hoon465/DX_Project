import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // 🔥 [추가] 파이어베이스 코어
import 'package:cloud_firestore/cloud_firestore.dart'; // 🔥 [추가] Firestore 설정용
import 'firebase_options.dart'; // 🔥 [추가] 설정 파일 (flutterfire configure로 생성됨)
import 'screens/thinq_home_screen.dart';

/// 부드러운 페이드 + 슬라이드 전환 효과
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 페이드 효과
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ),
    );

    // 슬라이드 효과 (오른쪽에서 왼쪽으로)
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0.0), // 약간만 슬라이드
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }
}

// 🔥 [수정] main 함수를 async로 변경하고 초기화 로직 추가
void main() async { 
  print('🚀 [main] 앱 시작');
  // 1. 플러터 엔진 초기화 (비동기 작업 전에 필수!)
  WidgetsFlutterBinding.ensureInitialized();
  print('🚀 [main] Flutter 엔진 초기화 완료');

  // 2. 파이어베이스 시동 켜기 
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ [main] Firebase 초기화 완료');
    
    // Firestore 설정 개선 (네트워크 연결 설정)
    try {
      final firestore = FirebaseFirestore.instance;
      firestore.settings = const Settings(
        persistenceEnabled: true, // 오프라인 지속성 활성화
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // 캐시 크기 제한 없음
      );
      print('✅ [main] Firestore 설정 완료');
    } catch (e) {
      print('⚠️ [main] Firestore 설정 실패 (계속 진행): $e');
    }
  } catch (e) {
    print('❌ [main] Firebase 초기화 실패: $e');
    // Firebase 초기화 실패해도 앱은 계속 실행 (오프라인 모드)
    print('⚠️ [main] Firebase 없이 앱을 계속 실행합니다.');
  }

  print('🚀 [main] MyApp 실행 시작');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set status bar style to match Figma design (Android status bar with gradient)
    // Figma shows gradient: #bdd2e6 -> #dceef6 -> #e8f3f8 -> #edf6f7
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFEDF6F7), // Figma gradient end color
      statusBarIconBrightness: Brightness.dark, // Dark icons on light background
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return MaterialApp(
      title: 'Vision App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        // 부드러운 화면 전환 효과 설정
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SmoothPageTransitionsBuilder(),
            TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
          },
        ),
      ),
      home: const ThinQHomeScreen(),
    );
  }
}