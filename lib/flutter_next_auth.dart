/// Authentication, sessions and permissions for Frappe/ERPNext sites.
///
/// ```dart
/// await FlutterNext.instance.initialize(baseUrl: 'https://erp.example.com');
///
/// final result = await flutternext.login(usr: 'a@b.com', pwd: 'secret');
/// if (result.success) {
///   // ...
/// }
/// ```
library;

import 'src/models/auth_models.dart';
import 'src/services/next_api_client.dart';
import 'src/services/next_auth_service.dart';
import 'src/services/next_auth_storage.dart';
import 'src/services/next_role_service.dart';

export 'src/models/auth_models.dart';
export 'src/services/next_api_client.dart' show NextApiClient, NextApiException;
export 'src/services/next_auth_service.dart';
export 'src/services/next_role_service.dart';

/// Entry point for the package.
class FlutterNext {
  late NextApiClient _apiClient;
  late NextAuthStorage _storage;
  late NextAuthService _authService;
  late NextRoleService _roleService;

  bool _initialized = false;

  FlutterNext._();

  static final FlutterNext _instance = FlutterNext._();

  /// The shared instance.
  static FlutterNext get instance => _instance;

  /// Whether [initialize] has been called.
  bool get isInitialized => _initialized;

  /// Configures the package against a site.
  ///
  /// Must be called before anything else. Calling it again is a no-op unless
  /// [force] is set, which is useful when the app can switch sites at runtime.
  ///
  /// Provide [apiKey] and [apiSecret] to authenticate with a token instead of a
  /// session. Token authentication does not expire, works on Flutter web (where
  /// the browser hides `Set-Cookie` from the app, so session login cannot work)
  /// and skips the login call entirely.
  ///
  /// [rolesMethod] names a whitelisted method returning the current user's
  /// roles. Set it if you rely on role checks: Frappe removed its built-in
  /// roles endpoint in v16. See [NextRoleService].
  Future<void> initialize({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 30),
    String? apiKey,
    String? apiSecret,
    String? rolesMethod,
    bool force = false,
  }) async {
    if (_initialized && !force) return;

    if (_initialized) _apiClient.close();

    _apiClient = NextApiClient(
      baseUrl: baseUrl,
      timeout: timeout,
      apiKey: apiKey,
      apiSecret: apiSecret,
    );
    _storage = NextAuthStorage();
    _authService = NextAuthService(apiClient: _apiClient, storage: _storage);
    _roleService = NextRoleService(
      apiClient: _apiClient,
      storage: _storage,
      rolesMethod: rolesMethod,
    );

    _initialized = true;
  }

  /// The authentication service.
  NextAuthService get auth {
    _checkInitialized();
    return _authService;
  }

  /// The role and permission service.
  NextRoleService get role {
    _checkInitialized();
    return _roleService;
  }

  /// The underlying HTTP client, for authenticated calls this package does not
  /// wrap.
  ///
  /// ```dart
  /// final response = await flutternext.api.get(
  ///   '/api/method/frappe.client.get_count',
  ///   query: {'doctype': 'Task'},
  /// );
  /// final data = flutternext.api.parseResponse(response);
  /// ```
  NextApiClient get api {
    _checkInitialized();
    return _apiClient;
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'FlutterNext is not initialized. Call initialize() first.',
      );
    }
  }

  /// Signs in with a user id and password.
  ///
  /// Check [LoginResult.requiresTwoFactor] before treating a non-success result
  /// as a failure — sites with 2FA enabled need [confirmTwoFactor] next.
  Future<LoginResult> login({
    required String usr,
    required String pwd,
  }) async {
    _checkInitialized();
    return _authService.login(usr: usr, pwd: pwd);
  }

  /// Completes a two factor login.
  Future<LoginResult> confirmTwoFactor({
    required String usr,
    required String tmpId,
    required String otp,
  }) async {
    _checkInitialized();
    return _authService.confirmTwoFactor(usr: usr, tmpId: tmpId, otp: otp);
  }

  /// Signs out and clears stored session data.
  Future<LogoutResult> logout() async {
    _checkInitialized();
    return _authService.logout();
  }

  /// Emails password reset instructions to [user].
  Future<PasswordResetResult> resetPassword({required String user}) async {
    _checkInitialized();
    return _authService.resetPassword(user: user);
  }

  /// Changes the signed-in user's password.
  ///
  /// The session id Frappe issues during this call is stored automatically.
  Future<PasswordChangeResult> changePassword({
    required String oldPassword,
    required String newPassword,
    bool logoutOtherSessions = false,
  }) async {
    _checkInitialized();
    return _authService.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
      logoutOtherSessions: logoutOtherSessions,
    );
  }

  /// Restores the stored session and verifies it against the server.
  ///
  /// The session is only cleared when the server rejects it, so being offline
  /// no longer signs the user out. Inspect [ReloginResult.sessionCleared] to
  /// tell "please sign in again" from "we could not reach the server".
  Future<ReloginResult> relogin() async {
    _checkInitialized();
    return _authService.relogin();
  }

  /// The signed-in user's profile, or null when there is no valid session.
  Future<UserProfile?> getUserProfile() async {
    _checkInitialized();
    return _authService.getUserProfile();
  }

  /// Whether a session id is stored locally. Does not contact the server.
  Future<bool> hasStoredSession() async {
    _checkInitialized();
    return _authService.hasStoredSession();
  }

  /// Whether the stored session is still accepted by the server.
  Future<bool> validateSession() async {
    _checkInitialized();
    return _authService.validateSession();
  }

  /// Deprecated alias for [hasStoredSession].
  @Deprecated(
    'Renamed to hasStoredSession(): this only checks local storage and never '
    'contacted the server. Use validateSession() for a live check. '
    'Will be removed in 2.0.0.',
  )
  Future<bool> hasActiveSession() async {
    _checkInitialized();
    return _authService.hasStoredSession();
  }

  /// The stored session id, or null.
  Future<String?> getStoredSid() async {
    _checkInitialized();
    return _storage.getSid();
  }

  /// The stored user id, or null.
  Future<String?> getStoredUsername() async {
    _checkInitialized();
    return _storage.getUsername();
  }

  /// The stored full name, or null.
  Future<String?> getStoredFullName() async {
    _checkInitialized();
    return _storage.getFullName();
  }

  /// The `Cookie` header for the current session.
  ///
  /// Hand this to another Frappe client so the whole app shares one session:
  ///
  /// ```dart
  /// final cookie = await flutternext.cookieHeader();
  /// ```
  Future<String?> cookieHeader() async {
    _checkInitialized();
    return _authService.cookieHeader();
  }

  /// The versions of Frappe and every installed app on the site.
  ///
  /// Handy for branching on server capabilities:
  ///
  /// ```dart
  /// final versions = await flutternext.getServerVersions();
  /// final frappe = versions['frappe']?['version'];
  /// ```
  Future<Map<String, dynamic>> getServerVersions() async {
    _checkInitialized();
    final response = await _apiClient.get(
      '/api/method/frappe.utils.change_log.get_versions',
    );
    final message = _apiClient.parseResponse(response)['message'];
    return message is Map ? Map<String, dynamic>.from(message) : {};
  }

  /// Clears stored session data without contacting the server.
  Future<void> clearStoredSession() async {
    _checkInitialized();
    await _storage.clearSession();
    _apiClient.setSessionId(null);
  }

  /// Releases the HTTP client. Call when tearing down a site connection.
  void dispose() {
    if (!_initialized) return;
    _apiClient.close();
    _initialized = false;
  }
}

/// Convenience accessor for [FlutterNext.instance].
final flutternext = FlutterNext.instance;
