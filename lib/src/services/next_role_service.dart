import 'dart:developer' as developer;

import '../models/auth_models.dart';
import 'next_api_client.dart';
import 'next_auth_storage.dart';

/// Role and permission checks against a Frappe/ERPNext site.
///
/// ## Prefer permissions over roles
///
/// Roles are indirection: what actually gates a screen is whether the user may
/// read, write or submit a DocType, and Frappe answers that directly through
/// [canRead], [canWrite], [canSubmit] and friends. Those endpoints
/// (`frappe.client.has_permission`, `frappe.client.get_doc_permissions`) have
/// been stable since v13 and are unchanged in v16.
///
/// Role lookup is more fragile. Frappe removed the
/// `frappe.core.doctype.user.user.get_roles` endpoint in v16, so [getUserRoles]
/// falls back through several strategies and may return an empty list on sites
/// where none apply. Set [rolesMethod] to a whitelisted method of your own to
/// make it deterministic:
///
/// ```python
/// # your_app/api.py
/// @frappe.whitelist()
/// def my_roles():
///     return frappe.get_roles()
/// ```
///
/// ```dart
/// FlutterNext.instance.initialize(
///   baseUrl: '...',
///   rolesMethod: 'your_app.api.my_roles',
/// );
/// ```
class NextRoleService {
  static const String _getRolesEndpoint =
      '/api/method/frappe.core.doctype.user.user.get_roles';
  static const String _getListEndpoint = '/api/method/frappe.client.get_list';
  static const String _hasPermissionEndpoint =
      '/api/method/frappe.client.has_permission';
  static const String _docPermissionsEndpoint =
      '/api/method/frappe.client.get_doc_permissions';

  final NextApiClient _apiClient;
  final NextAuthStorage _storage;

  /// Dotted path to a whitelisted method returning the current user's roles.
  ///
  /// When set it is tried first and is the only strategy guaranteed to work on
  /// every Frappe version.
  final String? rolesMethod;

  NextRoleService({
    required NextApiClient apiClient,
    required NextAuthStorage storage,
    this.rolesMethod,
  })  : _apiClient = apiClient,
        _storage = storage;

  /// Fetches the current user's roles from the server and caches them.
  ///
  /// Strategies are tried in order until one returns data:
  ///
  /// 1. [rolesMethod], when configured.
  /// 2. `frappe.core.doctype.user.user.get_roles` — present in v13 to v15,
  ///    **removed in v16**.
  /// 3. `frappe.client.get_list` over the `Has Role` child table. This needs
  ///    read permission on the User DocType, which by default only System
  ///    Manager holds, so it usually only helps administrators.
  ///
  /// Returns an empty list when every strategy fails; the previous cache is
  /// left untouched in that case. Consider [canRead] and friends instead.
  Future<List<String>> getUserRoles() async {
    final username = await _storage.getUsername();
    if (username == null || username.isEmpty) return const <String>[];

    for (final strategy in <Future<List<String>?> Function(String)>[
      _rolesViaCustomMethod,
      _rolesViaGetRoles,
      _rolesViaHasRoleTable,
    ]) {
      final roles = await strategy(username);
      if (roles != null && roles.isNotEmpty) {
        await _storage.saveUserRoles(roles);
        return roles;
      }
    }

    developer.log(
      'Could not determine roles for $username. On Frappe v16 the get_roles '
      'endpoint was removed: set rolesMethod, or use the permission checks '
      '(canRead/canWrite/...) instead.',
      name: 'flutter_next_auth',
    );
    return const <String>[];
  }

  Future<List<String>?> _rolesViaCustomMethod(String username) async {
    final method = rolesMethod;
    if (method == null || method.isEmpty) return null;

    try {
      final response = await _apiClient.get('/api/method/$method');
      return _rolesFrom(_apiClient.parseResponse(response)['message']);
    } catch (e) {
      developer.log(
        'Custom roles method "$method" failed',
        name: 'flutter_next_auth',
        error: e,
      );
      return null;
    }
  }

