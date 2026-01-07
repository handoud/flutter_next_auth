# Migration Guide: v1.1.0 to v1.2.1

## Overview

Version 1.2.1 introduces a more flexible and dynamic role-based access control (RBAC) system. The simple admin check has been replaced with dynamic role checking that allows you to check for any specific role.

## Breaking Changes

### Removed Methods

The following methods have been **removed**:
- `flutternext.role.checkIfUserIsAdmin()`
- `flutternext.role.getIsAdmin()`

### Migration Steps

If you were using the old admin checking methods, here's how to migrate:

#### Before (v1.1.0)

```dart
// Old way - checking if user is admin
bool isAdmin = await flutternext.role.checkIfUserIsAdmin();

if (isAdmin) {
  // Show admin features
}

// Or using cached value
bool cachedAdmin = await flutternext.role.getIsAdmin();
```

#### After (v1.2.1)

```dart
// New way - check for specific roles
bool isSystemManager = await flutternext.role.hasRole('System Manager');

if (isSystemManager) {
  // Show admin features
}

// Or check for multiple admin-like roles
bool hasAdminAccess = await flutternext.role.hasAnyRole([
  'System Manager',
  'Administrator',
]);

if (hasAdminAccess) {
  // Show admin features
}
```

## New Features

### 1. Dynamic Role Checking

You can now check for any role by name:

```dart
bool isStockManager = await flutternext.role.hasRole('Stock Manager');
bool isHRAdmin = await flutternext.role.hasRole('HR Manager');
bool isSalesUser = await flutternext.role.hasRole('Sales User');
```

### 2. Multiple Role Checks

Check if user has any or all of specified roles:

```dart
// Check if user has ANY of these roles
bool canAccessStock = await flutternext.role.hasAnyRole([
  'Stock Manager',
  'Stock User',
  'System Manager'
]);

// Check if user has ALL of these roles
bool hasFullAccess = await flutternext.role.hasAllRoles([
  'Stock Manager',
  'Sales Manager'
]);
```

### 3. Role Caching

Roles are automatically cached for offline access and better performance:

```dart
// Fetch fresh roles from server
List<String> roles = await flutternext.role.getUserRoles();

// Get cached roles (no network call)
List<String> cachedRoles = await flutternext.role.getCachedRoles();

// Force refresh when checking role
bool isAdmin = await flutternext.role.hasRole('System Manager', refresh: true);
```

### 4. Role Management

```dart
// Get all user roles
List<String> userRoles = await flutternext.role.getUserRoles();
print('User has roles: $userRoles');

// Clear cached roles
await flutternext.role.clearCachedRoles();
```

## Storage Changes

### What Changed

- **Removed**: `next_erp_is_admin` boolean storage key
- **Added**: `next_erp_user_roles` JSON array storage key

### Automatic Migration

The package will automatically handle the storage migration. Old admin flags will be ignored, and new role data will be fetched on first use.

## Benefits of the New System

1. **More Flexible**: Check for any specific role, not just admin/non-admin
2. **More Granular**: Different roles for different features (Stock Manager, HR Admin, etc.)
3. **Better Performance**: Roles are cached locally for offline access
4. **More Accurate**: Uses actual ERPNext/Frappe role assignments
5. **Future-Proof**: Easy to add new role checks without code changes

## Common Role Examples

Here are some standard ERPNext/Frappe roles you might check:

- `System Manager` - System administrator
- `Administrator` - Super administrator
- `HR Manager` / `HR User` - Human Resources
- `Stock Manager` / `Stock User` - Inventory/Stock
- `Sales Manager` / `Sales User` - Sales
- `Accounts Manager` / `Accounts User` - Accounting/Finance
- `Purchase Manager` / `Purchase User` - Purchasing

## Support

If you encounter any issues during migration, please:
1. Check the [README.md](README.md) for updated documentation
2. Review the [CHANGELOG.md](CHANGELOG.md) for all changes
3. Open an issue on [GitHub](https://github.com/handoud/flutter_next_auth/issues)
