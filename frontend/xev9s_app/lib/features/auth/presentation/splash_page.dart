import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/auth_controller.dart';

/// Splash page presented on initial application startup.
/// Matches the luxury minimalist design of the XEV 9S intelligent companion.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE2E8F0), // Soft atmospheric vignette at top
            Color(0xFFF8FAFD),
            Color(0xFFFFFFFF),
            Color(0xFFF3F7FA),
          ],
          stops: [0.0, 0.12, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // Central Breathing Hero Card with Logo Emblem
            AnimatedBuilder(
              animation: _breatheAnimation,
              builder: (context, child) {
                final breathe = _breatheAnimation.value;
                final scale = 0.96 + (0.08 * breathe);
                final glowOpacity = 0.22 + (0.28 * breathe);
                final glowBlur = 28.0 + (24.0 * breathe);
                final glowSpread = 2.0 + (6.0 * breathe);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        // Dynamic electric cyan breathing aura
                        BoxShadow(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: glowOpacity),
                          blurRadius: glowBlur,
                          spreadRadius: glowSpread,
                        ),
                        BoxShadow(
                          color: const Color(0xFF38BDF8)
                              .withValues(alpha: glowOpacity * 0.7),
                          blurRadius: glowBlur * 1.5,
                          spreadRadius: glowSpread * 0.5,
                        ),
                        // Soft structural drop shadow
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Top-left cyan dot
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),

                        // Bottom-right cyan dot
                        Positioned(
                          bottom: 14,
                          right: 14,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),

                        // Center Emblem Logo
                        Center(
                          child: Image.asset(
                            'assets/images/xev_logo.png',
                            width: 68,
                            height: 60,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const XevEmblemVector(size: 60),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 38),

            // Title: XEV 9S
            const Text(
              'XEV 9S',
              style: TextStyle(
                color: Color(0xFF0B192C),
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 6.0,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle: Pure Electric Luxury Architecture
            const Text(
              'Pure Electric Luxury Architecture',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.6,
              ),
            ),

            const Spacer(flex: 4),

            // Bottom Brand Signet: Cyan Dot + CONNECTED MOBILITY
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CONNECTED MOBILITY',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback vector renderer for the XEV 9S crystalline stealth emblem.
class XevEmblemVector extends StatelessWidget {
  const XevEmblemVector({super.key, this.size = 60});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.88),
      painter: _XevEmblemPainter(),
    );
  }
}

class _XevEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top cap (Pale ice diamond)
    final topCapPath = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.34, h * 0.32)
      ..lineTo(w * 0.50, h * 0.44)
      ..lineTo(w * 0.66, h * 0.32)
      ..close();

    final topCapPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE0F7FA), Color(0xFF80DEEA)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(topCapPath, topCapPaint);

    // Left swept wing
    final leftWingPath = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.12, h * 0.54)
      ..lineTo(w * 0.36, h * 0.58)
      ..lineTo(w * 0.46, h * 0.48)
      ..lineTo(w * 0.50, h * 0.44)
      ..lineTo(w * 0.34, h * 0.32)
      ..close();

    final leftWingPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00E5FF), Color(0xFF0097A7)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(leftWingPath, leftWingPaint);

    // Right swept wing
    final rightWingPath = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.88, h * 0.54)
      ..lineTo(w * 0.64, h * 0.58)
      ..lineTo(w * 0.54, h * 0.48)
      ..lineTo(w * 0.50, h * 0.44)
      ..lineTo(w * 0.66, h * 0.32)
      ..close();

    final rightWingPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(rightWingPath, rightWingPaint);

    // Center vertical dagger / needle spine
    // Left half (Dark teal shadow)
    final needleLeftPath = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.50, h * 0.90)
      ..lineTo(w * 0.45, h * 0.52)
      ..close();

    final needleLeftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF006064), Color(0xFF082633)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(needleLeftPath, needleLeftPaint);

    // Right half (Rich sapphire/cyan highlight)
    final needleRightPath = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.50, h * 0.90)
      ..lineTo(w * 0.55, h * 0.52)
      ..close();

    final needleRightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF00838F), Color(0xFF0D47A1)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(needleRightPath, needleRightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
