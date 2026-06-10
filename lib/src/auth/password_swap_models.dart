import 'package:meta/meta.dart';

import 'auth_models.dart';

/// The raw response shape returned by `POST /public/auth/sign-in`.
///
/// Unlike most other auth endpoints — which wrap the bearer in a nested
/// `token` object alongside a `user` object — this endpoint returns a flat
/// payload: `accessToken` at the top level, plus user fields inlined.
///
/// Use [toAuthResponse] when the host app would rather work with the
/// SDK-standard [AuthResponse] envelope (e.g. to keep parity with
/// [FirebaseSwapClient]).
@immutable
class PasswordSignInResponse {
  /// Construct.
  const PasswordSignInResponse({
    required this.accessToken,
    required this.id,
    required this.username,
    required this.fullName,
    required this.roles,
    required this.permissions,
    this.emailVerifiedAt,
    this.forcePasswordReset = false,
  });

  /// Decode from JSON. Tolerant of camelCase (`accessToken`) and snake_case
  /// (`access_token`) for compatibility — Laravel's serializer has been seen
  /// in both modes in this surface area.
  factory PasswordSignInResponse.fromJson(Map<String, dynamic> json) {
    return PasswordSignInResponse(
      accessToken: (json['accessToken'] ?? json['access_token']) as String,
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      fullName: (json['full_name'] ?? json['fullName'] ?? '') as String,
      roles: _readStringList(json['roles']),
      permissions: _readStringList(json['permissions']),
      emailVerifiedAt: _readDate(json['email_verified_at']),
      forcePasswordReset: (json['force_password_reset'] as bool?) ?? false,
    );
  }

  /// The Sanctum bearer. Send as `Authorization: Bearer <accessToken>`.
  final String accessToken;

  /// Primary key of the P2X `users` table.
  final int id;

  /// The login identifier — typically the email address.
  final String username;

  /// Display name. May be empty for accounts that never set one.
  final String fullName;

  /// Spatie role names the user holds.
  final List<String> roles;

  /// Per-route ability strings (e.g. `subproject:{id}` scopes).
  final List<String> permissions;

  /// When the email was verified, or `null` if not yet verified.
  final DateTime? emailVerifiedAt;

  /// When `true`, the host app must take the user through a password reset
  /// before allowing any other authenticated action. Set by the server when
  /// an admin forces a reset.
  final bool forcePasswordReset;

  /// Encode back to the standard Laravel JSON shape (snake_case fields).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'id': id,
      'username': username,
      'full_name': fullName,
      'roles': roles,
      'permissions': permissions,
      if (emailVerifiedAt != null)
        'email_verified_at': emailVerifiedAt!.toIso8601String(),
      'force_password_reset': forcePasswordReset,
    };
  }

  /// Adapt this flat response to the SDK's standard [AuthResponse] envelope
  /// so callers can share their post-login plumbing across PHM, NIO, IBD,
  /// and MOB. The [username] becomes [User.email] (the API uses the email
  /// as the login identifier) and [fullName] becomes [User.name].
  AuthResponse toAuthResponse() {
    return AuthResponse(
      user: User(
        id: id,
        name: fullName.isEmpty ? username : fullName,
        email: username,
        roles: roles,
        emailVerifiedAt: emailVerifiedAt,
      ),
      token: Token(accessToken: accessToken),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PasswordSignInResponse &&
        other.accessToken == accessToken &&
        other.id == id &&
        other.username == username &&
        other.fullName == fullName &&
        _listEquals(other.roles, roles) &&
        _listEquals(other.permissions, permissions) &&
        other.emailVerifiedAt == emailVerifiedAt &&
        other.forcePasswordReset == forcePasswordReset;
  }

  @override
  int get hashCode => Object.hash(
        accessToken,
        id,
        username,
        fullName,
        Object.hashAll(roles),
        Object.hashAll(permissions),
        emailVerifiedAt,
        forcePasswordReset,
      );

  @override
  String toString() =>
      'PasswordSignInResponse(id: $id, username: $username, '
      'roles: $roles, forcePasswordReset: $forcePasswordReset)';
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is List) {
    return value.map((Object? e) => e.toString()).toList(growable: false);
  }
  return const <String>[];
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
