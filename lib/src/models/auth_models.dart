/// Result of a login operation.
class LoginResult {
  /// Whether the login completed successfully.
  final bool success;

  /// Human readable message, populated on failure.
  final String? message;

  /// The user id (usually the email) that was authenticated.
  final String? username;

  /// The user's full name, as returned by Frappe's login endpoint.
  final String? fullName;

  /// The session id issued by the server.
  ///
  /// Treat this as a secret: never log it and never place it in a URL.
  final String? sid;

  /// True when the site has two factor authentication enabled and an OTP is
  /// required to finish signing in.
  ///
  /// When this is true, [tmpId] carries the temporary id that must be passed
  /// back to [NextAuthService.confirmTwoFactor].
  final bool requiresTwoFactor;

  /// Temporary login id issued by Frappe when 2FA is pending.
  final String? tmpId;

  /// The raw `verification` payload from Frappe, describing how the OTP was
  /// delivered (`method`, `prompt`, `setup`, ...).
  final Map<String, dynamic>? verification;

  const LoginResult({
    required this.success,
    this.message,
    this.username,
    this.fullName,
    this.sid,
    this.requiresTwoFactor = false,
    this.tmpId,
    this.verification,
  });

  factory LoginResult.success({
    required String username,
    String? fullName,
    String? sid,
  }) {
    return LoginResult(
      success: true,
      username: username,
      fullName: fullName,
      sid: sid,
    );
  }

  factory LoginResult.failure(String message) {
    return LoginResult(success: false, message: message);
  }

  /// Login was accepted but an OTP is still required.
  factory LoginResult.twoFactorRequired({
    required String username,
    String? tmpId,
    Map<String, dynamic>? verification,
    String? message,
  }) {
    return LoginResult(
      success: false,
      requiresTwoFactor: true,
      username: username,
      tmpId: tmpId,
      verification: verification,
      message: message ??
          verification?['prompt']?.toString() ??
          'A verification code is required to finish signing in',
    );
  }
}

/// Result of a logout operation.
class LogoutResult {
  final bool success;
  final String? message;

  const LogoutResult({required this.success, this.message});

  factory LogoutResult.success() => const LogoutResult(success: true);

  factory LogoutResult.failure(String message) =>
      LogoutResult(success: false, message: message);
}

/// Result of a password reset request.
class PasswordResetResult {
  final bool success;
  final String? message;

  const PasswordResetResult({required this.success, this.message});

  factory PasswordResetResult.success([String? message]) {
    return PasswordResetResult(
      success: true,
      message: message ?? 'Password reset link sent successfully',
    );
  }

  factory PasswordResetResult.failure(String message) =>
      PasswordResetResult(success: false, message: message);
}

/// Result of a password change operation.
class PasswordChangeResult {
  final bool success;
  final String? message;

  /// The session id issued by the server after the change.
  ///
  /// Frappe re-authenticates the user inside `update_password`, which rotates
  /// the session. The package stores this automatically; it is exposed here so
  /// callers sharing the session with other clients can refresh them too.
  final String? sid;

  const PasswordChangeResult({
    required this.success,
    this.message,
    this.sid,
  });

  factory PasswordChangeResult.success({String? message, String? sid}) {
    return PasswordChangeResult(
      success: true,
      message: message ?? 'Password changed successfully',
      sid: sid,
    );
  }

  factory PasswordChangeResult.failure(String message) =>
      PasswordChangeResult(success: false, message: message);
}

/// Profile information for the signed-in user.
///
/// Only [username] is always available. Frappe's `frappe.auth.get_logged_user`
/// returns nothing but the user id, so the remaining fields are filled in from
/// a best-effort follow-up read of the User document. That read requires read
/// permission on the User DocType, which by default only System Manager has,
/// so on most sites the extra fields stay null for ordinary users. [fullName]
/// additionally falls back to the value captured at login.
class UserProfile {
  /// The Frappe user id, usually an email address.
  final String username;

  final String? fullName;
  final String? email;
  final String? userImage;

  /// Either `System User` or `Website User`, when it could be read.
  final String? userType;

  final String? language;
  final String? timeZone;

