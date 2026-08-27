# flutter_next_auth

Authentication, session management and permission checks for Flutter apps that
talk to a **Frappe / ERPNext** site.

[![pub package](https://img.shields.io/pub/v/flutter_next_auth.svg)](https://pub.dev/packages/flutter_next_auth)

```dart
await FlutterNext.instance.initialize(baseUrl: 'https://erp.example.com');

final result = await flutternext.login(usr: 'jane@example.com', pwd: 'secret');
if (result.success) {
  // Session stored securely. Call relogin() on the next launch.
}
```

## Features

- Login, logout, password reset and password change
- Session (`sid`) stored in the Keychain / Keystore, restored on launch
- **Token authentication** with an API key + secret, for web and background work
- **Two factor authentication** for sites that require an OTP
- **Permission checks** (`canRead`, `canWrite`, `canSubmit`, ...) that work on
  every Frappe version
- Role checks with a configurable source, for sites that still use them
- Typed errors carrying Frappe's own `exc_type` and user-facing message
- Escape hatch (`flutternext.api`) for any endpoint this package does not wrap

## Install

```yaml
dependencies:
  flutter_next_auth: ^1.3.0
```

Requires Dart 3.8 / Flutter 3.32 or newer.

## Platform setup

| Platform | Notes |
| --- | --- |
| Android | Nothing required. Set `minSdkVersion 23` if you are below it. |
| iOS / macOS | Nothing required. Enable the Keychain Sharing capability if you share a session between app extensions. |
| Linux | `sudo apt-get install libsecret-1-dev libjsoncpp-dev` |
| Windows | Nothing required. |
| Web | **Use token authentication.** Browsers do not expose `Set-Cookie` to JavaScript, so session login cannot read the `sid` it needs. See below. |

## Authentication

### Session login

```dart
await FlutterNext.instance.initialize(
  baseUrl: 'https://erp.example.com',
  timeout: const Duration(seconds: 30),
);

final result = await flutternext.login(usr: 'jane@example.com', pwd: 'secret');

if (result.success) {
  print('Signed in as ${result.fullName ?? result.username}');
} else if (result.requiresTwoFactor) {
  // See below.
} else {
  print(result.message);
}
```

### Two factor authentication

When the site has 2FA enabled, `login()` returns a result that is neither a
success nor an ordinary failure. Check `requiresTwoFactor` **before** treating it
as an error:

```dart
final result = await flutternext.login(usr: usr, pwd: pwd);

if (result.requiresTwoFactor) {
  final otp = await promptUserForCode(result.verification?['prompt']);

  final confirmed = await flutternext.confirmTwoFactor(
    usr: usr,
    tmpId: result.tmpId!,
    otp: otp,
  );
}
```

### Token authentication

Create an API key and secret on the User document in the desk
(*User → Settings → API Access → Generate Keys*), then:

```dart
await FlutterNext.instance.initialize(
  baseUrl: 'https://erp.example.com',
  apiKey: 'your_api_key',
  apiSecret: 'your_api_secret',
);
```

No `login()` call is needed. Token auth does not expire, is unaffected by session
timeouts, and is the only scheme that works on Flutter web.

> Do not ship a key and secret inside a distributed app — anyone can extract
> them. Token auth is for trusted deployments, internal builds and server-side
> work.

### Restoring a session on launch

```dart
final result = await flutternext.relogin();

if (result.success) {
  goToHome(result.user!);
} else if (result.sessionCleared) {
  goToLogin();          // the server rejected the session
} else {
  showRetry(result.message);  // we could not reach the server; session kept
}
```

`sessionCleared` matters: before 1.3.0 any failure — including being offline —
wiped the session and signed the user out for good.

### Changing a password

```dart
final result = await flutternext.changePassword(
  oldPassword: 'old',
  newPassword: 'new',
  logoutOtherSessions: true,
);
```

Frappe issues a **new** session id during this call. It is stored automatically.
If you share the session with other clients, refresh them with `result.sid`.

## Permissions (recommended)

Ask what the user may *do*, not what roles they hold. These map onto
`frappe.client.has_permission` and `frappe.client.get_doc_permissions`, are what
the desk itself uses, and are stable across Frappe v13 to v16.

```dart
if (await flutternext.role.canCreate('Sales Invoice')) {
  showNewInvoiceButton();
}

if (await flutternext.role.canSubmit('Stock Entry', docname: 'STE-0001')) {
  showSubmitButton();
}
```

One request for several decisions on the same document:

```dart
final perms = await flutternext.role.getDocPermissions('Sales Order', 'SO-0007');

if (perms.write)  showEditButton();
if (perms.submit) showSubmitButton();
if (perms.cancel) showCancelButton();
```

Document-level checks respect User Permissions and owner-only rules, which role
checks cannot see.

## Roles

> **Frappe v16 removed the built-in roles endpoint.**
> `frappe.core.doctype.user.user.get_roles` exists in v13–v15 only. If your app
> depends on role names, configure `rolesMethod` — otherwise role lookups may
> return an empty list.

```dart
bool isStockManager = await flutternext.role.hasRole('Stock Manager');

bool canSeeStock = await flutternext.role.hasAnyRole([
  'Stock Manager',
  'Stock User',
  'System Manager',
]);

bool hasBoth = await flutternext.role.hasAllRoles(['Accounts Manager', 'Auditor']);

final roles = await flutternext.role.getUserRoles();   // fetch and cache
final cached = await flutternext.role.getCachedRoles(); // no network
await flutternext.role.clearCachedRoles();
```

Roles are cached in secure storage after the first successful fetch. Pass
`refresh: true` to force a round trip.

### Making role lookup deterministic

Add three lines to any custom app on your site:

```python
# your_app/api.py
import frappe

@frappe.whitelist()
def my_roles():
    return frappe.get_roles()
```

```dart
await FlutterNext.instance.initialize(
  baseUrl: 'https://erp.example.com',
  rolesMethod: 'your_app.api.my_roles',
);
```

This works on every Frappe version and needs no special permissions.

## Sharing the session with other clients

```dart
final cookie = await flutternext.cookieHeader();   // "sid=..."
```

Pass it to `flutter_next_base`, a `socket_io_client` connection, or a WebView so
the whole app runs on one session:

```dart
// flutter_next_base
class NextAuthCookieManager implements CookieManager {
  @override
  Future<String> getCookies(String url) async =>
      await flutternext.cookieHeader() ?? '';

  @override
  Future<void> saveCookies(String url, List<String> cookies) async {}
}

final client = FlutterNextBaseClient(
  baseUrl: 'https://erp.example.com',
  cookieManager: NextAuthCookieManager(),
);
```

## Calling any other endpoint

```dart
final response = await flutternext.api.get(
  '/api/method/frappe.client.get_count',
  query: {'doctype': 'Task', 'filters': [['status', '=', 'Open']]},
);
final count = flutternext.api.parseResponse(response)['message'];
```

Query values are encoded properly — lists and maps are JSON-encoded, and `+`
signs survive.

## Error handling

```dart
try {
  final response = await flutternext.api.post('/api/method/your_app.api.thing');
  flutternext.api.parseResponse(response);
} on NextApiException catch (e) {
  if (e.isAuthError)      goToLogin();
  else if (e.isTransportError) showRetry();
  else if (e.excType == 'ValidationError') showMessage(e.message);
}
```

`e.message` is the text `frappe.throw()` showed the user, pulled out of
`_server_messages` and stripped of markup.

## API reference

### `FlutterNext`

| Member | Description |
| --- | --- |
| `initialize({baseUrl, timeout, apiKey, apiSecret, rolesMethod, force})` | Configure against a site |
| `login({usr, pwd})` | Sign in |
| `confirmTwoFactor({usr, tmpId, otp})` | Complete a 2FA login |
| `logout()` | Sign out and clear stored data |
| `relogin()` | Restore and verify a stored session |
| `resetPassword({user})` | Email reset instructions |
| `changePassword({oldPassword, newPassword, logoutOtherSessions})` | Change password |
| `getUserProfile()` | Current user, or null |
| `hasStoredSession()` | Local check, no network |
| `validateSession()` | Live check against the server |
| `cookieHeader()` | `"sid=..."` for other clients |
| `getServerVersions()` | Frappe and app versions |
| `api` | `NextApiClient` for arbitrary calls |
| `role` | `NextRoleService` |
| `auth` | `NextAuthService` |
| `dispose()` | Release the HTTP client |

### `NextRoleService`

`canRead` · `canWrite` · `canCreate` · `canDelete` · `canSubmit` · `canCancel` ·
`hasPermission` · `getDocPermissions` · `hasRole` · `hasAnyRole` ·
`hasAllRoles` · `getUserRoles` · `getCachedRoles` · `clearCachedRoles`

## Frappe compatibility

| | v13 | v14 | v15 | v16 |
| --- | --- | --- | --- | --- |
| Login, logout, session | ✅ | ✅ | ✅ | ✅ |
| Password reset / change | ✅ | ✅ | ✅ | ✅ |
| Two factor | ✅ | ✅ | ✅ | ✅ |
| Permission checks | ✅ | ✅ | ✅ | ✅ |
| Roles via built-in endpoint | ✅ | ✅ | ✅ | ❌ removed |
| Roles via `rolesMethod` | ✅ | ✅ | ✅ | ✅ |

### A note on CSRF

Sessions created through `/api/method/login` carry no CSRF token — Frappe
generates one lazily when a desk or website page is rendered — so writes from
this package work without one. If you reuse a `sid` that originated in a browser,
set the token with `flutternext.api.setCsrfToken(...)`.

## Migrating from 1.2.x

Nothing breaks. Two things are worth doing:

1. Replace `hasActiveSession()` with `hasStoredSession()` (or `validateSession()`
   if you wanted a live check — the old method never made one).
2. If you rely on `hasRole`, either set `rolesMethod` or switch to the permission
   checks, before your site reaches Frappe v16.

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for the 1.1 → 1.2 role changes.

## License

MIT — see [LICENSE](LICENSE).
