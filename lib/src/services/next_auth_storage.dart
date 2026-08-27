import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for session data.
///
/// Values live in the iOS Keychain / Android Keystore / libsecret. Reads are
/// platform-channel round trips and are not free, so [NextAuthService] caches
/// the session id in memory rather than reading it per request.
class NextAuthStorage {
  static const String _sidKey = 'next_erp_sid';
  static const String _usernameKey = 'next_erp_username';
  static const String _fullNameKey = 'next_erp_full_name';
  static const String _userRolesKey = 'next_erp_user_roles';

  final FlutterSecureStorage _storage;

  NextAuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Stores the session id.
  Future<void> saveSid(String sid) => _storage.write(key: _sidKey, value: sid);

  /// Reads the stored session id.
  Future<String?> getSid() => _storage.read(key: _sidKey);

  /// Stores the user id.
  Future<void> saveUsername(String username) =>
      _storage.write(key: _usernameKey, value: username);

  /// Reads the stored user id.
  Future<String?> getUsername() => _storage.read(key: _usernameKey);

  /// Stores the user's full name.
  Future<void> saveFullName(String fullName) =>
      _storage.write(key: _fullNameKey, value: fullName);

  /// Reads the stored full name.
  Future<String?> getFullName() => _storage.read(key: _fullNameKey);

  /// Caches the user's roles as a JSON array.
  Future<void> saveUserRoles(List<String> roles) =>
      _storage.write(key: _userRolesKey, value: jsonEncode(roles));

  /// Reads the cached roles, or an empty list when nothing is cached.
  Future<List<String>> getUserRoles() async {
    final jsonString = await _storage.read(key: _userRolesKey);
    if (jsonString == null || jsonString.isEmpty) return const <String>[];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return const <String>[];
      return decoded.map((role) => role.toString()).toList();
    } on FormatException catch (error) {
      developer.log(
        'Discarding corrupt cached roles',
        name: 'flutter_next_auth',
        error: error,
      );
      await clearUserRoles();
      return const <String>[];
    }
  }

  /// Removes the cached roles.
  Future<void> clearUserRoles() => _storage.delete(key: _userRolesKey);

  /// Whether a session id is stored. Does not check it against the server.
  Future<bool> hasSession() async {
    final sid = await getSid();
    return sid != null && sid.isNotEmpty;
  }

  /// Removes every value this package stores.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _sidKey),
      _storage.delete(key: _usernameKey),
      _storage.delete(key: _fullNameKey),
      _storage.delete(key: _userRolesKey),
    ]);
  }

  /// Removes **all** values in secure storage, including those written by
  /// other packages. Prefer [clearSession].
  Future<void> clearAll() => _storage.deleteAll();
}
