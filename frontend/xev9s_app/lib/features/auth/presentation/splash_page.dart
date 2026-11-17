import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/auth_controller.dart';

/// Splash page presented on initial application startup.
/// Shows LoadingView while verifying session, or ErrorView with Retry if network failed.
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
            onRetry: () => ref.read(authControllerProvider.notifier).checkSession(),
          ),
        _ => const LoadingView(message: 'Connecting to XEV 9S Platform...'),
      },
    );
  }
}
