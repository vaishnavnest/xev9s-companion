import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/network/api_exception.dart';
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
      // Navigation is handled automatically by router listening to authControllerProvider
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _generalError = e.displayMessage;
        _fieldErrors = e.fieldErrors;
      });
      // Keep entered identifier, clear password on authentication failure
      _isClearingPassword = true;
      _passwordController.clear();
      _isClearingPassword = false;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generalError = 'Something went wrong. Please try again.';
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isSessionExpired = authState is AuthUnauthenticated &&
        authState.reason == UnauthenticatedReason.sessionExpired;

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
                    Icon(
                      Icons.electric_car_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome to XEV 9S',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to manage your connected vehicle',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Session expired one-time notification banner
                    if (isSessionExpired) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 20, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your session has expired. Please sign in again.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
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

                    // General / non-field server error banner
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

                    // Email / identifier field
                    TextFormField(
                      key: const Key('login-identifier'),
                      controller: _identifierController,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                        errorText: _fieldErrors['identifier'] ?? _fieldErrors['email'],
                      ),
                      validator: (val) {
                        return Validators.required(val, 'Email') ?? Validators.email(val);
                      },
                      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Password field with show/hide toggle
                    TextFormField(
                      key: const Key('login-password'),
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
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
                      validator: (val) => Validators.required(val, 'Password'),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),

                    // Sign In Submit button
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const Key('login-submit'),
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
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Navigation to Register
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : () => context.go('/register'),
                          child: const Text('Create account'),
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
