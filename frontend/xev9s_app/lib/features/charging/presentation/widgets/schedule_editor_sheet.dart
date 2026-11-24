import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../domain/charging_schedule.dart';
import '../../domain/day_of_week.dart';
import '../charging_display_helpers.dart';
import '../providers/charging_overview_provider.dart';

/// Bottom sheet or dialog for creating, editing, and deleting a recurring charging schedule.
class ScheduleEditorSheet extends ConsumerStatefulWidget {
  const ScheduleEditorSheet({
    super.key,
    this.initialSchedule,
    this.isVehicleOffline = false,
  });

  final ChargingSchedule? initialSchedule;
  final bool isVehicleOffline;

  static Future<void> show(
    BuildContext context, {
    ChargingSchedule? initialSchedule,
    bool isVehicleOffline = false,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop) {
      return showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: ScheduleEditorSheet(
              initialSchedule: initialSchedule,
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
          child: ScheduleEditorSheet(
            initialSchedule: initialSchedule,
            isVehicleOffline: isVehicleOffline,
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<ScheduleEditorSheet> createState() =>
      _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends ConsumerState<ScheduleEditorSheet> {
  late bool _enabled;
  late ScheduleTime _startTime;
  late ScheduleTime _endTime;
  late Set<DayOfWeek> _selectedDays;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final schedule = widget.initialSchedule;
    _enabled = schedule?.enabled ?? true;
    _startTime = schedule?.startTime ?? const ScheduleTime(hour: 22, minute: 0);
    _endTime = schedule?.endTime ?? const ScheduleTime(hour: 6, minute: 0);
    _selectedDays = schedule?.daysOfWeek.isNotEmpty == true
        ? Set<DayOfWeek>.from(schedule!.daysOfWeek)
        : {
            DayOfWeek.mon,
            DayOfWeek.tue,
            DayOfWeek.wed,
            DayOfWeek.thu,
            DayOfWeek.fri,
          };
  }

  bool get _hasChanged {
    final init = widget.initialSchedule;
    if (init == null) return true;
    return _enabled != init.enabled ||
        _startTime != init.startTime ||
        _endTime != init.endTime ||
        !_setEquals(_selectedDays, init.daysOfWeek);
  }

  bool _setEquals(Set<DayOfWeek> a, Set<DayOfWeek> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  String? get _validationError {
    final timeErr = Validators.scheduleTimes(
      _startTime.toApi(),
      _endTime.toApi(),
    );
    if (timeErr != null) return timeErr;

    final daysErr = Validators.scheduleDays(_selectedDays, _enabled);
    if (daysErr != null) return daysErr;

    return null;
  }

  bool get _isValid => _validationError == null;

  bool get _isOvernight =>
      (_endTime.hour < _startTime.hour) ||
      (_endTime.hour == _startTime.hour && _endTime.minute < _startTime.minute);

  Future<bool> _onWillPop() async {
    if (!_hasChanged || _isSaving) return true;
    return ConfirmDialog.show(
      context,
      title: 'Discard changes?',
      content: 'You have unsaved changes to your schedule. Are you sure you want to discard them?',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      isDestructive: true,
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startTime.hour, minute: _startTime.minute),
    );
    if (picked != null) {
      setState(() {
        _startTime = ScheduleTime(hour: picked.hour, minute: picked.minute);
        _errorMessage = null;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _endTime.hour, minute: _endTime.minute),
    );
    if (picked != null) {
      setState(() {
        _endTime = ScheduleTime(hour: picked.hour, minute: picked.minute);
        _errorMessage = null;
      });
    }
  }

  void _selectWeekdays() {
    setState(() {
      _selectedDays = {
        DayOfWeek.mon,
        DayOfWeek.tue,
        DayOfWeek.wed,
        DayOfWeek.thu,
        DayOfWeek.fri,
      };
      _errorMessage = null;
    });
  }

  void _selectAllDays() {
    setState(() {
      _selectedDays = {
        DayOfWeek.mon,
        DayOfWeek.tue,
        DayOfWeek.wed,
        DayOfWeek.thu,
        DayOfWeek.fri,
        DayOfWeek.sat,
        DayOfWeek.sun,
      };
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    if (!_isValid || !_hasChanged || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final schedule = ChargingSchedule(
      enabled: _enabled,
      startTime: _startTime,
      endTime: _endTime,
      daysOfWeek: _selectedDays,
    );

    try {
      await ref
          .read(chargingOverviewProvider.notifier)
          .saveSchedule(schedule);

      if (!mounted) return;
      Navigator.of(context).pop();

      final confirmation = widget.isVehicleOffline
          ? 'Saved. It will apply when the vehicle is back online.'
          : 'Charging schedule saved.';

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
          _errorMessage = e.displayMessage;
        } else {
          _errorMessage = e.toString();
        }
      });
    }
  }

  Future<void> _deleteSchedule() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete schedule?',
      content: 'Are you sure you want to remove your recurring charging schedule?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref.read(chargingOverviewProvider.notifier).deleteSchedule();
      if (!mounted) return;
      Navigator.of(context).pop();

      final confirmation = widget.isVehicleOffline
          ? 'Saved. It will apply when the vehicle is back online.'
          : 'Charging schedule deleted.';

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
          _errorMessage = e.displayMessage;
        } else {
          _errorMessage = e.toString();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysList = [
      DayOfWeek.mon,
      DayOfWeek.tue,
      DayOfWeek.wed,
      DayOfWeek.thu,
      DayOfWeek.fri,
      DayOfWeek.sat,
      DayOfWeek.sun,
    ];

    final summary = ChargingDisplayHelpers.formatScheduleSummary(
      ChargingSchedule(
        enabled: _enabled,
        startTime: _startTime,
        endTime: _endTime,
        daysOfWeek: _selectedDays,
      ),
    );

    return PopScope(
      canPop: !_hasChanged || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Charging Schedule',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    final shouldPop = await _onWillPop();
                    if (shouldPop && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Enable switch
            SwitchListTile(
              key: const Key('schedule_enable_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Schedule'),
              subtitle: Text(
                _enabled
                    ? 'Vehicle will charge within this recurring window'
                    : 'Schedule is paused',
                style: theme.textTheme.bodySmall,
              ),
              value: _enabled,
              onChanged: _isSaving
                  ? null
                  : (val) {
                      setState(() {
                        _enabled = val;
                        _errorMessage = null;
                      });
                    },
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Time pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('start_time_button'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _pickStartTime,
                    child: Column(
                      children: [
                        Text('Start Time', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          _startTime.toApi(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('end_time_button'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSaving ? null : _pickEndTime,
                    child: Column(
                      children: [
                        Text('End Time', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          _endTime.toApi(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_isOvernight) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.nightlight_round,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ends the next day',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Days selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Days of Week',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : _selectWeekdays,
                      child: const Text('Weekdays'),
                    ),
                    TextButton(
                      onPressed: _isSaving ? null : _selectAllDays,
                      child: const Text('Every day'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: daysList.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  key: Key('day_chip_${day.wireValue}'),
                  label: Text(day.shortName),
                  selected: isSelected,
                  onSelected: _isSaving
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDays.add(day);
                            } else {
                              _selectedDays.remove(day);
                            }
                            _errorMessage = null;
                          });
                        },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Summary box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],

            const SizedBox(height: 24),

            // Save & Delete buttons
            Row(
              children: [
                if (widget.initialSchedule != null) ...[
                  IconButton(
                    key: const Key('schedule_delete_button'),
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: _isSaving ? null : _deleteSchedule,
                    tooltip: 'Delete schedule',
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('schedule_save_button'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: (_hasChanged && _isValid && !_isSaving)
                        ? _save
                        : null,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Schedule'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
