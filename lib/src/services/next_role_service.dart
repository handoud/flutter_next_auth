import 'next_api_client.dart';
import 'next_auth_storage.dart';

/// Service for handling Role-Based Access Control (RBAC)
class NextRoleService {
  final NextApiClient _apiClient;
  final NextAuthStorage _storage;

  NextRoleService({
    required NextApiClient apiClient,
    required NextAuthStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  /// Fetch and cache user roles from the server
  ///
  /// Implements a 2-step verification strategy:
  /// 1. Dedicated Roles Endpoint (/api/method/frappe.core.doctype.user.user.get_roles)
  /// 2. Direct Table Query (Has Role table)
  ///
  /// Returns a list of role names assigned to the current user.
  /// The result is also cached in storage for offline access.
  Future<List<String>> getUserRoles() async {
    final username = await _storage.getUsername();
    if (username == null) return [];

    List<String> roles = [];

    // Step 1: Dedicated Roles Endpoint
    try {
      final response = await _apiClient.get(
        '/api/method/frappe.core.doctype.user.user.get_roles?uid=$username',
      );
      final data = _apiClient.parseResponse(response);
      if (data['message'] != null) {
        roles = List<String>.from(data['message']);
      }
    } catch (e) {
      // Fallback to Step 2 if Step 1 fails
      print('Role fetch Step 1 failed: $e');
    }

    // Step 2: Direct Table Query (Fallback Method)
    if (roles.isEmpty) {
      try {
        final filterParam = '[["parent", "=", "$username"]]';
        final response = await _apiClient.get(
          '/api/resource/Has Role?filters=$filterParam&fields=["role"]',
        );
        final data = _apiClient.parseResponse(response);
        if (data['data'] != null) {
          final list = data['data'] as List;
          roles = list.map((e) => e['role'] as String).toList();
        }
      } catch (e) {
        // Both methods failed or returned no data
        print('Role fetch Step 2 failed: $e');
      }
    }

    // Cache the roles for offline access
    if (roles.isNotEmpty) {
      await _storage.saveUserRoles(roles);
    }

    return roles;
  }

  /// Get cached user roles from storage
  ///
  /// Returns the list of roles that were previously fetched and cached.
  /// Useful for offline access or quick checks without network calls.
  Future<List<String>> getCachedRoles() async {
    return await _storage.getUserRoles();
  }

  /// Check if the current user has a specific role
  ///
  /// This method first tries to get cached roles, then falls back to
  /// fetching from the server if no cached data is available.
  ///
  /// Example:
  /// ```dart
  /// bool isStockManager = await flutternext.role.hasRole('Stock Manager');
  /// bool isHRAdmin = await flutternext.role.hasRole('HR Admin');
  /// ```
  ///
  /// [roleName] - The exact name of the role to check (case-sensitive)
  /// [refresh] - If true, fetches fresh data from server instead of using cache
  ///
  /// Returns true if the user has the specified role, false otherwise.
  Future<bool> hasRole(String roleName, {bool refresh = false}) async {
    List<String> roles;

    if (refresh) {
      roles = await getUserRoles();
    } else {
      roles = await getCachedRoles();
      // If no cached roles, fetch from server
      if (roles.isEmpty) {
        roles = await getUserRoles();
      }
    }

    return roles.contains(roleName);
  }

  /// Check if the current user has any of the specified roles
  ///
  /// Useful when you want to check if a user has at least one role
  /// from a list of acceptable roles.
  ///
  /// Example:
  /// ```dart
  /// bool canAccessStock = await flutternext.role.hasAnyRole([
  ///   'Stock Manager',
  ///   'Stock User',
  ///   'System Manager'
  /// ]);
  /// ```
  ///
  /// [roleNames] - List of role names to check against
  /// [refresh] - If true, fetches fresh data from server instead of using cache
  ///
  /// Returns true if the user has at least one of the specified roles.
  Future<bool> hasAnyRole(List<String> roleNames,
      {bool refresh = false}) async {
    List<String> roles;

    if (refresh) {
      roles = await getUserRoles();
    } else {
      roles = await getCachedRoles();
      if (roles.isEmpty) {
        roles = await getUserRoles();
      }
    }

    return roles.any((role) => roleNames.contains(role));
  }

  /// Check if the current user has all of the specified roles
  ///
  /// Useful when you need to verify that a user has multiple specific roles.
  ///
  /// Example:
  /// ```dart
  /// bool hasFullAccess = await flutternext.role.hasAllRoles([
  ///   'Stock Manager',
  ///   'Sales Manager'
  /// ]);
  /// ```
  ///
  /// [roleNames] - List of role names that must all be present
  /// [refresh] - If true, fetches fresh data from server instead of using cache
  ///
  /// Returns true if the user has all of the specified roles.
  Future<bool> hasAllRoles(List<String> roleNames,
      {bool refresh = false}) async {
    List<String> roles;

    if (refresh) {
      roles = await getUserRoles();
    } else {
      roles = await getCachedRoles();
      if (roles.isEmpty) {
        roles = await getUserRoles();
      }
    }

    return roleNames.every((roleName) => roles.contains(roleName));
  }

  /// Clear cached role data
  Future<void> clearCachedRoles() async {
    await _storage.clearUserRoles();
  }
}
