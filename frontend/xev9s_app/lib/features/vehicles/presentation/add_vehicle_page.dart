import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../application/vehicles_controller.dart';

class AddVehiclePage extends ConsumerStatefulWidget {
  const AddVehiclePage({super.key});

  @override
  ConsumerState<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends ConsumerState<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _pairingCodeController = TextEditingController();
  final _nameController = TextEditingController();

  final _codeFocusNode = FocusNode();
  final _nameFocusNode = FocusNode();

  bool _isLoading = false;
  String? _bannerError;
  Map<String, String> _fieldErrors = {};
  bool _hasUserInteracted = false;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_onFieldChanged);
    _pairingCodeController.addListener(_onFieldChanged);
    _nameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {
      _bannerError = null;
      _fieldErrors = {};
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _pairingCodeController.dispose();
    _nameController.dispose();
    _codeFocusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormInputValid {
    final idErr = Validators.required(_identifierController.text, 'Vehicle identifier');
    final codeErr = Validators.required(_pairingCodeController.text, 'Pairing code') ??
        Validators.digitsOnly(_pairingCodeController.text) ??
        Validators.exactLength(_pairingCodeController.text, AppConstants.pairingCodeLength,
            'Pairing code must be exactly ${AppConstants.pairingCodeLength} digits.');
    return idErr == null && codeErr == null;
  }

  Future<void> _submit() async {
    setState(() => _hasUserInteracted = true);
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
      _bannerError = null;
      _fieldErrors = {};
    });

    try {
      await ref.read(vehiclesControllerProvider.notifier).associate(
            identifier: _identifierController.text,
            pairingCode: _pairingCodeController.text,
            name: _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : null,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle added')),
      );
      context.pop();
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _bannerError = e.displayMessage;
        _fieldErrors = e.fieldErrors;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bannerError = 'Something went wrong. Please try again.';
      });
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
      appBar: AppBar(
        title: const Text('Add Vehicle'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                      'Pair Your XEV 9S',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your vehicle identifier and pairing code shown on the in-vehicle display.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (_bannerError != null) ...[
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
                                _bannerError!,
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

                    // Identifier
                    TextFormField(
                      key: const Key('add-vehicle-identifier'),
                      controller: _identifierController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Vehicle identifier (VIN)',
                        hintText: 'e.g. XEV9S-2026-0001',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        border: const OutlineInputBorder(),
                        errorText: _fieldErrors['vehicleIdentifier'] ?? _fieldErrors['identifier'],
                      ),
                      validator: (val) =>
                          Validators.required(val, 'Vehicle identifier'),
                      onFieldSubmitted: (_) => _codeFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Pairing code
                    TextFormField(
                      key: const Key('add-vehicle-code'),
                      controller: _pairingCodeController,
                      focusNode: _codeFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      maxLength: AppConstants.pairingCodeLength,
                      decoration: InputDecoration(
                        labelText: 'Pairing code',
                        hintText: '6-digit numeric code',
                        prefixIcon: const Icon(Icons.lock_clock_outlined),
                        border: const OutlineInputBorder(),
                        errorText: _fieldErrors['pairingCode'],
                      ),
                      validator: (val) {
                        return Validators.required(val, 'Pairing code') ??
                            Validators.digitsOnly(val) ??
                            Validators.exactLength(val, AppConstants.pairingCodeLength,
                                'Must be exactly ${AppConstants.pairingCodeLength} digits.');
                      },
                      onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Optional friendly name
                    TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Friendly name (optional)',
                        hintText: "e.g. Aarav's 9S",
                        prefixIcon: Icon(Icons.edit_outlined),
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const Key('add-vehicle-submit'),
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
                            : const Text('Add Vehicle'),
                      ),
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
