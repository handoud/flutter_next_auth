import 'dart:developer' as developer;

import '../models/auth_models.dart';
import 'next_api_client.dart';
import 'next_auth_storage.dart';

/// Authentication operations against a Frappe/ERPNext site.
class NextAuthService {
  static const String _loginEndpoint = '/api/method/login';
  static const String _logoutEndpoint = '/api/method/logout';
  static const String _forgotPasswordEndpoint =
      '/api/method/frappe.core.doctype.user.user.reset_password';
  static const String _updatePasswordEndpoint =
      '/api/method/frappe.core.doctype.user.user.update_password';
  static const String _getLoggedUserEndpoint =
      '/api/method/frappe.auth.get_logged_user';
  static const String _confirmOtpEndpoint =
      '/api/method/frappe.twofactor.confirm_otp_token';
  static const String _getValueEndpoint =
      '/api/method/frappe.client.get_value';

  final NextApiClient _apiClient;
  final NextAuthStorage _storage;

  /// In-memory mirror of the stored session id.
  ///
  /// Reading secure storage costs a platform-channel round trip, which on
  /// Android Keystore is routinely tens of milliseconds. Hydrating once and
  /// writing through keeps authenticated calls cheap and removes the race that
  /// per-call reads introduced when requests overlapped.
  String? _sid;
  bool _hydrated = false;

