import 'package:meta/meta.dart';

import '../subprojects/subprojects_models.dart';

// Re-export the canonical [Subproject] type from the subprojects module so
// auth-flow consumers can still get it from a single import.
export '../subprojects/subprojects_models.dart' show Subproject;

/// A P2X user as returned by `/api/dashboard/login`, `/api/user/get-data`,
/// and the integration login endpoints.
///
/// Maps Laravel's snake_case field names (`subproject_id`, `created_at`,
/// `email_verified_at`, etc.) onto Dart's camelCase. See the IBD/NIO/MOB
/// federation tables for how these IDs are linked back to per-app user
/// records.
@immutable
class User {
  /// Construct.
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.phone,
    this.subprojectId,
    this.subprojectDomain,
    this.createdAt,
    this.updatedAt,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
  });

  /// Build a [User] from the standard Laravel JSON shape.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      roles: _readStringList(json['roles']),
      subprojectId: _readInt(json['subproject_id']),
      subprojectDomain: json['subproject_domain'] as String?,
      createdAt: _readDate(json['created_at']),
      updatedAt: _readDate(json['updated_at']),
      emailVerifiedAt: _readDate(json['email_verified_at']),
      phoneVerifiedAt: _readDate(json['phone_verified_at']),
    );
  }

  /// Primary key of the P2X `users` table.
  final int id;

  /// Display name. May be the email's local-part for federated users that
  /// never set one.
  final String name;

  /// Login email. Always present.
  final String email;

  /// Optional phone (E.164 preferred). Used by MOB / IBD signup flows.
  final String? phone;

  /// Spatie role names the user holds on the current subproject. Empty if
  /// the endpoint didn't include them.
  final List<String> roles;

  /// FK into `subprojects` — the subproject this user is scoped to, if any.
  final int? subprojectId;

  /// Convenience copy of the subproject's domain (e.g. `crohnie.ai`).
  /// Saves a join when all the caller needs is the domain string.
  final String? subprojectDomain;

  /// Server-emitted creation timestamp.
  final DateTime? createdAt;

  /// Server-emitted last-modified timestamp.
  final DateTime? updatedAt;

  /// When the email was verified, or `null` if not yet verified.
  final DateTime? emailVerifiedAt;

  /// When the phone was verified, or `null` if not yet verified.
  final DateTime? phoneVerifiedAt;

  /// Encode this user back to the standard Laravel JSON shape.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      'roles': roles,
      if (subprojectId != null) 'subproject_id': subprojectId,
      if (subprojectDomain != null) 'subproject_domain': subprojectDomain,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (emailVerifiedAt != null)
        'email_verified_at': emailVerifiedAt!.toIso8601String(),
      if (phoneVerifiedAt != null)
        'phone_verified_at': phoneVerifiedAt!.toIso8601String(),
    };
  }

  /// Return a copy with the given fields replaced.
  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    List<String>? roles,
    int? subprojectId,
    String? subprojectDomain,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? emailVerifiedAt,
    DateTime? phoneVerifiedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      subprojectId: subprojectId ?? this.subprojectId,
      subprojectDomain: subprojectDomain ?? this.subprojectDomain,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.phone == phone &&
        _listEquals(other.roles, roles) &&
        other.subprojectId == subprojectId &&
        other.subprojectDomain == subprojectDomain &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.emailVerifiedAt == emailVerifiedAt &&
        other.phoneVerifiedAt == phoneVerifiedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        email,
        phone,
        Object.hashAll(roles),
        subprojectId,
        subprojectDomain,
        createdAt,
        updatedAt,
        emailVerifiedAt,
        phoneVerifiedAt,
      );

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, '
        'roles: $roles, subprojectId: $subprojectId)';
  }
}

/// A bearer token issued by the P2X API.
///
/// P2X uses Laravel Sanctum, which usually issues access tokens only —
/// [refreshToken] and [expiresAt] are optional and will be `null` for most
/// setups.
@immutable
class Token {
  /// Construct.
  const Token({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.tokenType = 'Bearer',
  });

  /// Build a [Token] from the standard JSON shape.
  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: _readDate(json['expires_at']),
      tokenType: (json['token_type'] as String?) ?? 'Bearer',
    );
  }

  /// The Sanctum bearer token. Send as `Authorization: Bearer <accessToken>`.
  final String accessToken;

  /// Optional refresh token. Most Sanctum setups don't issue these.
  final String? refreshToken;

  /// Optional expiry. `null` means "no known expiry" — the server will
  /// reject the token when it's actually expired.
  final DateTime? expiresAt;

  /// Always `Bearer` for the Sanctum case. Kept as a field so the SDK can
  /// support other schemes in the future without an API break.
  final String tokenType;

  /// Encode this token back to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      'token_type': tokenType,
    };
  }

  /// Return a copy with the given fields replaced.
  Token copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? tokenType,
  }) {
    return Token(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      tokenType: tokenType ?? this.tokenType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Token &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.expiresAt == expiresAt &&
        other.tokenType == tokenType;
  }

  @override
  int get hashCode =>
      Object.hash(accessToken, refreshToken, expiresAt, tokenType);

  @override
  String toString() {
    // Intentionally redacts the token value — do NOT include accessToken
    // here, or refreshToken. Toggling this would leak Sanctum bearers into
    // logs / crash reports.
    return 'Token(tokenType: $tokenType, '
        'hasRefresh: ${refreshToken != null}, '
        'expiresAt: $expiresAt)';
  }
}

/// The composite response returned by the auth endpoints — user, token, and
/// optional subproject context.
@immutable
class AuthResponse {
  /// Construct.
  const AuthResponse({
    required this.user,
    required this.token,
    this.subproject,
  });

  /// Build an [AuthResponse] from JSON.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final subprojectJson = json['subproject'];
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      token: Token.fromJson(json['token'] as Map<String, dynamic>),
      subproject: subprojectJson is Map<String, dynamic>
          ? Subproject.fromJson(subprojectJson)
          : null,
    );
  }

  /// The authenticated user.
  final User user;

  /// The newly minted bearer.
  final Token token;

  /// Active subproject context, when applicable.
  final Subproject? subproject;

  /// Encode back to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': user.toJson(),
      'token': token.toJson(),
      if (subproject != null) 'subproject': subproject!.toJson(),
    };
  }

  /// Return a copy with the given fields replaced.
  AuthResponse copyWith({
    User? user,
    Token? token,
    Subproject? subproject,
  }) {
    return AuthResponse(
      user: user ?? this.user,
      token: token ?? this.token,
      subproject: subproject ?? this.subproject,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthResponse &&
        other.user == user &&
        other.token == token &&
        other.subproject == subproject;
  }

  @override
  int get hashCode => Object.hash(user, token, subproject);

  @override
  String toString() {
    // Use Token.toString which is itself redacted — safe to compose.
    return 'AuthResponse(user: $user, token: $token, subproject: $subproject)';
  }
}

// ─── helpers ─────────────────────────────────────────────────────────────────

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return null;
}

int? _readInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
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
