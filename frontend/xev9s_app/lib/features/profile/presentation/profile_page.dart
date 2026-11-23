import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/application/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Log out?',
      content: 'You will need to sign in again.',
      confirmLabel: 'Log Out',
      isDestructive: true,
    );

    if (confirmed) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 16),
                if (user != null) ...[
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ] else ...[
                  const Text('Profile Page (Placeholder)'),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                    ),
                    onPressed: () => _handleLogout(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
