import 'package:material_ui/material_ui.dart';

/// Reusable Mahindra XEV 9S brand logo.
/// Attempts to load the official asset image ('assets/images/xev_logo.png')
/// and seamlessly falls back to the high-fidelity [XevEmblemVector] painter
/// if the asset is missing or during tests.
class XevAppLogo extends StatelessWidget {
  const XevAppLogo({
    super.key,
    this.height = 32,
    this.width,
    this.fit = BoxFit.contain,
  });

  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? 32.0;
    final effectiveWidth = width ?? (effectiveHeight * (800 / 460));

    return Image.asset(
      'assets/images/xev_logo.png',
      height: effectiveHeight,
      width: effectiveWidth,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          XevEmblemVector(size: effectiveHeight),
    );
  }
}

/// Fallback vector renderer for the XEV Twin Peaks emblem.
class XevEmblemVector extends StatelessWidget {
  const XevEmblemVector({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * (800 / 460), size),
      painter: const _XevTwinPeaksPainter(),
    );
  }
}

class _XevTwinPeaksPainter extends CustomPainter {
  const _XevTwinPeaksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Metallic silver paint for left wing
    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8), Color(0xFF475569)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.05).clamp(2.5, 6.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final leftPath = Path()
      ..moveTo(w * 0.48, h * 0.85)
      ..lineTo(w * 0.15, h * 0.25)
      ..lineTo(w * 0.42, h * 0.50)
      ..close();
    canvas.drawPath(leftPath, leftPaint);

    // Crimson illuminated right wing
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFF4D6D), Color(0xFFE11D48), Color(0xFF94A3B8)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.05).clamp(2.5, 6.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rightPath = Path()
      ..moveTo(w * 0.52, h * 0.85)
      ..lineTo(w * 0.85, h * 0.25)
      ..lineTo(w * 0.58, h * 0.50)
      ..close();
    canvas.drawPath(rightPath, rightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
