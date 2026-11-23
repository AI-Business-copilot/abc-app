import 'package:flutter/material.dart';

/// ABC Brand Logo Badge đồng bộ 1:1 với giao diện web và ảnh thiết kế
class AbcLogo extends StatelessWidget {
  final bool showSubtitles;
  final double size;

  const AbcLogo({
    super.key,
    this.showSubtitles = false,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.26),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFC1121F), // ABC Red
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(text: 'ABC'),
                    ],
                  ),
                ),
                // Chấm nhỏ xanh lá thương hiệu ở đuôi chữ C
                Positioned(
                  right: -5,
                  bottom: 2,
                  child: Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F4C3A), // ABC Green
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Chiếc lá nhỏ đỏ thắm phía trên chữ C
                Positioned(
                  right: -3,
                  top: -2,
                  child: Transform.rotate(
                    angle: 0.35,
                    child: Container(
                      width: 5,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC1121F),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showSubtitles) ...[
          const SizedBox(height: 12),
          const Text(
            'ABC RETAIL',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'COPILOT',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ],
    );
  }
}
