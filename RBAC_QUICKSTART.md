# Role-Based Access Control (RBAC) Quick Start

This guide helps you quickly implement role-based access control in your Flutter app using `flutter_next_auth` version 1.2.1 or higher.

## Basic Setup

After initializing the package and logging in, you can start checking user roles.

```dart
// Initialize (usually in main.dart)
await flutternext.initialize(baseUrl: 'https://your-erp.com');

// Login
final result = await flutternext.login(usr: 'user@example.com', pwd: 'password');
```

## Quick Examples

### 1. Check a Single Role

```dart
bool isStockManager = await flutternext.role.hasRole('Stock Manager');

if (isStockManager) {
  // Show stock management features
}
```

### 2. Check Multiple Roles (OR logic)

```dart
bool canAccessStock = await flutternext.role.hasAnyRole([
  'Stock Manager',
  'Stock User',
  'System Manager'
]);

if (canAccessStock) {
  // User has at least one of these roles
}
```

### 3. Check Multiple Roles (AND logic)

```dart
bool hasFullAccess = await flutternext.role.hasAllRoles([
  'Stock Manager',
  'Sales Manager'
]);

if (hasFullAccess) {
  // User has both roles
}
```

### 4. Get All User Roles

```dart
List<String> roles = await flutternext.role.getUserRoles();
print('User roles: $roles');
// Output: User roles: [Stock Manager, Sales User, All]
```

### 5. Use Cached Roles (Faster)

```dart
// Get roles without making a network call
List<String> cachedRoles = await flutternext.role.getCachedRoles();

// Check role using cache
bool isManager = await flutternext.role.hasRole('Stock Manager');
// Uses cache by default if available
```

### 6. Force Refresh from Server

```dart
// Force fetch fresh data from server
bool isAdmin = await flutternext.role.hasRole('System Manager', refresh: true);
```

## Common Use Cases

### Conditional UI Rendering

```dart
Widget build(BuildContext context) {
  return FutureBuilder<bool>(
    future: flutternext.role.hasRole('Stock Manager'),
    builder: (context, snapshot) {
      if (snapshot.data == true) {
        return ElevatedButton(
          onPressed: _deleteItem,
          child: Text('Delete'),
        );
      }
      return SizedBox.shrink(); // Hide button
    },
  );
}
```

### Navigation Guards

```dart
Future<void> navigateToStockPage() async {
  bool hasAccess = await flutternext.role.hasAnyRole([
    'Stock Manager',
    'Stock User'
  ]);

  if (hasAccess) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => StockManagementPage(),
    ));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Access denied')),
    );
  }
}
```

### Feature Toggles

```dart
Future<List<MenuItem>> getMenuItems() async {
  List<MenuItem> items = [
    MenuItem('Home', Icons.home),
  ];

  if (await flutternext.role.hasAnyRole(['Stock Manager', 'Stock User'])) {
    items.add(MenuItem('Stock', Icons.inventory));
  }

  if (await flutternext.role.hasAnyRole(['HR Manager', 'HR User'])) {
    items.add(MenuItem('HR', Icons.people));
  }

  if (await flutternext.role.hasRole('System Manager')) {
    items.add(MenuItem('Settings', Icons.settings));
  }

  return items;
}
```

### Permission-Based Actions

```dart
Future<void> performAction() async {
  // Check if user can perform action
  bool canEdit = await flutternext.role.hasAnyRole([
    'Stock Manager',
    'System Manager'
  ]);

  if (!canEdit) {
    _showError('You do not have permission to edit');
    return;
  }

  // Perform action
  await _updateItem();
}
```

## Common ERPNext Roles

Here are frequently used roles in ERPNext/Frappe systems:

| Role | Description |
|------|-------------|
| `System Manager` | Full system access |
| `Administrator` | Super admin |
| `Stock Manager` | Manage inventory |
| `Stock User` | View/use inventory |
| `Sales Manager` | Manage sales |
| `Sales User` | Process sales |
| `Accounts Manager` | Manage accounting |
| `Accounts User` | Process accounting |
| `HR Manager` | Manage human resources |
| `HR User` | HR operations |
| `Purchase Manager` | Manage purchases |
| `Purchase User` | Process purchases |

**Note:** Role names are case-sensitive!

## Best Practices

1. **Cache First**: Use cached roles for UI rendering to avoid network delays
2. **Refresh on Login**: Call `getUserRoles()` after login to cache roles
3. **Refresh Periodically**: Refresh roles occasionally or when user requests
4. **Specific Checks**: Check for specific roles rather than broad categories
5. **Combine Roles**: Use `hasAnyRole()` for OR logic, `hasAllRoles()` for AND logic

## Performance Tips

```dart
// ✅ Good: Cache roles once
await flutternext.role.getUserRoles(); // Fetches and caches
bool check1 = await flutternext.role.hasRole('Stock Manager'); // Uses cache
bool check2 = await flutternext.role.hasRole('Sales Manager'); // Uses cache

// ❌ Avoid: Refreshing unnecessarily
bool check1 = await flutternext.role.hasRole('Stock Manager', refresh: true);
bool check2 = await flutternext.role.hasRole('Sales Manager', refresh: true);
// Each call makes a network request
```

## Troubleshooting

### Roles Not Found

```dart
List<String> roles = await flutternext.role.getUserRoles();
if (roles.isEmpty) {
  print('No roles found. Check:');
  print('1. User is logged in');
  print('2. User has roles assigned in ERPNext');
  print('3. Network connection is available');
}
```

### Clear Cache

```dart
// If roles seem outdated
await flutternext.role.clearCachedRoles();
await flutternext.role.getUserRoles(); // Fetch fresh
```

## Complete Example

```dart
class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final roles = await flutternext.role.getUserRoles();
    setState(() => _roles = roles);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Column(
        children: [
          // Show user roles
          Text('Your roles: ${_roles.join(", ")}'),
          
          // Conditional buttons
          if (_roles.contains('Stock Manager'))
            ElevatedButton(
              onPressed: _goToStock,
              child: Text('Stock Management'),
            ),
          
          if (_roles.contains('System Manager'))
            ElevatedButton(
              onPressed: _goToSettings,
              child: Text('System Settings'),
            ),
        ],
      ),
    );
  }
}
```

## Need Help?

- 📖 [Full Documentation](../README.md)
- 📝 [Migration Guide](../MIGRATION_GUIDE.md)
- 💻 [Example App](../example/lib/role_based_example.dart)
- 🐛 [Report Issues](https://github.com/handoud/flutter_next_auth/issues)
