import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client for Frappe/ERPNext API requests.
///
/// Handles the two authentication schemes Frappe supports:
///
/// * **Session (sid)** — obtained by calling `/api/method/login`. Sent as a
///   `Cookie: sid=...` header.
/// * **Token** — an API key and secret pair created on a User document. Sent as
///   an `Authorization: token key:secret` header. Token auth never expires and
///   is not affected by session timeouts.
///
/// When both are configured the token wins, matching Frappe's own precedence.
class NextApiClient {
  /// The site root, e.g. `https://erp.example.com`. Any trailing slash is
  /// removed so endpoints can be concatenated safely.
  final String baseUrl;

  /// Applied to every request. Requests that exceed it complete with a
  /// [NextApiException] carrying [NextApiException.timeoutStatus].
  final Duration timeout;

  /// API key for token authentication.
  final String? apiKey;

  /// API secret for token authentication.
  final String? apiSecret;

  final http.Client _client;
  final bool _ownsClient;

  String? _sessionId;
  String? _csrfToken;

  NextApiClient({
    required String baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.apiKey,
    this.apiSecret,
    http.Client? client,
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Whether API key/secret authentication is configured.
  bool get usesTokenAuth =>
      (apiKey?.isNotEmpty ?? false) && (apiSecret?.isNotEmpty ?? false);

  /// Sets the session id used for authenticated requests.
  ///
  /// `Guest` and empty values are treated as "no session", so a rejected login
  /// (which Frappe answers with `Set-Cookie: sid=Guest`) cannot leave a bogus
  /// session behind.
  void setSessionId(String? sid) {
    if (sid == null || sid.isEmpty || sid == 'Guest') {
      _sessionId = null;
    } else {
      _sessionId = sid;
    }
  }

  /// The session id currently in use, if any.
  String? get sessionId => _sessionId;

  /// Sets the CSRF token for session-authenticated writes.
  ///
  /// Sessions created through `/api/method/login` have no CSRF token — Frappe
  /// generates one lazily when a desk or website page is rendered — so this is
  /// only needed when reusing a session id that originated in a browser.
  void setCsrfToken(String? token) => _csrfToken = token;

  /// The CSRF token currently in use, if any.
  String? get csrfToken => _csrfToken;

  /// The `Cookie` header value for the current session, or null.
  ///
  /// Useful for handing the session to another client, such as
  /// `flutter_next_base` or a WebSocket connection.
  String? get cookieHeader => _sessionId == null ? null : 'sid=$_sessionId';

  Uri _uri(String endpoint, Map<String, dynamic>? query) {
    final uri = Uri.parse('$baseUrl$endpoint');
    if (query == null || query.isEmpty) return uri;

    // Encode through queryParameters so values containing '+', '&', spaces or
    // JSON punctuation survive the round trip. Raw interpolation does not:
    // Werkzeug decodes a literal '+' as a space, which silently corrupts user
    // ids such as "someone+erp@gmail.com".
    final params = <String, String>{
      ...uri.queryParameters,
      for (final entry in query.entries)
        if (entry.value != null)
          entry.key: entry.value is String
              ? entry.value as String
              : jsonEncode(entry.value),
    };
    return uri.replace(queryParameters: params);
  }

  Map<String, String> _buildHeaders({
    required bool sendsBody,
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{'Accept': 'application/json'};

    if (sendsBody) headers['Content-Type'] = 'application/json';

    if (usesTokenAuth) {
      headers['Authorization'] = 'token $apiKey:$apiSecret';
    } else if (_sessionId != null) {
      headers['Cookie'] = 'sid=$_sessionId';
    }

    if (_csrfToken != null) headers['X-Frappe-CSRF-Token'] = _csrfToken!;

    if (extra != null) headers.addAll(extra);
    return headers;
  }

  /// Makes a POST request against [endpoint], e.g. `/api/method/login`.
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) {
    return _send(
      () => _client.post(
        _uri(endpoint, query),
        headers: _buildHeaders(sendsBody: true, extra: headers),
        body: body != null ? jsonEncode(body) : null,
      ),
      endpoint,
    );
  }

  /// Makes a GET request against [endpoint].
  Future<http.Response> get(
    String endpoint, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) {
    return _send(
      () => _client.get(
        _uri(endpoint, query),
        headers: _buildHeaders(sendsBody: false, extra: headers),
      ),
      endpoint,
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request,
    String endpoint,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw NextApiException(
        statusCode: NextApiException.timeoutStatus,
        message: 'Request to $endpoint timed out after '
            '${timeout.inSeconds}s',
      );
    }

    _extractSessionId(response);
    return response;
  }

  /// Picks the session id out of a successful response's cookies.
  ///
  /// Only 2xx responses are considered: Frappe answers a rejected login with
  /// `sid=Guest`, and adopting that would send a meaningless session on every
  /// later request.
  ///
  /// On Flutter web this is always a no-op, because browsers do not expose
  /// `Set-Cookie` to JavaScript. Use token authentication there.
  void _extractSessionId(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) return;

    final cookies = response.headers['set-cookie'];
    if (cookies == null) return;

    final match = RegExp(r'sid=([^;,\s]+)').firstMatch(cookies);
    if (match == null) return;

    final sid = match.group(1);
    if (sid == null || sid.isEmpty || sid == 'Guest') return;
    _sessionId = sid;
  }

  /// Decodes a Frappe JSON response, throwing [NextApiException] on failure.
  Map<String, dynamic> parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return const <String, dynamic>{};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'message': decoded};
    }
    throw exceptionFor(response);
  }

  /// Decodes a raw response body into a map, or null when it is not a JSON
  /// object. Used to inspect payloads that accompany non-2xx statuses, such as
  /// Frappe's two factor `verification` block.
  Map<String, dynamic>? decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Builds a [NextApiException] from an error response, extracting the
  /// user-facing message Frappe buries in `_server_messages`.
  NextApiException exceptionFor(http.Response response) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Not JSON: an nginx error page or a proxy timeout. Fall through to the
      // status-based message below.
    }

    return NextApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(response, data),
      excType: data?['exc_type']?.toString(),
      data: data,
    );
  }

  String _extractErrorMessage(http.Response response, Map<String, dynamic>? data) {
    if (data != null) {
      // `_server_messages` carries what frappe.throw() showed the user. It is a
      // JSON string holding a list of JSON strings.
      final serverMessage = _firstServerMessage(data['_server_messages']);
      if (serverMessage != null) return serverMessage;

      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;

      final exception = data['exception'];
      if (exception is String && exception.isNotEmpty) {
        // "frappe.exceptions.ValidationError: Item is required" -> the tail.
        final colon = exception.indexOf(': ');
        return colon == -1 ? exception : exception.substring(colon + 2);
      }

      final excType = data['exc_type'];
      if (excType is String && excType.isNotEmpty) return excType;
    }

    return 'HTTP ${response.statusCode}: '
        '${response.reasonPhrase ?? 'Request failed'}';
  }

  static String? _firstServerMessage(dynamic raw) {
    if (raw == null) return null;
    try {
      final messages = raw is String ? jsonDecode(raw) : raw;
      if (messages is! List || messages.isEmpty) return null;

      final first = messages.first;
      final decoded = first is String ? jsonDecode(first) : first;
      if (decoded is Map && decoded['message'] != null) {
        return _stripHtml(decoded['message'].toString());
      }
      return _stripHtml(decoded.toString());
    } catch (_) {
      return null;
    }
  }

  /// Frappe messages routinely contain markup such as `<b>` or `<br>`.
  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  /// Closes the underlying HTTP client, when this instance owns it.
  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Thrown when a Frappe API request fails.
