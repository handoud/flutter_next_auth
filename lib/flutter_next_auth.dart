import 'src/models/auth_models.dart';
import 'src/services/next_api_client.dart';
import 'src/services/next_auth_service.dart';
import 'src/services/next_auth_storage.dart';
import 'src/services/next_role_service.dart';

// Export models for public use
export 'src/models/auth_models.dart';
export 'src/services/next_auth_service.dart';
export 'src/services/next_role_service.dart';

/// Main class for FlutterNext authentication
class FlutterNext {
  late final NextApiClient _apiClient;
  late final NextAuthStorage _storage;
  late final NextAuthService _authService;
  late final NextRoleService _roleService;

  bool _initialized = false;

  FlutterNext._();

  static final FlutterNext _instance = FlutterNext._();

  /// Get singleton instance
  static FlutterNext get instance => _instance;

  /// Initialize FlutterNext with base URL
  ///
  /// Must be called before using any other methods
  ///
  /// Example:
  /// ```dart
  /// await FlutterNext.instance.initialize(baseUrl: 'https://your-erp.com');
  /// ```
  Future<void> initialize({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_initialized) {
      return;
    }

    _apiClient = NextApiClient(
      baseUrl: baseUrl,
      timeout: timeout,
    );
    _storage = NextAuthStorage();
    _authService = NextAuthService(
      apiClient: _apiClient,
      storage: _storage,
    );
    _roleService = NextRoleService(
      apiClient: _apiClient,
      storage: _storage,
    );

    _initialized = true;
  }

  /// Access authentication service directly
  NextAuthService get auth {
    _checkInitialized();
    return _authService;
  }

  /// Access role management service directly
  NextRoleService get role {
    _checkInitialized();
    return _roleService;
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'FlutterNext is not initialized. Call initialize() first.',
      );
    }
  }

  /// Login with username and password
  ///
  /// Returns [LoginResult] with success status and user information
  ///
  /// Example:
  /// ```dart
  /// final result = await flutternext.login(
  ///   usr: 'username@example.com',
  ///   pwd: 'password123',
  /// );
  ///
  /// if (result.success) {
  ///   print('Logged in as ${result.username}');
  /// } else {
  ///   print('Login failed: ${result.message}');
  /// }
  /// ```
  Future<LoginResult> login({
    required String usr,
    required String pwd,
  }) async {
    _checkInitialized();
    return await _authService.login(usr: usr, pwd: pwd);
  }

  /// Logout current user
  ///
  /// Clears session data and logs out from server
  ///
  /// Example:
  /// ```dart
  /// final result = await flutternext.logout();
  /// if (result.success) {
  ///   print('Logged out successfully');
  /// }
  /// ```
  Future<LogoutResult> logout() async {
    _checkInitialized();
    return await _authService.logout();
  }

  /// Request password reset for a user
  ///
  /// Sends password reset instructions to the user's email
  ///
  /// Example:
  /// ```dart
  /// final result = await flutternext.resetPassword(
  ///   user: 'username@example.com',
  /// );
  ///
  /// if (result.success) {
  ///   print(result.message);
  /// }
  /// ```
  Future<PasswordResetResult> resetPassword({
    required String user,
  }) async {
    _checkInitialized();
    return await _authService.resetPassword(user: user);
  }

  /// Change password for currently logged-in user
  ///
  /// Requires old password and new password
  ///
  /// Example:
  /// ```dart
  /// final result = await flutternext.changePassword(
  ///   oldPassword: 'oldpass123',
  ///   newPassword: 'newpass456',
  /// );
  ///
  /// if (result.success) {
  ///   print('Password changed successfully');
  /// }
  /// ```
  Future<PasswordChangeResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _checkInitialized();
    return await _authService.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  /// Re-authenticate using stored session
  ///
  /// Attempts to restore session using stored SID
  /// Useful for auto-login on app restart
  ///
  /// Example:
  /// ```dart
  /// final result = await flutternext.relogin();
  ///
  /// if (result.success) {
  ///   print('Restored session for ${result.user?.username}');
  /// } else {
  ///   // Navigate to login screen
  ///   print('No valid session found');
  /// }
  /// ```
  Future<ReloginResult> relogin() async {
    _checkInitialized();
    return await _authService.relogin();
  }

  /// Get current logged-in user profile
  ///
  /// Returns null if no active session
  ///
  /// Example:
  /// ```dart
  /// final user = await flutternext.getUserProfile();
  /// if (user != null) {
  ///   print('Current user: ${user.username}');
  /// }
  /// ```
  Future<UserProfile?> getUserProfile() async {
    _checkInitialized();
    return await _authService.getUserProfile();
  }

  /// Check if user has an active session
  ///
  /// Example:
  /// ```dart
  /// if (await flutternext.hasActiveSession()) {
  ///   // User is logged in
  /// }
  /// ```
  Future<bool> hasActiveSession() async {
    _checkInitialized();
    return await _authService.hasActiveSession();
  }

  /// Get stored session ID (SID)
  ///
  /// Returns null if no session is stored
  Future<String?> getStoredSid() async {
    _checkInitialized();
    return await _storage.getSid();
  }

  /// Get stored username
  ///
  /// Returns null if no username is stored
  Future<String?> getStoredUsername() async {
    _checkInitialized();
    return await _storage.getUsername();
  }

  /// Get stored full name
  ///
  /// Returns null if no full name is stored
  Future<String?> getStoredFullName() async {
    _checkInitialized();
    return await _storage.getFullName();
  }

  /// Clear all stored session data
  ///
  /// Does not logout from server
  Future<void> clearStoredSession() async {
    _checkInitialized();
    await _storage.clearSession();
  }
}

/// Convenience getter for FlutterNext instance
final flutternext = FlutterNext.instance;
