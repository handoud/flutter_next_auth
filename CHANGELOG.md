## 1.2.1

* **BREAKING CHANGE**: Removed `checkIfUserIsAdmin()` and `getIsAdmin()` methods
* **NEW**: Dynamic role-based access control (RBAC) system
* Added `getUserRoles()` - Fetch and cache all user roles from server
* Added `getCachedRoles()` - Get cached roles without network call
* Added `hasRole(roleName)` - Check if user has a specific role (e.g., 'Stock Manager', 'HR Admin')
* Added `hasAnyRole(roleNames)` - Check if user has any of the specified roles
* Added `hasAllRoles(roleNames)` - Check if user has all of the specified roles
* Added `clearCachedRoles()` - Clear cached role data
* Updated storage to cache user roles as JSON array instead of boolean admin flag
* Improved flexibility: Users can now check for any role dynamically
* Enhanced documentation with comprehensive RBAC examples

## 1.1.0

* RBAC: Added `NextRoleService` to detect admin users (cached via storage).
## 1.0.1

* Fix: Remove deprecated author field from pubspec.yaml

## 1.0.0

* Initial release
* Login with username and password
* Logout functionality
* Password reset request
* Password change/update
* Session management with secure storage (SID)
* Automatic re-authentication using stored session
* Get logged user profile
