# Flutter Next Auth

A Flutter package for NextERP (Frappe/ERPNext) authentication with secure session management.

## Features

✅ Login with username and password  
✅ Logout functionality  
✅ Password reset request  
✅ Password change/update  
✅ Session management with secure storage (SID)  
✅ Automatic re-authentication using stored session  
✅ Get logged user profile  
✅ Simple, intuitive API  

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_next_auth: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Platform-Specific Setup

### Android

Add the following to your `android/app/src/main/AndroidManifest.xml` inside the `<application>` tag:

```xml
<application>
    <!-- Other configurations -->
    <activity
        android:name=".MainActivity"
        android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
        android:hardwareAccelerated="true"
        android:windowSoftInputMode="adjustResize">
    </activity>
</application>
```

### iOS

No additional setup required.

### Linux

```bash
sudo apt-get install libsecret-1-dev
```

## Usage

### 1. Initialize

Initialize the package with your NextERP server URL before using any authentication methods:

```dart
import 'package:flutter_next_auth/flutter_next_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize FlutterNext with your server URL
  await flutternext.initialize(
    baseUrl: 'https://your-erp-server.com',
  );
  
  runApp(MyApp());
}
```

### 2. Login

```dart
final result = await flutternext.login(
  usr: 'username@example.com',
  pwd: 'password123',
);

if (result.success) {
  print('Logged in as ${result.username}');
  print('Full name: ${result.fullName}');
  print('Session ID: ${result.sid}');
  // Navigate to home screen
} else {
  print('Login failed: ${result.message}');
  // Show error message
}
```

### 3. Relogin (Auto-Login)

Use this to restore a user's session when the app starts:

```dart
final result = await flutternext.relogin();

if (result.success) {
  print('Session restored for ${result.user?.username}');
  // Navigate to home screen
} else {
  print('No valid session: ${result.message}');
  // Navigate to login screen
}
```

### 4. Logout

```dart
final result = await flutternext.logout();

if (result.success) {
  print('Logged out successfully');
  // Navigate to login screen
} else {
  print('Logout error: ${result.message}');
}
```

### 5. Reset Password

```dart
final result = await flutternext.resetPassword(
  user: 'username@example.com',
);

if (result.success) {
  print(result.message);
  // Show success message
} else {
  print('Reset failed: ${result.message}');
}
```

### 6. Change Password

```dart
final result = await flutternext.changePassword(
  oldPassword: 'currentpass123',
  newPassword: 'newpass456',
);

if (result.success) {
  print('Password changed successfully');
} else {
  print('Change failed: ${result.message}');
}
```

### 7. Get User Profile

```dart
final user = await flutternext.getUserProfile();

if (user != null) {
  print('Username: ${user.username}');
  print('Full name: ${user.fullName}');
  print('Email: ${user.email}');
}
```

### 8. Check Active Session

```dart
bool hasSession = await flutternext.hasActiveSession();

if (hasSession) {
  print('User has an active session');
}
```

### 9. Get Stored Data

```dart
// Get stored session ID
String? sid = await flutternext.getStoredSid();

// Get stored username
String? username = await flutternext.getStoredUsername();

// Get stored full name
String? fullName = await flutternext.getStoredFullName();
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_next_auth/flutter_next_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await flutternext.initialize(
    baseUrl: 'https://demo.erpnext.com',
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Next Auth Demo',
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final result = await flutternext.relogin();
    if (result.success) {
      _navigateToHome();
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    final result = await flutternext.login(
      usr: _usernameController.text,
      pwd: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result.success) {
      _navigateToHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Login failed')),
      );
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  Future<void> _handleLogout(BuildContext context) async {
    await flutternext.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder<UserProfile?>(
          future: flutternext.getUserProfile(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final user = snapshot.data!;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Welcome, ${user.fullName ?? user.username}!'),
                  SizedBox(height: 16),
                  Text('Email: ${user.email ?? "N/A"}'),
                ],
              );
            }
            return CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}
```

## How It Works

### Session Management

1. **Login**: When you call `flutternext.login()`, the package:
   - Sends credentials to NextERP server
   - Receives a session ID (SID) in response cookies
   - Stores the SID securely using `flutter_secure_storage`
   - Returns user information

2. **Relogin**: When you call `flutternext.relogin()`, the package:
   - Retrieves the stored SID from secure storage
   - Makes a request to get the logged-in user profile
   - If successful, the session is still valid
   - If failed, clears the stored session

3. **Authenticated Requests**: All subsequent API calls automatically include the stored SID in the cookie header

4. **Logout**: Clears both server-side session and local storage

### Secure Storage

The package uses `flutter_secure_storage` to securely store:
- Session ID (SID)
- Username
- Full name

This data persists across app restarts and is encrypted on the device.

## API Reference

### Methods

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `initialize()` | `baseUrl`, `timeout?` | `Future<void>` | Initialize with server URL |
| `login()` | `usr`, `pwd` | `Future<LoginResult>` | Login with credentials |
| `logout()` | - | `Future<LogoutResult>` | Logout and clear session |
| `relogin()` | - | `Future<ReloginResult>` | Restore session from storage |
| `resetPassword()` | `user` | `Future<PasswordResetResult>` | Request password reset |
| `changePassword()` | `oldPassword`, `newPassword` | `Future<PasswordChangeResult>` | Change password |
| `getUserProfile()` | - | `Future<UserProfile?>` | Get current user info |
| `hasActiveSession()` | - | `Future<bool>` | Check if session exists |
| `getStoredSid()` | - | `Future<String?>` | Get stored session ID |
| `getStoredUsername()` | - | `Future<String?>` | Get stored username |
| `getStoredFullName()` | - | `Future<String?>` | Get stored full name |
| `clearStoredSession()` | - | `Future<void>` | Clear local session data |

### Models

- `LoginResult`: Contains success status, username, full name, and SID
- `LogoutResult`: Contains success status and message
- `ReloginResult`: Contains success status, message, and user profile
- `PasswordResetResult`: Contains success status and message
- `PasswordChangeResult`: Contains success status and message
- `UserProfile`: Contains username, full name, and email

## Error Handling

All methods return result objects with a `success` boolean and optional `message` string:

```dart
final result = await flutternext.login(usr: username, pwd: password);

if (!result.success) {
  // Handle error
  print('Error: ${result.message}');
}
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/handoud/flutter_next_auth).
