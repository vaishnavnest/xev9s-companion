import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/network/api_exception.dart';
import 'empty_state.dart';
import 'error_view.dart';
import 'loading_view.dart';

/// Generic widget for safely rendering Riverpod [AsyncValue] states.
/// Handles loading, error (converted to AppError), empty state, and data.
/// Preserves previous data during pull-to-refresh without flashing a spinner.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.empty,
    this.isEmpty,
    this.loadingMessage,
  });

  final AsyncValue<T> value;
  final Widget Function(T) data;
  final VoidCallback? onRetry;
  final Widget? empty;
  final bool Function(T)? isEmpty;
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    // When refreshing with previous data, keep showing the data without flashing a loading spinner
    if (value.hasValue && (value.isRefreshing || value.isReloading)) {
      final val = value.requireValue;
      if (isEmpty != null && isEmpty!(val)) {
        return empty ?? const EmptyState(title: 'No data found');
      }
      return data(val);
    }

    return value.when(
      loading: () => LoadingView(message: loadingMessage),
      error: (error, stackTrace) {
        final appError = error is AppError
            ? error
            : AppError.unknown(error.toString());
        return ErrorView(
          error: appError,
          message: appError.displayMessage,
          onRetry: onRetry,
        );
      },
      data: (val) {
        if (isEmpty != null && isEmpty!(val)) {
          return empty ?? const EmptyState(title: 'No data found');
        }
        return data(val);
      },
    );
  }
}
