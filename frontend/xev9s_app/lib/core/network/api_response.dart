import 'package:equatable/equatable.dart';

/// Metadata included in all API envelopes.
class ApiMeta extends Equatable {
  const ApiMeta({
    required this.requestId,
    required this.timestamp,
    this.pagination,
  });

  final String requestId;
  final DateTime timestamp;
  final Pagination? pagination;

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      requestId: json['requestId'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now().toUtc(),
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'timestamp': timestamp.toIso8601String(),
        if (pagination != null) 'pagination': pagination!.toJson(),
      };

  @override
  List<Object?> get props => [requestId, timestamp, pagination];
}

/// Pagination information attached to paginated list responses.
class Pagination extends Equatable {
  const Pagination({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'pageSize': pageSize,
        'totalItems': totalItems,
        'totalPages': totalPages,
      };

  @override
  List<Object?> get props => [page, pageSize, totalItems, totalPages];
}

/// Structured details for validation or sub-field failures.
class ApiErrorDetail extends Equatable {
  const ApiErrorDetail({
    required this.field,
    required this.issue,
  });

  final String field;
  final String issue;

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      field: json['field'] as String? ?? '',
      issue: json['issue'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'field': field,
        'issue': issue,
      };

  @override
  List<Object?> get props => [field, issue];
}

/// Standardized JSON response envelope across the XEV 9S Companion API.
class ApiResponse<T> extends Equatable {
  const ApiResponse({
    required this.success,
    this.data,
    this.meta,
    this.error,
  });

  final bool success;
  final T? data;
  final ApiMeta? meta;
  final Map<String, dynamic>? error;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) parseData,
  ) {
    final success = json['success'] as bool? ?? false;
    final rawData = json['data'];
    final rawMeta = json['meta'];
    final rawError = json['error'] as Map<String, dynamic>?;

    return ApiResponse<T>(
      success: success,
      data: rawData != null ? parseData(rawData) : null,
      meta: rawMeta is Map<String, dynamic> ? ApiMeta.fromJson(rawMeta) : null,
      error: rawError,
    );
  }

  @override
  List<Object?> get props => [success, data, meta, error];
}

/// Helper container representing paginated list results.
class PagedResult<T> extends Equatable {
  const PagedResult({
    required this.items,
    this.pagination,
  });

  final List<T> items;
  final Pagination? pagination;

  @override
  List<Object?> get props => [items, pagination];
}
