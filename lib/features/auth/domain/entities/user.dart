import 'package:equatable/equatable.dart';

/// Represents a user in the system
class User extends Equatable {
  /// The unique identifier of the user
  final String id;

  /// The username of the user
  final String username;

  /// The email address of the user
  final String? email;

  /// The full name of the user
  final String? fullName;

  /// The URL to the user's profile picture
  final String? profilePictureUrl;

  /// The role of the user
  final String? role;

  /// Whether the user is active
  final bool isActive;

  /// The date and time when the user was created
  final DateTime? createdAt;

  /// The date and time when the user was last updated
  final DateTime? updatedAt;

  /// Creates a new instance of [User]
  const User({
    required this.id,
    required this.username,
    this.email,
    this.fullName,
    this.profilePictureUrl,
    this.role,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates an empty instance of [User]
  factory User.empty() {
    return const User(
      id: '',
      username: '',
      email: null,
      fullName: null,
      profilePictureUrl: null,
      role: null,
      isActive: false,
      createdAt: null,
      updatedAt: null,
    );
  }

  /// Creates a copy of this object with the given fields replaced with the new values
  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? profilePictureUrl,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts this object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'profile_picture_url': profilePictureUrl,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }

  /// Creates an instance of [User] from a JSON map
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      role: json['role'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        fullName,
        profilePictureUrl,
        role,
        isActive,
        createdAt,
        updatedAt,
      ];

  @override
  bool get stringify => true;
}
