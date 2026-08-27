## 1.3.0

Reliability and Frappe-version compatibility release. No public API was removed;
two methods are deprecated with replacements.

### Fixed

* **Being offline no longer signs the user out.** `relogin()` cleared the stored
  session on *any* exception, so a timeout, a 5xx or an unreachable server
  destroyed the session permanently. It now clears only when the server actually
  rejects the session (401/403, or a Frappe `AuthenticationError` /
  `SessionExpired`). `ReloginResult.sessionCleared` tells the two cases apart.
* **`changePassword()` no longer strands the app on a dead session.** Frappe
  re-authenticates inside `update_password`, which issues a new session id. That
  id is now persisted; previously the app worked until its next launch and then
  failed to restore the session.
* **A rejected login no longer leaves a `Guest` session behind.** Frappe answers
  a wrong password with `Set-Cookie: sid=Guest`; that was being adopted and sent
  on every later request. Session ids are now only read from successful
  responses, and `Guest` is rejected outright.
* **User ids containing `+` work again.** The roles lookup interpolated the user
  id straight into a URL, and a literal `+` in a query string decodes to a space
  server-side, so `someone+erp@gmail.com` was sent as `someone erp@gmail.com`.
  All query parameters are now properly encoded.
* **Frappe error messages survive.** `_server_messages` — the text
  `frappe.throw()` actually shows the user — is now extracted and HTML-stripped,
  falling back through `message`, `exception` and `exc_type`. Non-JSON bodies
  (nginx error pages, proxy timeouts) no longer produce a cast error.
* **Requests can no longer hang forever.** The configured timeout is now applied
  to every request and surfaces as a `NextApiException` with
  `statusCode == NextApiException.timeoutStatus`.
* `UserProfile.fullName` and `.email` are no longer permanently null.
  `frappe.auth.get_logged_user` returns nothing but the user id, so the profile
  is now enriched from the User document where permissions allow, and falls back
  to the full name captured at login.

### Added

* **Permission checks** — `role.canRead`, `canWrite`, `canCreate`, `canDelete`,
  `canSubmit`, `canCancel`, `hasPermission()` and `getDocPermissions()`, backed
  by `frappe.client.has_permission` and `frappe.client.get_doc_permissions`.
  These are what the desk itself uses, they work on every Frappe version, and
  they are the recommended replacement for role checks.
* **Two factor authentication.** `LoginResult.requiresTwoFactor` plus
  `confirmTwoFactor()`. Sites with 2FA enabled previously could not sign in at
  all.
* **Token authentication.** Pass `apiKey` and `apiSecret` to `initialize()` to
  authenticate with an API key pair instead of a session. Token auth does not
  expire and is the only scheme that works on Flutter web, where browsers hide
  `Set-Cookie` from the app.
* `flutternext.api` exposes `NextApiClient` for authenticated calls this package
  does not wrap. `NextApiClient` and `NextApiException` are now exported, so
  errors can be caught by type.
* `cookieHeader()` returns the session as a `Cookie` header, for sharing one
  session with `flutter_next_base`, a WebSocket, or a WebView.
* `getServerVersions()` reads `frappe.utils.change_log.get_versions`, for
  branching on server capabilities.
* `hasStoredSession()` (local check) and `validateSession()` (live check).
* `initialize(force: true)` to reconfigure against a different site, and
  `dispose()` to release the HTTP client.
* `NextApiException.excType`, `.isAuthError`, `.isTransportError` and `.data`.
* A test suite covering session handling, query encoding, error parsing, error
  classification and timeouts.

### Changed

* **Role lookup is now version-aware.** Frappe **removed**
  `frappe.core.doctype.user.user.get_roles` in v16 — it exists in v13, v14 and
  v15 only. `getUserRoles()` now tries, in order: a custom method you name via
  the new `rolesMethod` option, the built-in endpoint, then
  `frappe.client.get_list` over `Has Role`.

  The previous fallback queried `/api/resource/Has Role` without a `parent`,
  which Frappe rejects with `PermissionError` on **every** version — it never
  worked. It now sends `parent=User` as Frappe requires. Note that even then it
  needs read permission on the User DocType, which by default only System
  Manager holds. **If you depend on role checks, set `rolesMethod`**, or move to
  the permission checks above.
* The session id is cached in memory instead of being read from secure storage
  on every request. That removes a Keychain/Keystore round trip per call and the
  race that overlapping requests could hit.
* Diagnostics go through `dart:developer` instead of `print()`, and the
  `avoid_print: false` lint override has been removed.
* Base URLs are normalised, so a trailing slash no longer produces `//api/...`.
* Minimum SDK is now Dart 3.8 / Flutter 3.32.

### Deprecated

* `hasActiveSession()` → `hasStoredSession()`. The old name implied a live check
  it never performed. Both remain; the old one will be removed in 2.0.0.

### Known dependency note

`flutter_secure_storage` is pinned to `^9.2.4`. Version 10+ pulls `win32 ^6`,
which requires Dart 3.10; bump to `^11.0.0` once you are on Flutter 3.35 or
newer.

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
