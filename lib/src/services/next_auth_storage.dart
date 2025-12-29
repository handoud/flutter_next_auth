import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing secure storage of session data
class NextAuthStorage {
  static const String _sidKey = 'next_erp_sid';
  static const String _usernameKey = 'next_erp_username';
  static const String _fullNameKey = 'next_erp_full_name';
  static const String _isAdminKey = 'next_erp_is_admin';

  final FlutterSecureStorage _storage;

  NextAuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Store session ID (SID) securely
  Future<void> saveSid(String sid) async {
    await _storage.write(key: _sidKey, value: sid);
  }

  /// Retrieve stored session ID (SID)
  Future<String?> getSid() async {
    return await _storage.read(key: _sidKey);
  }

  /// Store username securely
  Future<void> saveUsername(String username) async {
    await _storage.write(key: _usernameKey, value: username);
  }

  /// Retrieve stored username
  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  /// Store user's full name
  Future<void> saveFullName(String fullName) async {
    await _storage.write(key: _fullNameKey, value: fullName);
  }

  /// Retrieve stored full name
  Future<String?> getFullName() async {
    return await _storage.read(key: _fullNameKey);
  }

  /// Store admin status
  Future<void> saveIsAdmin(bool isAdmin) async {
    await _storage.write(key: _isAdminKey, value: isAdmin.toString());
  }

  /// Retrieve admin status
  Future<bool> getIsAdmin() async {
    final value = await _storage.read(key: _isAdminKey);
    return value == 'true';
  }

  /// Check if session exists
  Future<bool> hasSession() async {
    final sid = await getSid();
    return sid != null && sid.isNotEmpty;
  }

  /// Clear all stored session data
  Future<void> clearSession() async {
    await _storage.delete(key: _sidKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _fullNameKey);
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
