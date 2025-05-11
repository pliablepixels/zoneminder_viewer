import 'dart:convert';

class JwtUtils {
  /// Decodes a JWT and returns the payload as a Map.
  static Map<String, dynamic> decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid JWT');
    }
    final payload = base64Url.normalize(parts[1]);
    final payloadMap = json.decode(utf8.decode(base64Url.decode(payload)));
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('Invalid JWT payload');
    }
    return payloadMap;
  }

  /// Checks if the JWT is expired based on the exp claim.
  static bool isExpired(String token) {
    try {
      final payload = decodePayload(token);
      final exp = payload['exp'];
      if (exp == null) return false;
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expDate);
    } catch (_) {
      return false;
    }
  }
}
