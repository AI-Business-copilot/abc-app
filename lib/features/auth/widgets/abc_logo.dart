import 'package:flutter/material.dart';

/// ABC Brand Logo đồng bộ chuẩn 1:1 với Web Dashboard (`brand.tsx` & `auth-shell.tsx`):
/// - Chữ `ABC` màu đỏ mận `#C1121F` (FontWeight.w900, tracking tight)
/// - Thanh nhãn phụ: `— AI BUSINESS COPILOT —` màu xanh lá đậm `#0F4C3A`
/// - Không bọc viền ngoài, đứng độc lập tinh gọn và nhất quán.
class AbcLogo extends StatelessWidget {
  final bool showTagline;
  final double size;

  const AbcLogo({
    super.key,
    this.showTagline = true,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'ABC',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFC1121F), // ABC Signature Crimson Red
            letterSpacing: -0.6,
            height: 1.0,
          ),
        ),
        if (showTagline) ...[
          Padding(
            padding: const EdgeInsets.only(top: 3.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: size * 0.28,
                  height: 1.6,
                  color: const Color(0xFF0F4C3A), // ABC Signature Forest Green
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    'AI BUSINESS COPILOT',
                    style: TextStyle(
                      fontSize: (size * 0.26).clamp(7.5, 11.0),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F4C3A),
                      letterSpacing: 0.9,
                      height: 1.0,
                    ),
                  ),
                ),
                Container(
                  width: size * 0.28,
                  height: 1.6,
                  color: const Color(0xFF0F4C3A),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
