import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';

/// A single structured section inside a legal document page.
class LegalSection {
  const LegalSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

/// Shared layout for Terms of Service and Privacy Policy screens.
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lastUpdated,
    required this.icon,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final String lastUpdated;
  final IconData icon;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/register');
            }
          },
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: accent, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subtitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Last updated: $lastUpdated',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final section in sections) ...[
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: isDark ? 0.35 : 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              section.body,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Terms of Service screen routed from registration and help pages.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Terms of Service',
      subtitle: 'XEV 9S Companion Connected Services',
      lastUpdated: 'November 2026',
      icon: Icons.description_outlined,
      sections: [
        LegalSection(
          title: '1. Acceptance of Terms',
          body:
              'By creating an account or using the XEV 9S Companion application, you agree to comply with these Terms of Service and all applicable local laws governing connected vehicle operation.',
        ),
        LegalSection(
          title: '2. Connected Vehicle Services',
          body:
              'The app provides remote telemetry, charging management, trip analytics, and remote vehicle controls. Feature availability depends on vehicle hardware, active connectivity, and regional coverage.',
        ),
        LegalSection(
          title: '3. Remote Commands & Safety',
          body:
              'You are solely responsible for ensuring your vehicle is in a safe environment before issuing remote commands such as lock, unlock, climate pre-conditioning, or charging schedule changes.',
        ),
        LegalSection(
          title: '4. Account Security',
          body:
              'Keep your login credentials confidential and notify support immediately if you suspect unauthorized access to your account or paired vehicle.',
        ),
        LegalSection(
          title: '5. Service Updates',
          body:
              'We may update app features or these terms from time to time to improve reliability and security. Continued use of the service constitutes acceptance of updated terms.',
        ),
      ],
    );
  }
}

/// Privacy Policy screen routed from registration and help pages.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Privacy Policy',
      subtitle: 'How XEV 9S Companion Protects Your Data',
      lastUpdated: 'November 2026',
      icon: Icons.privacy_tip_outlined,
      sections: [
        LegalSection(
          title: '1. Information We Collect',
          body:
              'We collect account details you provide during registration (name, email, phone number) along with vehicle identifiers and telemetry needed to deliver companion features.',
        ),
        LegalSection(
          title: '2. Vehicle Telemetry & Location',
          body:
              'Battery state of charge, charging session logs, trip summaries, and vehicle GPS coordinates are processed solely to display vehicle status, charging history, and location services.',
        ),
        LegalSection(
          title: '3. Data Security',
          body:
              'All communications between the mobile app, vehicle telematics unit, and cloud services use encrypted transport and authenticated session tokens.',
        ),
        LegalSection(
          title: '4. Retention & Your Choices',
          body:
              'You may review, update, or request deletion of your account data at any time through your Profile settings or by contacting XEV Connected Care.',
        ),
      ],
    );
  }
}
