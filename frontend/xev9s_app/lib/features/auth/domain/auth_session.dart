import 'package:equatable/equatable.dart';
import 'user_summary.dart';

/// Active authentication session tokens and authenticated user summary.
class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final UserSummary user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final accessToken = (json['accessToken'] ?? json['access_token']) as String?;
    final refreshToken = (json['refreshToken'] ?? json['refresh_token']) as String?;
    final expiresIn = ((json['expiresIn'] ?? json['expires_in']) as num?)?.toInt();
    final tokenType = (json['tokenType'] ?? json['token_type']) as String? ?? 'Bearer';
    final userJson = json['user'];

    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('Missing required field: accessToken');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const FormatException('Missing required field: refreshToken');
    }
    if (expiresIn == null) {
      throw const FormatException('Missing required field: expiresIn');
    }
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid required field: user');
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      tokenType: tokenType,
      user: UserSummary.fromJson(userJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresIn': expiresIn,
        'tokenType': tokenType,
        'user': user.toJson(),
      };

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn, tokenType, user];
}
