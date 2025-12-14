import '../models/auth_models.dart';
import 'next_api_client.dart';
import 'next_auth_storage.dart';

/// Service for handling NextERP authentication operations
class NextAuthService {
  static const String _loginEndpoint = '/api/method/login';
  static const String _logoutEndpoint = '/api/method/logout';
  static const String _forgotPasswordEndpoint =
      '/api/method/frappe.core.doctype.user.user.reset_password';
  static const String _updatePasswordEndpoint =
      '/api/method/frappe.core.doctype.user.user.update_password';
  static const String _getUserProfileEndpoint =
      '/api/method/frappe.auth.get_logged_user';

  final NextApiClient _apiClient;
  final NextAuthStorage _storage;

  NextAuthService({
    required NextApiClient apiClient,
    required NextAuthStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  /// Login with username and password
  Future<LoginResult> login({
    required String usr,
    required String pwd,
  }) async {
    try {
      final response = await _apiClient.post(
        _loginEndpoint,
        body: {
          'usr': usr,
          'pwd': pwd,
        },
      );

      final data = _apiClient.parseResponse(response);

      // Extract session ID
      final sid = _apiClient.sessionId;
      if (sid == null) {
        return LoginResult.failure('Failed to obtain session ID');
      }

      // Get user's full name from response
      final fullName = data['full_name'] as String?;

      // Store session data
      await _storage.saveSid(sid);
      await _storage.saveUsername(usr);
      if (fullName != null) {
        await _storage.saveFullName(fullName);
      }

      return LoginResult.success(
        username: usr,
        fullName: fullName,
        sid: sid,
      );
    } on NextApiException catch (e) {
      return LoginResult.failure(e.message);
    } catch (e) {
      return LoginResult.failure('Login failed: ${e.toString()}');
    }
  }

  /// Logout current user
  Future<LogoutResult> logout() async {
    try {
      // Load session ID from storage
      final sid = await _storage.getSid();
      if (sid != null) {
        _apiClient.setSessionId(sid);
      }

      await _apiClient.post(_logoutEndpoint);

      // Clear stored session data
      await _storage.clearSession();
      _apiClient.setSessionId(null);

      return LogoutResult.success();
    } on NextApiException catch (e) {
      // Even if logout fails on server, clear local session
      await _storage.clearSession();
      _apiClient.setSessionId(null);
      return LogoutResult.failure(e.message);
    } catch (e) {
      // Even if logout fails, clear local session
      await _storage.clearSession();
      _apiClient.setSessionId(null);
      return LogoutResult.failure('Logout failed: ${e.toString()}');
    }
  }

  /// Request password reset for a user
  Future<PasswordResetResult> resetPassword({
    required String user,
  }) async {
    try {
      final response = await _apiClient.post(
        _forgotPasswordEndpoint,
        body: {
          'user': user,
        },
      );

      _apiClient.parseResponse(response);

      return PasswordResetResult.success(
        'Password reset instructions sent to your email',
      );
    } on NextApiException catch (e) {
      return PasswordResetResult.failure(e.message);
    } catch (e) {
      return PasswordResetResult.failure(
        'Password reset failed: ${e.toString()}',
      );
    }
  }

  /// Change password for currently logged-in user
  Future<PasswordChangeResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      // Load session ID from storage
      final sid = await _storage.getSid();
      if (sid == null) {
        return PasswordChangeResult.failure('No active session');
      }
      _apiClient.setSessionId(sid);

      final response = await _apiClient.post(
        _updatePasswordEndpoint,
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );

      _apiClient.parseResponse(response);

      return PasswordChangeResult.success();
    } on NextApiException catch (e) {
      return PasswordChangeResult.failure(e.message);
    } catch (e) {
      return PasswordChangeResult.failure(
        'Password change failed: ${e.toString()}',
      );
    }
  }

  /// Re-authenticate using stored session ID
  Future<ReloginResult> relogin() async {
    try {
      // Load session ID from storage
      final sid = await _storage.getSid();
      if (sid == null || sid.isEmpty) {
        return ReloginResult.failure('No stored session found');
      }

      // Set session ID in API client
      _apiClient.setSessionId(sid);

      // Try to get user profile with stored session
      final response = await _apiClient.get(_getUserProfileEndpoint);
      final data = _apiClient.parseResponse(response);

      // Parse user profile
      final user = UserProfile.fromJson(data);

      // Update stored data if needed
      if (user.fullName != null) {
        await _storage.saveFullName(user.fullName!);
      }

      return ReloginResult.success(user);
    } on NextApiException catch (e) {
      // Session is invalid, clear it
      await _storage.clearSession();
      _apiClient.setSessionId(null);
      return ReloginResult.failure(e.message);
    } catch (e) {
      // Session might be invalid, clear it
      await _storage.clearSession();
      _apiClient.setSessionId(null);
      return ReloginResult.failure('Relogin failed: ${e.toString()}');
    }
  }

  /// Get current logged-in user profile
  Future<UserProfile?> getUserProfile() async {
    try {
      // Load session ID from storage
      final sid = await _storage.getSid();
      if (sid == null) {
        return null;
      }
      _apiClient.setSessionId(sid);

      final response = await _apiClient.get(_getUserProfileEndpoint);
      final data = _apiClient.parseResponse(response);

      return UserProfile.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  /// Check if user has an active session
  Future<bool> hasActiveSession() async {
    return await _storage.hasSession();
  }
}
