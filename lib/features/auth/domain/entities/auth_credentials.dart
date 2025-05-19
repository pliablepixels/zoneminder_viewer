import 'package:equatable/equatable.dart';

/// Represents the authentication credentials for a user
class AuthCredentials extends Equatable {
  /// The base URL of the ZoneMinder server
  final String baseUrl;

  /// The username for authentication
  final String username;

  /// The password for authentication
  final String password;

  /// Whether to remember the credentials
  final bool rememberMe;

  /// Creates a new instance of [AuthCredentials]
  const AuthCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.rememberMe = false,
  });

  /// Creates an empty instance of [AuthCredentials]
  factory AuthCredentials.empty() {
    return const AuthCredentials(
      baseUrl: '',
      username: '',
      password: '',
      rememberMe: false,
    );
  }


  /// Creates a copy of this object with the given fields replaced with the new values
  AuthCredentials copyWith({
    String? baseUrl,
    String? username,
    String? password,
    bool? rememberMe,
  }) {
    return AuthCredentials(
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }

  /// Converts this object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      'rememberMe': rememberMe,
    };
  }

  /// Creates an instance of [AuthCredentials] from a JSON map
  factory AuthCredentials.fromJson(Map<String, dynamic> json) {
    return AuthCredentials(
      baseUrl: json['baseUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      rememberMe: json['rememberMe'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [baseUrl, username, password, rememberMe];

  @override
  bool get stringify => true;
}
