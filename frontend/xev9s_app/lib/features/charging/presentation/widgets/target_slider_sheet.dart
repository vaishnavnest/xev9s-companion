import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/validators.dart';
import '../providers/charging_overview_provider.dart';

/// Modal bottom sheet or dialog allowing user to adjust their vehicle charging target percentage.
class TargetSliderSheet extends ConsumerStatefulWidget {
  const TargetSliderSheet({
    super.key,
    required this.initialTarget,
    this.currentBatteryPercent,
    this.isVehicleOffline = false,
  });

  final int? initialTarget;
  final double? currentBatteryPercent;
  final bool isVehicleOffline;

  static Future<void> show(
    BuildContext context, {
    required int? initialTarget,
    double? currentBatteryPercent,
    bool isVehicleOffline = false,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop) {
      return showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: TargetSliderSheet(
              initialTarget: initialTarget,
              currentBatteryPercent: currentBatteryPercent,
              isVehicleOffline: isVehicleOffline,
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: TargetSliderSheet(
            initialTarget: initialTarget,
            currentBatteryPercent: currentBatteryPercent,
            isVehicleOffline: isVehicleOffline,
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<TargetSliderSheet> createState() => _TargetSliderSheetState();
}

class _TargetSliderSheetState extends ConsumerState<TargetSliderSheet> {
  late int _selectedTarget;
  late final TextEditingController _textController;
  String? _inlineError;
  String? _serverErrorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final defaultVal = widget.initialTarget ?? 80;
    _selectedTarget = defaultVal.clamp(
      AppConstants.chargingTargetMin,
      AppConstants.chargingTargetMax,
    );
    _textController = TextEditingController(text: '$_selectedTarget');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _hasChanged => _selectedTarget != widget.initialTarget;

  bool get _isValid =>
      Validators.chargingTarget(_selectedTarget) == null && _inlineError == null;

  void _onSliderChanged(double value) {
    final rounded = value.round();
    setState(() {
      _selectedTarget = rounded;
      _textController.text = '$rounded';
      _inlineError = null;
      _serverErrorMessage = null;
    });
  }

  void _onTextChanged(String text) {
    final parsed = int.tryParse(text.trim());
    setState(() {
      if (parsed == null) {
        _inlineError = 'Please enter a valid number.';
      } else {
        _inlineError = Validators.chargingTarget(parsed);
        if (_inlineError == null) {
          _selectedTarget = parsed;
        }
      }
      _serverErrorMessage = null;
    });
  }

  Future<void> _save() async {
    if (!_isValid || !_hasChanged || _isSaving) return;

    setState(() {
      _isSaving = true;
      _serverErrorMessage = null;
    });

    try {
      final updated = await ref
          .read(chargingOverviewProvider.notifier)
          .setTarget(_selectedTarget);

      if (!mounted) return;
      Navigator.of(context).pop();

      final confirmation = widget.isVehicleOffline
          ? 'Saved. It will apply when the vehicle is back online.'
          : 'Charging target set to ${updated.targetPercent ?? _selectedTarget}%.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confirmation),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (e is AppError) {
          _serverErrorMessage =
              e.message.isNotEmpty ? e.message : e.displayMessage;
        } else {
          _serverErrorMessage = e.toString();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBatteryAboveTarget = widget.currentBatteryPercent != null &&
        widget.currentBatteryPercent! > _selectedTarget;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set Charging Target',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Limit charge level to prolong battery longevity and health.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Server error banner
          if (_serverErrorMessage != null) ...[
            Container(
              key: const Key('target_server_error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _serverErrorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Slider & numeric input
          Row(
            children: [
              Expanded(
                child: Slider(
                  key: const Key('target_slider'),
                  value: _selectedTarget.toDouble().clamp(
                        AppConstants.chargingTargetMin.toDouble(),
                        AppConstants.chargingTargetMax.toDouble(),
                      ),
                  min: AppConstants.chargingTargetMin.toDouble(),
                  max: AppConstants.chargingTargetMax.toDouble(),
                  divisions: (AppConstants.chargingTargetMax -
                          AppConstants.chargingTargetMin) ~/
                      AppConstants.chargingTargetStep,
                  label: '$_selectedTarget%',
                  onChanged: _isSaving ? null : _onSliderChanged,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: TextField(
                  key: const Key('target_input_field'),
                  controller: _textController,
                  keyboardType: TextInputType.number,
                  enabled: !_isSaving,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    suffixText: '%',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onTextChanged,
                ),
              ),
            ],
          ),

          // Inline validation error
          if (_inlineError != null) ...[
            const SizedBox(height: 4),
            Text(
              _inlineError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],

          // Non-blocking warning when target < current battery
          if (isBatteryAboveTarget && _inlineError == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Battery is already above this target',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Save button
          FilledButton(
            key: const Key('target_save_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: (_hasChanged && _isValid && !_isSaving) ? _save : null,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Target'),
          ),
        ],
      ),
    );
  }
}
