import 'package:flutter/material.dart';

/// ABC Brand Logo chuẩn hóa theo Web Dashboard (`brand.tsx` & `auth-shell.tsx`):
/// - Chữ `ABC` màu đỏ mận thương hiệu `#C1121F` (FontWeight.w900, tracking tight)
/// - Thanh nhãn phụ: `— AI BUSINESS COPILOT —` màu xanh lá đậm `#0F4C3A`
/// - Hỗ trợ hiển thị dạng badge khung viền bo cong hoặc dạng lockup trực tiếp cho dashboard.
class AbcLogo extends StatelessWidget {
  final bool showBadge;
  final bool showTagline;
  final double size;

  const AbcLogo({
    super.key,
    this.showBadge = true,
    this.showTagline = true,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final abcText = Text(
      'ABC',
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: const Color(0xFFC1121F), // ABC Signature Crimson Red
        letterSpacing: -0.6,
        height: 1.0,
      ),
    );

    final tagline = showTagline
        ? Padding(
            padding: const EdgeInsets.only(top: 2.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: size * 0.28,
                  height: 1.5,
                  color: const Color(0xFF0F4C3A), // ABC Signature Forest Green
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.5),
                  child: Text(
                    'AI BUSINESS COPILOT',
                    style: TextStyle(
                      fontSize: (size * 0.26).clamp(7.0, 10.0),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F4C3A),
                      letterSpacing: 0.8,
                      height: 1.0,
                    ),
                  ),
                ),
                Container(
                  width: size * 0.28,
                  height: 1.5,
                  color: const Color(0xFF0F4C3A),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final logoContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        abcText,
        tagline,
      ],
    );

    if (!showBadge) {
      return logoContent;
    }

    final badgePaddingH = size * 0.55;
    final badgePaddingV = size * 0.45;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: badgePaddingH,
        vertical: badgePaddingV,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: logoContent,
    );
  }
}
