import 'package:equatable/equatable.dart';

/// Minimal user representation returned upon authentication and /users/me.
class UserSummary extends Equatable {
  const UserSummary({
    required this.userId,
    required this.name,
    required this.email,
  });

  final String userId;
  final String name;
  final String email;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final userId = (json['userId'] ?? json['id']) as String?;
    final name = (json['name'] ?? json['full_name']) as String?;
    final email = json['email'] as String?;

    if (userId == null || userId.isEmpty) {
      throw const FormatException('Missing required field: userId');
    }
    if (name == null) {
      throw const FormatException('Missing required field: name');
    }
    if (email == null || email.isEmpty) {
      throw const FormatException('Missing required field: email');
    }

    return UserSummary(
      userId: userId,
      name: name,
      email: email,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
      };

  @override
  List<Object?> get props => [userId, name, email];
}