  const UserProfile({
    required this.username,
    this.fullName,
    this.email,
    this.userImage,
    this.userType,
    this.language,
    this.timeZone,
  });

  /// Whether this user can access the Frappe desk.
  bool get isSystemUser => userType == 'System User';

  /// Parses the response of `frappe.auth.get_logged_user`, which is shaped
  /// `{"message": "user@example.com"}`.
  factory UserProfile.fromLoggedUser(Map<String, dynamic> json) {
    return UserProfile(
      username: json['message']?.toString() ?? json['name']?.toString() ?? '',
    );
  }

  /// Parses a User document (or a `frappe.client.get_value` result).
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final data = json['message'] is Map<String, dynamic>
        ? json['message'] as Map<String, dynamic>
        : json;

    return UserProfile(
      username: (data['name'] ??
              data['email'] ??
              (json['message'] is String ? json['message'] : null) ??
              '')
          .toString(),
      fullName: data['full_name']?.toString(),
      email: data['email']?.toString(),
      userImage: data['user_image']?.toString(),
      userType: data['user_type']?.toString(),
      language: data['language']?.toString(),
      timeZone: data['time_zone']?.toString(),
    );
  }

  UserProfile copyWith({
    String? username,
    String? fullName,
    String? email,
    String? userImage,
    String? userType,
    String? language,
    String? timeZone,
  }) {
    return UserProfile(
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      userImage: userImage ?? this.userImage,
      userType: userType ?? this.userType,
      language: language ?? this.language,
      timeZone: timeZone ?? this.timeZone,
    );
  }

  @override
  String toString() => 'UserProfile($username)';
}

/// Result of a relogin operation.
class ReloginResult {
  final bool success;
  final String? message;
  final UserProfile? user;

  /// True when the stored session was rejected by the server and has been
  /// cleared. False for transport failures, where the session is kept so the
  /// app can retry once connectivity returns.
  final bool sessionCleared;

  const ReloginResult({
    required this.success,
    this.message,
    this.user,
    this.sessionCleared = false,
  });

  factory ReloginResult.success(UserProfile user) =>
      ReloginResult(success: true, user: user);

  factory ReloginResult.failure(String message, {bool sessionCleared = false}) =>
      ReloginResult(
        success: false,
        message: message,
        sessionCleared: sessionCleared,
      );
}

/// The permissions the current user holds on a document or DocType.
///
/// Returned by `frappe.client.get_doc_permissions`.
class DocPermissions {
  final bool read;
  final bool write;
  final bool create;
  final bool delete;
  final bool submit;
  final bool cancel;
  final bool amend;
  final bool print;
  final bool email;
  final bool share;
  final bool report;

  const DocPermissions({
    this.read = false,
    this.write = false,
    this.create = false,
    this.delete = false,
    this.submit = false,
    this.cancel = false,
    this.amend = false,
    this.print = false,
    this.email = false,
    this.share = false,
    this.report = false,
  });

  static bool _flag(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value == 1 || value == true || value == '1';
  }

  factory DocPermissions.fromJson(Map<String, dynamic> json) {
    final data = json['message'] is Map
        ? Map<String, dynamic>.from(json['message'] as Map)
        : json;

    return DocPermissions(
      read: _flag(data, 'read'),
      write: _flag(data, 'write'),
      create: _flag(data, 'create'),
      delete: _flag(data, 'delete'),
      submit: _flag(data, 'submit'),
      cancel: _flag(data, 'cancel'),
      amend: _flag(data, 'amend'),
      print: _flag(data, 'print'),
      email: _flag(data, 'email'),
      share: _flag(data, 'share'),
      report: _flag(data, 'report'),
    );
  }

  /// Whether the given permission type is granted.
  bool has(String permType) {
    switch (permType.toLowerCase()) {
      case 'read':
        return read;
      case 'write':
        return write;
      case 'create':
        return create;
      case 'delete':
        return delete;
      case 'submit':
        return submit;
      case 'cancel':
        return cancel;
      case 'amend':
        return amend;
      case 'print':
        return print;
      case 'email':
        return email;
      case 'share':
        return share;
      case 'report':
        return report;
      default:
        return false;
    }
  }
}
