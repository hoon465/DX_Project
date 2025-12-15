import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: const [
            Text(
              '김지현 홈',
              style: TextStyle(
                color: Colors.black, // 검은색
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.black54, // 검은색 (약간 투명)
              size: 24,
            ),
          ],
        ),
        Row(
          children: [
            _buildRoundIcon(Icons.add),
            const SizedBox(width: 10),
            _buildRoundIcon(Icons.notifications, size: 20),
            const SizedBox(width: 10),
            _buildRoundIcon(Icons.more_vert, size: 20),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundIcon(IconData icon, {double size = 18}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white, // 흰색 배경
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.black87, // 검은색 아이콘
        size: size,
      ),
    );
  }
}



