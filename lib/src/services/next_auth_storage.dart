import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing secure storage of session data
class NextAuthStorage {
  static const String _sidKey = 'next_erp_sid';
  static const String _usernameKey = 'next_erp_username';
  static const String _fullNameKey = 'next_erp_full_name';
  static const String _userRolesKey = 'next_erp_user_roles';

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

  /// Store user roles as a JSON-encoded list
  Future<void> saveUserRoles(List<String> roles) async {
    final jsonString = jsonEncode(roles);
    await _storage.write(key: _userRolesKey, value: jsonString);
  }

  /// Retrieve stored user roles
  Future<List<String>> getUserRoles() async {
    final jsonString = await _storage.read(key: _userRolesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<String>();
    } catch (e) {
      print('Error decoding user roles: $e');
      return [];
    }
  }

  /// Clear user roles from storage
  Future<void> clearUserRoles() async {
    await _storage.delete(key: _userRolesKey);
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
    await _storage.delete(key: _userRolesKey);
  }

  /// Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