  Future<List<String>?> _rolesViaGetRoles(String username) async {
    try {
      final response = await _apiClient.get(
        _getRolesEndpoint,
        query: {'uid': username},
      );
      return _rolesFrom(_apiClient.parseResponse(response)['message']);
    } on NextApiException catch (e) {
      // 404 is the expected shape on v16, where the endpoint no longer exists.
      developer.log(
        'user.get_roles unavailable (${e.statusCode})',
        name: 'flutter_next_auth',
      );
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>?> _rolesViaHasRoleTable(String username) async {
    try {
      // `Has Role` is a child table, so Frappe requires the parent DocType and
      // checks permission against it. Omitting `parent` raises PermissionError
      // on every version, which is why this must be sent.
      final response = await _apiClient.get(
        _getListEndpoint,
        query: {
          'doctype': 'Has Role',
          'parent': 'User',
          'filters': [
            ['parent', '=', username],
          ],
          'fields': ['role'],
          'limit_page_length': '0',
        },
      );

      final message = _apiClient.parseResponse(response)['message'];
      if (message is! List) return null;

      return message
          .whereType<Map>()
          .map((row) => row['role']?.toString())
          .whereType<String>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  static List<String>? _rolesFrom(dynamic message) {
    if (message is! List) return null;
    return message.map((role) => role.toString()).toList();
  }

  /// The roles cached by the last successful [getUserRoles] call.
  Future<List<String>> getCachedRoles() => _storage.getUserRoles();

  /// Whether the user holds [roleName].
  ///
  /// Uses the cache when available; pass [refresh] to force a server round trip.
  Future<bool> hasRole(String roleName, {bool refresh = false}) async {
    final roles = await _resolveRoles(refresh: refresh);
    return roles.contains(roleName);
  }

  /// Whether the user holds at least one of [roleNames].
  Future<bool> hasAnyRole(List<String> roleNames, {bool refresh = false}) async {
    final roles = await _resolveRoles(refresh: refresh);
    return roleNames.any(roles.contains);
  }

  /// Whether the user holds every one of [roleNames].
  Future<bool> hasAllRoles(List<String> roleNames, {bool refresh = false}) async {
    final roles = await _resolveRoles(refresh: refresh);
    return roleNames.every(roles.contains);
  }

  Future<List<String>> _resolveRoles({required bool refresh}) async {
    if (refresh) return getUserRoles();

    final cached = await getCachedRoles();
    if (cached.isNotEmpty) return cached;
    return getUserRoles();
  }

  /// Clears the cached roles.
  Future<void> clearCachedRoles() => _storage.clearUserRoles();

  // ---------------------------------------------------------------- permissions

  /// Whether the user holds [permType] on [doctype].
  ///
  /// Pass [docname] to check a specific document, including any User Permission
  /// or owner-only rules that apply to it. This is the check the desk itself
  /// performs, and it works on every Frappe version.
  ///
  /// ```dart
  /// if (await flutternext.role.hasPermission('Sales Invoice', permType: 'create')) {
  ///   // show the "New invoice" button
  /// }
  /// ```
  Future<bool> hasPermission(
    String doctype, {
    String docname = '',
    String permType = 'read',
  }) async {
    try {
      final response = await _apiClient.get(
        _hasPermissionEndpoint,
        query: {
          'doctype': doctype,
          'docname': docname,
          'perm_type': permType,
        },
      );

      final message = _apiClient.parseResponse(response)['message'];
      if (message is Map) {
        final granted = message['has_permission'];
        return granted == 1 || granted == true || granted == '1';
      }
      return false;
    } catch (e) {
      developer.log(
        'Permission check failed for $doctype ($permType)',
        name: 'flutter_next_auth',
        error: e,
      );
      return false;
    }
  }

  /// Every permission the user holds on a specific document.
  ///
  /// One request instead of one per permission type — prefer this when a screen
  /// needs to decide about several actions at once.
  Future<DocPermissions> getDocPermissions(String doctype, String docname) async {
    try {
      final response = await _apiClient.get(
        _docPermissionsEndpoint,
        query: {'doctype': doctype, 'docname': docname},
      );
      return DocPermissions.fromJson(_apiClient.parseResponse(response));
    } catch (e) {
      developer.log(
        'Could not read permissions for $doctype $docname',
        name: 'flutter_next_auth',
        error: e,
      );
      return const DocPermissions();
    }
  }

  /// Whether the user may read [doctype].
  Future<bool> canRead(String doctype, {String docname = ''}) =>
      hasPermission(doctype, docname: docname, permType: 'read');

  /// Whether the user may write to [doctype].
  Future<bool> canWrite(String doctype, {String docname = ''}) =>
      hasPermission(doctype, docname: docname, permType: 'write');

  /// Whether the user may create documents of [doctype].
  Future<bool> canCreate(String doctype) =>
      hasPermission(doctype, permType: 'create');

  /// Whether the user may delete [doctype] documents.
  Future<bool> canDelete(String doctype, {String docname = ''}) =>
      hasPermission(doctype, docname: docname, permType: 'delete');

  /// Whether the user may submit [doctype] documents.
  Future<bool> canSubmit(String doctype, {String docname = ''}) =>
      hasPermission(doctype, docname: docname, permType: 'submit');

  /// Whether the user may cancel [doctype] documents.
  Future<bool> canCancel(String doctype, {String docname = ''}) =>
      hasPermission(doctype, docname: docname, permType: 'cancel');
}
