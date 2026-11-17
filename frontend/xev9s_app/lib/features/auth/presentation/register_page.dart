import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/error_codes.dart';
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
  String? _generalError;
  Map<String, String> _fieldErrors = {};
  bool _hasUserInteracted = false;
  bool _isClearingPasswords = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_isClearingPasswords) return;
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
        Validators.maxLength(_nameController.text, AppConstants.maxNameLength, fieldName: 'Full name');
    final emailErr = Validators.required(_emailController.text, 'Email') ??
        Validators.email(_emailController.text);
    final passwordErr = Validators.password(_passwordController.text);
    final confirmErr = Validators.matches(
      _passwordController.text,
      _confirmPasswordController.text,
      'Passwords do not match.',
    );
    return nameErr == null && emailErr == null && passwordErr == null && confirmErr == null;
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
      await ref.read(authControllerProvider.notifier).register(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
          );
      // Router will automatically navigate upon authController state change
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
      _isClearingPasswords = true;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _isClearingPasswords = false;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generalError = 'Something went wrong. Please try again.';
      });
      _isClearingPasswords = true;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _isClearingPasswords = false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                    Text(
                      'Create Account',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join the XEV 9S companion platform',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (_generalError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 20, color: theme.colorScheme.onErrorContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _generalError!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
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

                    // Full name
                    TextFormField(
                      key: const Key('register-name'),
                      controller: _nameController,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                        errorText: _fieldErrors['name'],
                      ),
                      validator: (val) {
                        return Validators.required(val, 'Full name') ??
                            Validators.maxLength(val, AppConstants.maxNameLength, fieldName: 'Full name');
                      },
                      onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      key: const Key('register-email'),
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                        errorText: _fieldErrors['email'],
                      ),
                      validator: (val) {
                        return Validators.required(val, 'Email') ?? Validators.email(val);
                      },
                      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      key: const Key('register-password'),
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: 'Must be at least ${AppConstants.minPasswordLength} characters',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: const OutlineInputBorder(),
                        errorText: _fieldErrors['password'],
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: Validators.password,
                      onFieldSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextFormField(
                      key: const Key('register-confirm'),
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      obscureText: _obscureConfirm,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
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
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const Key('register-submit'),
                        onPressed: (_isFormInputValid && !_isLoading) ? _submit : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Link back to Login
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : () => context.go('/login'),
                          child: const Text('Sign in'),
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
