import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/xev_logo.dart';
import '../application/auth_controller.dart';

export '../../../shared/widgets/xev_logo.dart' show XevEmblemVector, XevAppLogo;

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
      backgroundColor: const Color(0xFF020305),
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
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _entranceFade;
  late final AnimationController _cycleController;

  @override
  void initState() {
    super.initState();

    // Elegant entrance fade-in
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    // Continuous luxury motion: weightless suspension float + metallic light sweep
    _cycleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _cycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF020305),
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _entranceFade,
            child: AnimatedBuilder(
              animation: _cycleController,
              builder: (context, child) {
                final progress = _cycleController.value;

                // 1. Organic weightless float & subtle pulse (smooth cyclic sine wave)
                final floatWave =
                    (math.sin(progress * 2 * math.pi) + 1.0) / 2.0;
                final scale = 0.97 + (0.05 * floatWave);
                final floatY = -3.5 + (7.0 * floatWave);

                // 2. Specular metallic sheen sweep across the emblem
                // Sweeps across the logo during the first 45% of the cycle (~1.6s), then rests
                const sheenWindow = 0.45;
                final double sheenPosition;
                final double sheenOpacity;

                if (progress < sheenWindow) {
                  final sheenT =
                      Curves.easeInOutCubic.transform(progress / sheenWindow);
                  sheenPosition = -1.5 + (sheenT * 3.0);
                  sheenOpacity = 1.0;
                } else {
                  sheenPosition = 2.5;
                  sheenOpacity = 0.0;
                }

                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: Transform.scale(
                    scale: scale,
                    child: ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (Rect bounds) {
                        if (sheenOpacity == 0.0) {
                          return const LinearGradient(
                            colors: [Colors.transparent, Colors.transparent],
                          ).createShader(bounds);
                        }

                        return LinearGradient(
                          begin: Alignment(sheenPosition - 0.45, -0.6),
                          end: Alignment(sheenPosition + 0.45, 0.6),
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.55),
                            const Color(0xFF00E5BE).withValues(alpha: 0.40),
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 0.50, 0.58, 0.75, 1.0],
                        ).createShader(bounds);
                      },
                      child: const XevAppLogo(height: 80),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
