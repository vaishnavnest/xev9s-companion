import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/auth_controller.dart';

/// Splash page presented on initial application startup.
/// Features the official Mahindra XEV 9S Companion brand mark floating cleanly
/// over an ambient background matching the app's electric teal theme,
/// with a smooth breathing animation.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF010406),
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
          center: Alignment(0.0, -0.05),
          radius: 1.25,
          colors: [
            Color(0xFF062A2B), // Deep electric teal glow from AppTheme brand palette
            Color(0xFF04171A), // Deep oceanic midnight teal
            Color(0xFF02090D), // Obsidian EV cockpit dark
            Color(0xFF010406), // Deep luxury black
          ],
          stops: [0.0, 0.45, 0.8, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (context, child) {
              final breathe = _breatheAnimation.value;
              final scale = 0.95 + (0.08 * breathe);
              final tealGlowOpacity = 0.16 + (0.18 * breathe);
              final redGlowOpacity = 0.12 + (0.16 * breathe);
              final glowBlur = 32.0 + (30.0 * breathe);

              return Transform.scale(
                scale: scale,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Electric Teal halo directly from AppTheme.accentColor
                      BoxShadow(
                        color: AppTheme.accentColor
                            .withValues(alpha: tealGlowOpacity),
                        blurRadius: glowBlur * 1.3,
                        spreadRadius: 2.0 + (4.0 * breathe),
                      ),
                      // Crimson red aura matching the "9S" red badge accent
                      BoxShadow(
                        color: const Color(0xFFE11D48)
                            .withValues(alpha: redGlowOpacity),
                        blurRadius: glowBlur,
                        offset: const Offset(30, 0),
                        spreadRadius: 1.0 + (3.0 * breathe),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/xev_logo.png',
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
