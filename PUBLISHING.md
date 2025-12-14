# Flutter Next Auth - Publishing Guide

## Package Structure

```
flutter_next_auth/
├── lib/
│   ├── flutter_next_auth.dart          # Main export file
│   └── src/
│       ├── models/
│       │   └── auth_models.dart        # Data models
│       └── services/
│           ├── next_api_client.dart    # HTTP client
│           ├── next_auth_service.dart  # Auth logic
│           └── next_auth_storage.dart  # Secure storage
├── example/
│   ├── lib/
│   │   └── main.dart                   # Example app
│   └── pubspec.yaml
├── analysis_options.yaml
├── CHANGELOG.md
├── LICENSE
├── pubspec.yaml
└── README.md
```

## Before Publishing to pub.dev

1. **Test the package**:
   ```bash
   cd flutter_next_auth
   flutter pub get
   flutter analyze
   ```

2. **Test the example app**:
   ```bash
   cd example
   flutter pub get
   flutter run
   ```

3. **Verify package score**:
   ```bash
   cd flutter_next_auth
   dart pub publish --dry-run
   ```

4. **Update version** in `pubspec.yaml` if needed

5. **Publish to pub.dev**:
   ```bash
   dart pub publish
   ```

## Using the Package Locally

Before publishing, you can use this package in your project:

### Option 1: Path dependency

In your project's `pubspec.yaml`:

```yaml
dependencies:
  flutter_next_auth:
    path: ../flutter_next_auth
```

### Option 2: Git dependency

After pushing to GitHub:

```yaml
dependencies:
  flutter_next_auth:
    git:
      url: https://github.com/yourusername/flutter_next_auth.git
```

## Package Features

✅ **Login** - Authenticate with username and password  
✅ **Logout** - Clear session and logout from server  
✅ **Relogin** - Restore session using stored SID  
✅ **Reset Password** - Send password reset email  
✅ **Change Password** - Update user password  
✅ **Get User Profile** - Fetch logged-in user info  
✅ **Secure Storage** - SID stored in flutter_secure_storage  
✅ **Session Management** - Automatic cookie handling  

## API Quick Reference

```dart
// Initialize (required first)
await flutternext.initialize(baseUrl: 'https://your-erp.com');

// Login
final result = await flutternext.login(usr: 'user', pwd: 'pass');

// Relogin (auto-login)
final result = await flutternext.relogin();

// Logout
await flutternext.logout();

// Reset password
await flutternext.resetPassword(user: 'email@example.com');

// Change password
await flutternext.changePassword(
  oldPassword: 'old',
  newPassword: 'new',
);

// Get user profile
final user = await flutternext.getUserProfile();

// Check session
bool hasSession = await flutternext.hasActiveSession();
```

## NextERP Endpoints Used

- `/api/method/login` - User login
- `/api/method/logout` - User logout
- `/api/method/frappe.core.doctype.user.user.reset_password` - Password reset
- `/api/method/frappe.core.doctype.user.user.update_password` - Change password
- `/api/method/frappe.auth.get_logged_user` - Get logged user profile

## Dependencies

- `http: ^1.1.0` - HTTP requests
- `flutter_secure_storage: ^9.0.0` - Secure data storage

## Minimum Requirements

- Dart SDK: >=3.0.0 <4.0.0
- Flutter: >=3.0.0
- NextERP/Frappe/ERPNext server with API enabled

## Support

For issues or questions, please open an issue on GitHub.
