import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/error_codes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../application/auth_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreedToTerms = true;
  String? _generalError;
  Map<String, String> _fieldErrors = {};
  bool _hasUserInteracted = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {
      _generalError = null;
      _fieldErrors = {};
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormInputValid {
    final nameErr = Validators.required(_nameController.text, 'Full name') ??
        Validators.maxLength(_nameController.text, AppConstants.maxNameLength,
            fieldName: 'Full name');
    final emailErr = Validators.required(_emailController.text, 'Email') ??
        Validators.email(_emailController.text);
    final passwordErr =
        Validators.required(_passwordController.text, 'Password') ??
            Validators.minLength(
                _passwordController.text, AppConstants.minPasswordLength,
                fieldName: 'Password');
    final confirmErr = Validators.matches(
      _passwordController.text,
      _confirmPasswordController.text,
      'Passwords do not match.',
    );
    return nameErr == null &&
        emailErr == null &&
        passwordErr == null &&
        confirmErr == null &&
        _agreedToTerms;
  }

  Future<void> _submit() async {
    setState(() => _hasUserInteracted = true);

    if (!_agreedToTerms) {
      setState(() {
        _generalError = 'Please agree to the Terms of Service & Privacy Policy.';
      });
      return;
    }

    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
      _fieldErrors = {};
    });

    try {
      await ref.read(authControllerProvider.notifier).register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          );
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == ApiErrorCode.duplicateEmail) {
          _fieldErrors['email'] = e.displayMessage;
        } else {
          _generalError = e.displayMessage;
          _fieldErrors = e.fieldErrors;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generalError = 'Something went wrong. Please try again.';
      });
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
    String? helperText,
    String? errorText,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final focusColor = isDark ? AppTheme.accentColor : const Color(0xFF00ACC1);
    final borderColor =
        isDark ? colorScheme.outlineVariant : const Color(0xFFE2E8F0);
    final errorBorderColor =
        isDark ? colorScheme.error : const Color(0xFFEF4444);
    final mutedColor =
        isDark ? colorScheme.onSurfaceVariant : const Color(0xFF64748B);

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
      prefixIcon: Icon(prefixIcon, color: mutedColor, size: 20),
      suffixIcon: suffixIcon,
      helperText: helperText,
      helperStyle: helperText != null
          ? TextStyle(color: mutedColor, fontSize: 11)
          : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
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
        borderSide: BorderSide(color: focusColor, width: 1.5),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? colorScheme.onSurface : const Color(0xFF0F172A);
    final headingColor =
        isDark ? colorScheme.onSurface : const Color(0xFF0B192C);
    final subtitleColor =
        isDark ? colorScheme.onSurfaceVariant : const Color(0xFF64748B);
    final labelColor =
        isDark ? colorScheme.onSurfaceVariant : const Color(0xFF334155);
    final bodyColor =
        isDark ? colorScheme.onSurfaceVariant : const Color(0xFF475569);
    final linkColor = isDark ? AppTheme.accentColor : const Color(0xFF00838F);
    final controlAccent =
        isDark ? AppTheme.accentColor : const Color(0xFF00ACC1);
    final submitBg = isDark ? AppTheme.accentColor : const Color(0xFF00BCD4);
    final submitFg = isDark ? const Color(0xFF030D11) : Colors.white;
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
        toolbarHeight: 44,
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
            } else {
              context.go('/login');
            }
          },
        ),
        title: Text(
          'Create Account',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
                    // Main Title
                    Text(
                      'Create Account',
                      style: TextStyle(
                        color: headingColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      'Sign up to connect and manage your XEV 9S.',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // General Error Banner
                    if (_generalError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: errorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: errorBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 18,
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
                      const SizedBox(height: 12),
                    ],

                    // Field 1: Full Name Label
                    Text(
                      'FULL NAME',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Field 1: Full Name Input
                    TextFormField(
                      key: const Key('register-name'),
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(fontSize: 14, color: titleColor),
                      decoration: _buildInputDecoration(
                        theme: theme,
                        hintText: 'e.g. Alex Vance',
                        prefixIcon: Icons.person_outline_rounded,
                        errorText: _fieldErrors['name'],
                      ),
                      validator: (val) {
                        return Validators.required(val, 'Full name') ??
                            Validators.maxLength(
                                val, AppConstants.maxNameLength,
                                fieldName: 'Full name');
                      },
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_emailFocusNode);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Field 2: Email Label
                    Text(
                      'EMAIL',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Field 2: Email Input
                    TextFormField(
                      key: const Key('register-email'),
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(fontSize: 14, color: titleColor),
                      decoration: _buildInputDecoration(
                        theme: theme,
                        hintText: 'name@example.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        errorText: _fieldErrors['email'],
                      ),
                      validator: (val) {
                        return Validators.required(val, 'Email') ??
                            Validators.email(val);
                      },
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_passwordFocusNode);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Field 3: Password Label
                    Text(
                      'PASSWORD',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Field 3: Password Input
                    TextFormField(
                      key: const Key('register-password'),
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(fontSize: 14, color: titleColor),
                      decoration: _buildInputDecoration(
                        theme: theme,
                        hintText: 'Create a password',
                        prefixIcon: Icons.lock_outline_rounded,
                        helperText: 'Must be at least 8 characters',
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
                        return Validators.required(val, 'Password') ??
                            Validators.minLength(
                                val, AppConstants.minPasswordLength,
                                fieldName: 'Password');
                      },
                      onFieldSubmitted: (_) {
                        FocusScope.of(context)
                            .requestFocus(_confirmPasswordFocusNode);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Field 4: Confirm Password Label
                    Text(
                      'CONFIRM PASSWORD',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Field 4: Confirm Password Input
                    TextFormField(
                      key: const Key('register-confirm'),
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(fontSize: 14, color: titleColor),
                      decoration: _buildInputDecoration(
                        theme: theme,
                        hintText: 'Re-enter your password',
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: subtitleColor,
                            size: 20,
                          ),
                          tooltip: _obscureConfirm
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() {
                              _obscureConfirm = !_obscureConfirm;
                            });
                          },
                        ),
                      ),
                      validator: (val) {
                        return Validators.matches(
                          _passwordController.text,
                          val,
                          'Passwords do not match.',
                        );
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),

                    // Terms & Privacy Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged: (val) {
                              setState(() {
                                _agreedToTerms = val ?? false;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            activeColor: controlAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Wrap(
                              children: [
                                Text(
                                  'I agree to the ',
                                  style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/terms'),
                                  child: Text(
                                    'Terms of Service',
                                    style: TextStyle(
                                      color: linkColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  ' and ',
                                  style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/privacy'),
                                  child: Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      color: linkColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '.',
                                  style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        key: const Key('register-submit'),
                        onPressed:
                            (_isFormInputValid && !_isLoading) ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: submitBg,
                          foregroundColor: submitFg,
                          disabledBackgroundColor:
                              submitBg.withValues(alpha: 0.35),
                          disabledForegroundColor:
                              submitFg.withValues(alpha: 0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: _isLoading ? 0 : 3,
                          shadowColor: submitBg.withValues(alpha: 0.35),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: submitFg,
                                ),
                              )
                            : const Text(
                                'CREATE ACCOUNT',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Link back to Sign In
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
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
                              _isLoading ? null : () => context.go('/login'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SIGN IN',
                                style: TextStyle(
                                  color: linkColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: linkColor,
                              ),
                            ],
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
