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

  /// Check if the current user has admin privileges
  ///
  /// Implements a 3-step verification strategy:
  /// 1. Superuser Check (username == 'Administrator')
  /// 2. Dedicated Roles Endpoint (/api/method/frappe.core.doctype.user.user.get_roles)
  /// 3. Direct Table Query (Has Role table)
  ///
  /// Returns true if the user is an admin, false otherwise.
  /// The result is also cached in storage.
  Future<bool> checkIfUserIsAdmin() async {
    final username = await _storage.getUsername();
    if (username == null) return false;

    // Step 1: Superuser Check
    if (username.toLowerCase() == 'administrator') {
      await _storage.saveIsAdmin(true);
      return true;
    }

    List<String> roles = [];

    // Step 2: Dedicated Roles Endpoint
    try {
      final response = await _apiClient.get(
        '/api/method/frappe.core.doctype.user.user.get_roles?uid=$username',
      );
      final data = _apiClient.parseResponse(response);
      if (data['message'] != null) {
        roles = List<String>.from(data['message']);
      }
    } catch (e) {
      // Fallback to Step 3 if Step 2 fails
      print('Step 2 failed: $e');
    }

    // Step 3: Direct Table Query (Fallback Method)
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
        print('Step 3 failed: $e');
      }
    }

    // Admin Role Criteria
    bool isAdmin = roles.any((role) =>
        role == 'System Manager' ||
        role == 'Administrator' ||
        role.contains('Manager'));

    await _storage.saveIsAdmin(isAdmin);
    return isAdmin;
  }

  /// Get the cached admin status
  Future<bool> getIsAdmin() async {
    return await _storage.getIsAdmin();
  }
}