class NextApiException implements Exception {
  /// Synthetic status used when a request exceeds its timeout.
  static const int timeoutStatus = -1;

  /// The HTTP status code, or [timeoutStatus].
  final int statusCode;

  /// The user-facing message, extracted from `_server_messages` where present.
  final String message;

  /// Frappe's exception class name, e.g. `ValidationError`, `PermissionError`,
  /// `AuthenticationError`. Null when the body was not a Frappe error payload.
  final String? excType;

  /// The decoded error body, when it was JSON.
  final Map<String, dynamic>? data;

  const NextApiException({
    required this.statusCode,
    required this.message,
    this.excType,
    this.data,
  });

  /// True when the server rejected the caller's identity, meaning any stored
  /// session is genuinely dead.
  ///
  /// Deliberately narrow: a timeout, a 500 from a broken server hook or a 502
  /// from a proxy are **not** auth errors, and must not cause a sign-out.
  bool get isAuthError {
    if (statusCode == 401 || statusCode == 403) return true;
    return const {
      'AuthenticationError',
      'SessionExpired',
      'InvalidAuthorizationToken',
      'InvalidAuthorizationHeader',
    }.contains(excType);
  }

  /// True when the request never reached the server, or the server could not
  /// answer. The caller should retry rather than sign the user out.
  bool get isTransportError =>
      statusCode == timeoutStatus || statusCode == 0 || statusCode >= 500;

  @override
  String toString() {
    final where = statusCode == timeoutStatus ? 'timeout' : 'status $statusCode';
    final type = excType == null ? '' : ' [$excType]';
    return 'NextApiException$type: $message ($where)';
  }
}
