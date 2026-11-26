import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../application/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;
  String? _generalError;
  Map<String, String> _fieldErrors = {};
  bool _hasUserInteracted = false;
  bool _isClearingPassword = false;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_isClearingPassword) return;
    setState(() {
      _generalError = null;
      _fieldErrors = {};
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormInputValid {
    final emailErr = Validators.required(_identifierController.text, 'Email') ??
        Validators.email(_identifierController.text);
    final passwordErr = Validators.required(_passwordController.text, 'Password');
    return emailErr == null && passwordErr == null;
  }

  Future<void> _submit() async {
    setState(() => _hasUserInteracted = true);
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
      _fieldErrors = {};
    });

    try {
      await ref.read(authControllerProvider.notifier).login(
            _identifierController.text,
            _passwordController.text,
          );
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = e.displayMessage;
        _fieldErrors = e.fieldErrors;
      });
      _isClearingPassword = true;
      _passwordController.clear();
      _isClearingPassword = false;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = 'Something went wrong: $e';
      });
      _isClearingPassword = true;
      _passwordController.clear();
      _isClearingPassword = false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required ThemeData theme,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final accent = isDark ? AppTheme.accentColor : const Color(0xFF006677);
    final borderColor =
        isDark ? colorScheme.outlineVariant : const Color(0xFFE2E8F0);
    final errorBorderColor =
        isDark ? colorScheme.error : const Color(0xFFEF4444);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark
            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
            : const Color(0xFF94A3B8),
        fontSize: 14,
      ),
      errorMaxLines: 2,
      filled: true,
      fillColor: isDark ? colorScheme.surfaceContainerLow : Colors.white,
      prefixIcon: Icon(
        prefixIcon,
        color: isDark ? colorScheme.onSurfaceVariant : const Color(0xFF64748B),
        size: 20,
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errorBorderColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: errorBorderColor, width: 1.5),
      ),
      errorText: errorText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isSessionExpired = authState is AuthUnauthenticated &&
        authState.reason == UnauthenticatedReason.sessionExpired;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppTheme.accentColor : const Color(0xFF006677);
    final primaryCta = isDark ? AppTheme.accentColor : const Color(0xFF005F73);
    final primaryCtaFg = isDark ? const Color(0xFF030D11) : Colors.white;
    final titleColor = isDark ? colorScheme.onSurface : const Color(0xFF0F172A);
    final headingColor =
        isDark ? colorScheme.onSurface : const Color(0xFF0B192C);
    final subtitleColor =
        isDark ? colorScheme.onSurfaceVariant : const Color(0xFF64748B);
    final labelColor =
        isDark ? colorScheme.onSurfaceVariant : const Color(0xFF334155);
    final bodyColor =
        isDark ? colorScheme.onSurfaceVariant : const Color(0xFF475569);
    final errorBg = isDark
        ? colorScheme.errorContainer.withValues(alpha: 0.35)
        : const Color(0xFFFEF2F2);
    final errorBorder = isDark
        ? colorScheme.error.withValues(alpha: 0.5)
        : const Color(0xFFFECACA);
    final errorIconColor =
        isDark ? colorScheme.error : const Color(0xFFDC2626);
    final errorTextColor =
        isDark ? colorScheme.onErrorContainer : const Color(0xFF991B1B);

    return Scaffold(
      backgroundColor:
          isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: titleColor,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
        title: Text(
          'Sign In',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Tooltip(
                message: 'Help & Support',
                child: Material(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest
                      : const Color(0xFFF1F5F9),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.push('/help'),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 20,
                        color: bodyColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: _hasUserInteracted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Brand Card Icon
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.accentColor.withValues(alpha: 0.14)
                              : const Color(0xFFEBF7F9),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.accentColor.withValues(alpha: 0.35)
                                : const Color(0xFFCCEBF0),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.directions_car_rounded,
                              size: 40,
                              color: accent,
                            ),
                            Positioned(
                              bottom: 12,
                              child: Icon(
                                Icons.bolt_rounded,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFF030D11)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // XEV 9S Tag
                    Center(
                      child: Text(
                        'XEV 9S',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Welcome Back Heading
                    Center(
                      child: Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: headingColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Center(
                      child: Text(
                        'Sign in to access your vehicle and connected services',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Session expired notice banner
                    if (isSessionExpired) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: errorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: errorBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: errorIconColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your session has expired. Please sign in again.',
                                style: TextStyle(
                                  color: errorTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // General error banner
                    if (_generalError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: errorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: errorBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 20,
                              color: errorIconColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _generalError!,
                                style: TextStyle(
                                  color: errorTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Label
                    Text(
                      'Email',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Email / Identifier Field
                    TextFormField(
                      key: const Key('login-identifier'),
                      controller: _identifierController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        fontSize: 15,
                        color: titleColor,
                      ),
                      decoration: _buildInputDecoration(
                        theme: theme,
                        hintText: 'name@example.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        errorText:
                            _fieldErrors['identifier'] ?? _fieldErrors['email'],
                      ),
                      validator: (val) {
                        return Validators.required(val, 'Email') ??
                            Validators.email(val);
                      },
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_passwordFocusNode);
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password Label Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Password',
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please contact your administrator to reset password.'),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Password Field
                    TextFormField(
                      key: const Key('login-password'),
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        fontSize: 15,
                        color: titleColor,
                      ),
                      decoration: _buildInputDecoration(
                        theme: theme,
                        hintText: '••••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: subtitleColor,
                            size: 20,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        errorText: _fieldErrors['password'],
                      ),
                      validator: (val) {
                        return Validators.required(val, 'Password');
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 18),

                    // Remember Me Row
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (val) {
                              setState(() {
                                _rememberMe = val ?? false;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            activeColor: accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: TextStyle(
                            color: isDark
                                ? colorScheme.onSurface
                                : const Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit Button (Deep Teal / Accent)
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('login-submit'),
                        onPressed:
                            (_isFormInputValid && !_isLoading) ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryCta,
                          foregroundColor: primaryCtaFg,
                          disabledBackgroundColor:
                              primaryCta.withValues(alpha: 0.35),
                          disabledForegroundColor:
                              primaryCtaFg.withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: _isLoading ? 0 : 3,
                          shadowColor: primaryCta.withValues(alpha: 0.35),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryCtaFg,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Navigation to Register
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed:
                              _isLoading ? null : () => context.go('/register'),
                          child: Text(
                            'Register',
                            style: TextStyle(
                              color: primaryCta,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
