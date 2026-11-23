import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/auth_controller.dart';

/// Splash page presented on initial application startup.
/// Features the official Mahindra XEV 9S Companion brand mark with an
/// ambient breathing animation, free of redundant text labels.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF040609),
      body: switch (authState) {
        AuthStartupFailed(:final error) => ErrorView(
            title: "Couldn't load your account",
            message: error.displayMessage,
            error: error,
            showRetry: true,
            onRetry: () =>
                ref.read(authControllerProvider.notifier).checkSession(),
          ),
        _ => const _SplashContent(),
      },
    );
  }
}

class _SplashContent extends StatefulWidget {
  const _SplashContent();

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _breatheAnimation = CurvedAnimation(
      parent: _breatheController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [
            Color(0xFF141A24), // Subtle deep charcoal ambient glow in center
            Color(0xFF090D14),
            Color(0xFF040609), // Deep luxury black
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (context, child) {
              final breathe = _breatheAnimation.value;
              final scale = 0.95 + (0.08 * breathe);
              final redGlowOpacity = 0.14 + (0.18 * breathe);
              final silverGlowOpacity = 0.10 + (0.16 * breathe);
              final glowBlur = 28.0 + (26.0 * breathe);

              return Transform.scale(
                scale: scale,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Crimson red ambient aura reflecting the 9S red accent
                      BoxShadow(
                        color: const Color(0xFFE11D48)
                            .withValues(alpha: redGlowOpacity),
                        blurRadius: glowBlur,
                        spreadRadius: 2.0 + (4.0 * breathe),
                      ),
                      // Platinum / Cyan soft halo
                      BoxShadow(
                        color: const Color(0xFF38BDF8)
                            .withValues(alpha: silverGlowOpacity),
                        blurRadius: glowBlur * 1.4,
                        spreadRadius: 1.0 + (3.0 * breathe),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/xev9s_logo_clean.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const XevEmblemVector(size: 80),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Fallback vector renderer for the XEV emblem.
class XevEmblemVector extends StatelessWidget {
  const XevEmblemVector({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.75),
      painter: _XevTwinPeaksPainter(),
    );
  }
}

class _XevTwinPeaksPainter extends CustomPainter {
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
      ..strokeWidth = 6.0
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
      ..strokeWidth = 6.0
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
