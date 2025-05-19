import 'package:equatable/equatable.dart';

/// Represents the response from an authentication request
class AuthResponse extends Equatable {
  /// The authentication token
  final String token;

  /// The refresh token
  final String? refreshToken;

  /// The token expiration time in seconds
  final int expiresIn;

  /// The token type (e.g., 'Bearer')
  final String tokenType;

  /// The authenticated user
  final User user;

  /// Creates a new instance of [AuthResponse]
  const AuthResponse({
    required this.token,
    this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
    required this.user,
  });

  /// Creates an empty instance of [AuthResponse]
  factory AuthResponse.empty() {
    return AuthResponse(
      token: '',
      refreshToken: null,
      expiresIn: 0,
      tokenType: 'Bearer',
      user: User.empty(),
    );
  }

  /// Creates a copy of this object with the given fields replaced with the new values
  AuthResponse copyWith({
    String? token,
    String? refreshToken,
    int? expiresIn,
    String? tokenType,
    User? user,
  }) {
    return AuthResponse(
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresIn: expiresIn ?? this.expiresIn,
      tokenType: tokenType ?? this.tokenType,
      user: user ?? this.user,
    );
  }

  /// Converts this object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }

  /// Creates an instance of [AuthResponse] from a JSON map
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int? ?? 0,
      tokenType: (json['token_type'] as String?) ?? 'Bearer',
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [
        token,
        refreshToken,
        expiresIn,
        tokenType,
        user,
      ];

  @override
  bool get stringify => true;
}
