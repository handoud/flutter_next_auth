/// Result of a login operation
class LoginResult {
  final bool success;
  final String? message;
  final String? username;
  final String? fullName;
  final String? sid;

  LoginResult({
    required this.success,
    this.message,
    this.username,
    this.fullName,
    this.sid,
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
    return LoginResult(
      success: false,
      message: message,
    );
  }
}

/// Result of a logout operation
class LogoutResult {
  final bool success;
  final String? message;

  LogoutResult({
    required this.success,
    this.message,
  });

  factory LogoutResult.success() {
    return LogoutResult(success: true);
  }

  factory LogoutResult.failure(String message) {
    return LogoutResult(
      success: false,
      message: message,
    );
  }
}

/// Result of a password reset request
class PasswordResetResult {
  final bool success;
  final String? message;

  PasswordResetResult({
    required this.success,
    this.message,
  });

  factory PasswordResetResult.success([String? message]) {
    return PasswordResetResult(
      success: true,
      message: message ?? 'Password reset link sent successfully',
    );
  }

  factory PasswordResetResult.failure(String message) {
    return PasswordResetResult(
      success: false,
      message: message,
    );
  }
}

/// Result of a password change operation
class PasswordChangeResult {
  final bool success;
  final String? message;

  PasswordChangeResult({
    required this.success,
    this.message,
  });

  factory PasswordChangeResult.success([String? message]) {
    return PasswordChangeResult(
      success: true,
      message: message ?? 'Password changed successfully',
    );
  }

  factory PasswordChangeResult.failure(String message) {
    return PasswordChangeResult(
      success: false,
      message: message,
    );
  }
}

/// User profile information
class UserProfile {
  final String username;
  final String? fullName;
  final String? email;

  UserProfile({
    required this.username,
    this.fullName,
    this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['message'] ?? json['name'] ?? '',
      fullName: json['full_name'],
      email: json['email'],
    );
  }
}

/// Result of a relogin operation
class ReloginResult {
  final bool success;
  final String? message;
  final UserProfile? user;

  ReloginResult({
    required this.success,
    this.message,
    this.user,
  });

  factory ReloginResult.success(UserProfile user) {
    return ReloginResult(
      success: true,
      user: user,
    );
  }

  factory ReloginResult.failure(String message) {
    return ReloginResult(
      success: false,
      message: message,
    );
  }
}
