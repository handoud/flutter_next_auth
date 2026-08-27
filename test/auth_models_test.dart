import 'package:flutter_next_auth/flutter_next_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    test('parses frappe.auth.get_logged_user, which returns only the user id', () {
      final user = UserProfile.fromLoggedUser({'message': 'jane@example.com'});

      expect(user.username, 'jane@example.com');
      expect(user.fullName, isNull);
    });

    test('parses an enriched User document', () {
      final user = UserProfile.fromJson({
        'message': {
          'name': 'jane@example.com',
          'full_name': 'Jane Doe',
          'email': 'jane@example.com',
          'user_type': 'System User',
          'time_zone': 'Africa/Tunis',
        },
      });

      expect(user.username, 'jane@example.com');
      expect(user.fullName, 'Jane Doe');
      expect(user.userType, 'System User');
      expect(user.isSystemUser, isTrue);
      expect(user.timeZone, 'Africa/Tunis');
    });

    test('copyWith fills the full name captured at login', () {
      const user = UserProfile(username: 'jane@example.com');
      expect(user.copyWith(fullName: 'Jane Doe').fullName, 'Jane Doe');
      expect(user.copyWith(fullName: 'Jane Doe').username, 'jane@example.com');
    });
  });

  group('DocPermissions', () {
    test('reads Frappe integer flags', () {
      final perms = DocPermissions.fromJson({
        'message': {'read': 1, 'write': 1, 'submit': 0, 'delete': false},
      });

      expect(perms.read, isTrue);
      expect(perms.write, isTrue);
      expect(perms.submit, isFalse);
      expect(perms.delete, isFalse);
      expect(perms.has('write'), isTrue);
      expect(perms.has('cancel'), isFalse);
      expect(perms.has('nonsense'), isFalse);
    });

    test('defaults to denying everything', () {
      const perms = DocPermissions();
      expect(perms.read, isFalse);
      expect(perms.submit, isFalse);
    });
  });

  group('LoginResult', () {
    test('a two factor challenge is not a success but is not a failure either', () {
      final result = LoginResult.twoFactorRequired(
        username: 'jane@example.com',
        tmpId: 'tmp-1',
        verification: {'method': 'OTP App', 'prompt': 'Enter your code'},
      );

      expect(result.success, isFalse);
      expect(result.requiresTwoFactor, isTrue);
      expect(result.tmpId, 'tmp-1');
      expect(result.message, 'Enter your code');
    });
  });

  group('ReloginResult', () {
    test('distinguishes a rejected session from an unreachable server', () {
      final rejected = ReloginResult.failure('bad sid', sessionCleared: true);
      final offline = ReloginResult.failure('timed out');

      expect(rejected.sessionCleared, isTrue);
      expect(offline.sessionCleared, isFalse);
    });
  });
}