  NextAuthService({
    required NextApiClient apiClient,
    required NextAuthStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  /// Loads the stored session into memory, once.
  Future<String?> _currentSid() async {
    if (_apiClient.usesTokenAuth) return null;

    if (!_hydrated) {
      _sid = await _storage.getSid();
      _hydrated = true;
      _apiClient.setSessionId(_sid);
    }
    return _sid;
  }

  Future<void> _setSid(String? sid) async {
    _sid = sid;
    _hydrated = true;
    _apiClient.setSessionId(sid);
    if (sid != null) await _storage.saveSid(sid);
  }

  Future<void> _clearSession() async {
    _sid = null;
    _hydrated = true;
    _apiClient.setSessionId(null);
    await _storage.clearSession();
  }

  /// Ensures the client is carrying the stored session before an authenticated
  /// call. No-op under token authentication.
  Future<bool> _prepare() async {
    if (_apiClient.usesTokenAuth) return true;
    final sid = await _currentSid();
    return sid != null;
  }

  /// Signs in with a user id and password.
  ///
  /// On a site with two factor authentication enabled the returned result has
  /// [LoginResult.requiresTwoFactor] set; pass its `tmpId` and the user's code
  /// to [confirmTwoFactor] to finish.
  Future<LoginResult> login({
    required String usr,
    required String pwd,
  }) async {
    try {
      final response = await _apiClient.post(
        _loginEndpoint,
        body: {'usr': usr, 'pwd': pwd},
      );

      // Frappe answers a pending OTP with a non-2xx status and a `verification`
      // payload, so this has to be checked before the status is interpreted.
      final pending = _twoFactorFrom(response.body, usr);
      if (pending != null) return pending;

      final data = _apiClient.parseResponse(response);

      final sid = _apiClient.sessionId;
      if (sid == null) {
        return LoginResult.failure(
          'Signed in, but no session cookie was returned. On Flutter web the '
          'browser hides Set-Cookie from the app: use API key authentication '
          'there instead.',
        );
      }

      final fullName = data['full_name'] as String?;

      await _setSid(sid);
      await _storage.saveUsername(usr);
      if (fullName != null) await _storage.saveFullName(fullName);

      return LoginResult.success(username: usr, fullName: fullName, sid: sid);
    } on NextApiException catch (e) {
      return LoginResult.failure(e.message);
    } catch (e) {
      return LoginResult.failure('Login failed: $e');
    }
  }

  LoginResult? _twoFactorFrom(String body, String usr) {
    if (!body.contains('verification') && !body.contains('tmp_id')) return null;

    try {
      final decoded = _apiClient.decodeBody(body);
      if (decoded == null) return null;

      final verification = decoded['verification'];
      final tmpId = decoded['tmp_id'];
      if (verification == null && tmpId == null) return null;

      return LoginResult.twoFactorRequired(
        username: usr,
        tmpId: tmpId?.toString(),
        verification: verification is Map
            ? Map<String, dynamic>.from(verification)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Completes a two factor login with the code the user received.
  Future<LoginResult> confirmTwoFactor({
    required String usr,
    required String tmpId,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.post(
        _confirmOtpEndpoint,
        body: {'user': usr, 'tmp_id': tmpId, 'otp': otp},
      );
      _apiClient.parseResponse(response);

      final sid = _apiClient.sessionId;
      if (sid == null) {
        return LoginResult.failure('Verification succeeded but no session was issued');
      }

      await _setSid(sid);
      await _storage.saveUsername(usr);

      return LoginResult.success(username: usr, sid: sid);
    } on NextApiException catch (e) {
      return LoginResult.failure(e.message);
    } catch (e) {
      return LoginResult.failure('Verification failed: $e');
    }
  }

  /// Signs out, clearing the server session and every stored value.
  ///
  /// Local state is cleared even when the server call fails, so the app never
  /// ends up showing a signed-in UI backed by a session it cannot use.
  Future<LogoutResult> logout() async {
    try {
      await _prepare();
      await _apiClient.post(_logoutEndpoint);
      await _clearSession();
      return LogoutResult.success();
    } on NextApiException catch (e) {
      await _clearSession();
      return LogoutResult.failure(e.message);
    } catch (e) {
      await _clearSession();
      return LogoutResult.failure('Logout failed: $e');
    }
  }

  /// Emails password reset instructions to [user].
  ///
  /// Frappe rate limits this endpoint per hour; exceeding it surfaces as a
  /// failure carrying the server's message.
  Future<PasswordResetResult> resetPassword({required String user}) async {
    try {
      final response = await _apiClient.post(
        _forgotPasswordEndpoint,
        body: {'user': user},
      );
      _apiClient.parseResponse(response);
      return PasswordResetResult.success(
        'Password reset instructions sent to your email',
      );
    } on NextApiException catch (e) {
      return PasswordResetResult.failure(e.message);
    } catch (e) {
      return PasswordResetResult.failure('Password reset failed: $e');
    }
  }

  /// Changes the signed-in user's password.
  ///
  /// Frappe re-authenticates inside `update_password`, which issues a **new**
  /// session id. The new id is persisted here; without that the app keeps
  /// working until it is next launched and then finds a dead session.
  ///
  /// If the site has *Logout on Password Reset* enabled, other sessions for
  /// this user are terminated server-side.
  Future<PasswordChangeResult> changePassword({
    required String oldPassword,
    required String newPassword,
    bool logoutOtherSessions = false,
  }) async {
    try {
      if (!await _prepare()) {
        return PasswordChangeResult.failure('No active session');
      }

      final previousSid = _apiClient.sessionId;

      final response = await _apiClient.post(
        _updatePasswordEndpoint,
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'logout_all_sessions': logoutOtherSessions ? 1 : 0,
        },
      );
      _apiClient.parseResponse(response);

      final rotatedSid = _apiClient.sessionId;
      if (rotatedSid != null && rotatedSid != previousSid) {
        await _setSid(rotatedSid);
      }

      return PasswordChangeResult.success(sid: _apiClient.sessionId);
    } on NextApiException catch (e) {
      return PasswordChangeResult.failure(e.message);
    } catch (e) {
      return PasswordChangeResult.failure('Password change failed: $e');
    }
  }

  /// Restores a session from storage and verifies it against the server.
  ///
  /// The stored session is cleared **only** when the server rejects it. A
  /// timeout, an offline device or a 5xx leaves it intact and returns a failure
  /// with [ReloginResult.sessionCleared] false, so the app can retry instead of
  /// signing the user out for being on a train.
  Future<ReloginResult> relogin() async {
    try {
      if (!await _prepare()) {
        return ReloginResult.failure('No stored session found');
      }

      final response = await _apiClient.get(_getLoggedUserEndpoint);
      final data = _apiClient.parseResponse(response);

      var user = UserProfile.fromLoggedUser(data);
      if (user.username.isEmpty || user.username == 'Guest') {
        await _clearSession();
        return ReloginResult.failure(
          'Stored session is no longer valid',
          sessionCleared: true,
        );
      }

      user = await _enrich(user);

      await _storage.saveUsername(user.username);
      if (user.fullName != null) await _storage.saveFullName(user.fullName!);

      return ReloginResult.success(user);
    } on NextApiException catch (e) {
      if (e.isAuthError) {
        await _clearSession();
        return ReloginResult.failure(e.message, sessionCleared: true);
      }
      return ReloginResult.failure(e.message);
    } catch (e) {
      return ReloginResult.failure('Relogin failed: $e');
    }
  }

  /// Returns the signed-in user's profile, or null when there is no session.
  ///
  /// Never clears the stored session — use [relogin] when a rejected session
  /// should sign the user out.
  Future<UserProfile?> getUserProfile() async {
    try {
      if (!await _prepare()) return null;

      final response = await _apiClient.get(_getLoggedUserEndpoint);
      final data = _apiClient.parseResponse(response);

      final user = UserProfile.fromLoggedUser(data);
      if (user.username.isEmpty || user.username == 'Guest') return null;

      return _enrich(user);
    } catch (e) {
      developer.log(
        'Could not read the user profile',
        name: 'flutter_next_auth',
        error: e,
      );
      return null;
    }
  }

  /// Fills in full name, email and the rest from the User document.
  ///
  /// `frappe.auth.get_logged_user` returns nothing but the user id, and the
  /// follow-up read needs read permission on the User DocType, which the
  /// shipped permissions grant only to System Manager. So this is best effort:
  /// on failure the profile keeps the user id and falls back to the full name
  /// captured at login.
  Future<UserProfile> _enrich(UserProfile user) async {
    try {
      final response = await _apiClient.get(
        _getValueEndpoint,
        query: {
          'doctype': 'User',
          'filters': {'name': user.username},
          'fieldname': [
            'full_name',
            'email',
            'user_image',
            'user_type',
            'language',
            'time_zone',
          ],
        },
      );

      final data = _apiClient.parseResponse(response);
      final message = data['message'];
      if (message is Map && message.isNotEmpty) {
        return UserProfile.fromJson({
          'message': {...Map<String, dynamic>.from(message), 'name': user.username},
        });
      }
    } catch (_) {
      // Expected for non-System-Manager users; fall through to the fallback.
    }

    final storedFullName = await _storage.getFullName();
    return storedFullName == null ? user : user.copyWith(fullName: storedFullName);
  }

  /// Whether a session id is stored locally.
  ///
  /// This does **not** contact the server — a stored session may have expired.
  /// Use [validateSession] when that matters.
  Future<bool> hasStoredSession() async {
    if (_apiClient.usesTokenAuth) return true;
    return (await _currentSid()) != null;
  }

  /// Whether the stored session is still accepted by the server.
  Future<bool> validateSession() async => (await getUserProfile()) != null;

  /// Deprecated alias for [hasStoredSession].
  @Deprecated(
    'Renamed to hasStoredSession(): this only checks local storage and never '
    'contacted the server. Use validateSession() for a live check. '
    'Will be removed in 2.0.0.',
  )
  Future<bool> hasActiveSession() => hasStoredSession();

  /// The `Cookie` header for the current session, for handing to other clients.
  Future<String?> cookieHeader() async {
    await _currentSid();
    return _apiClient.cookieHeader;
  }
}
