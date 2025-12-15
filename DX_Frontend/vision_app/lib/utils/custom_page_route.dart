import 'package:flutter/material.dart';

/// 부드러운 화면 전환을 위한 커스텀 PageRoute
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final AxisDirection direction;

  SmoothPageRoute({
    required this.child,
    this.direction = AxisDirection.left,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300), // 전환 시간 (기본 300ms)
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => child,
        );

  @override
  Widget buildTransitions(
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
        curve: Curves.easeInOut, // 부드러운 곡선
      ),
    );

    // 슬라이드 효과
    Offset begin;
    switch (direction) {
      case AxisDirection.right:
        begin = const Offset(-1.0, 0.0);
        break;
      case AxisDirection.left:
        begin = const Offset(1.0, 0.0);
        break;
      case AxisDirection.up:
        begin = const Offset(0.0, 1.0);
        break;
      case AxisDirection.down:
        begin = const Offset(0.0, -1.0);
        break;
    }

    final slideAnimation = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic, // 더 부드러운 곡선
      ),
    );

    // 페이드 + 슬라이드 조합
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }
}

