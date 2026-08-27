import 'dart:convert';

import 'package:flutter_next_auth/flutter_next_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

NextApiClient clientReturning(
  http.Response Function(http.Request request) handler, {
  String baseUrl = 'https://erp.example.com',
  String? apiKey,
  String? apiSecret,
  Duration timeout = const Duration(seconds: 5),
}) {
  return NextApiClient(
    baseUrl: baseUrl,
    apiKey: apiKey,
    apiSecret: apiSecret,
    timeout: timeout,
    client: MockClient((request) async => handler(request)),
  );
}

void main() {
  group('base url', () {
    test('trailing slashes are stripped so endpoints concatenate cleanly', () {
      final client = clientReturning(
        (_) => http.Response('{}', 200),
        baseUrl: 'https://erp.example.com///',
      );
      expect(client.baseUrl, 'https://erp.example.com');
    });
  });

  group('session handling', () {
    test('adopts the sid from a successful response', () async {
      final client = clientReturning(
        (_) => http.Response(
          '{"message":"Logged In"}',
          200,
          headers: {'set-cookie': 'sid=abc123; Path=/; HttpOnly'},
        ),
      );

      await client.post('/api/method/login');
      expect(client.sessionId, 'abc123');
      expect(client.cookieHeader, 'sid=abc123');
    });

    test('ignores the sid=Guest cookie Frappe sends on a rejected login', () async {
      final client = clientReturning(
        (_) => http.Response(
          '{"message":"Invalid login credentials"}',
          401,
          headers: {'set-cookie': 'sid=Guest; Path=/'},
        ),
      );

      final response = await client.post('/api/method/login');
      expect(response.statusCode, 401);
      expect(client.sessionId, isNull,
          reason: 'a failed login must not leave a Guest session behind');
    });

    test('setSessionId treats Guest and empty as no session', () {
      final client = clientReturning((_) => http.Response('{}', 200));

      client.setSessionId('Guest');
      expect(client.sessionId, isNull);

      client.setSessionId('');
      expect(client.sessionId, isNull);

      client.setSessionId('real-sid');
      expect(client.sessionId, 'real-sid');
    });

    test('sends the session as a cookie header', () async {
      String? sentCookie;
      final client = clientReturning((request) {
        sentCookie = request.headers['Cookie'];
        return http.Response('{}', 200);
      });

      client.setSessionId('sid-value');
      await client.get('/api/method/frappe.auth.get_logged_user');
      expect(sentCookie, 'sid=sid-value');
    });

    test('token auth wins over a session cookie', () async {
      Map<String, String> sent = {};
      final client = clientReturning(
        (request) {
          sent = request.headers;
          return http.Response('{}', 200);
        },
        apiKey: 'key',
        apiSecret: 'secret',
      );

      client.setSessionId('sid-value');
      await client.get('/api/method/ping');

      expect(client.usesTokenAuth, isTrue);
      expect(sent['Authorization'], 'token key:secret');
      expect(sent.containsKey('Cookie'), isFalse);
    });
  });

  group('query encoding', () {
    test('percent-encodes a "+" so Werkzeug does not read it as a space', () async {
      late Uri sent;
      final client = clientReturning((request) {
        sent = request.url;
        return http.Response('{"message":[]}', 200);
      });

      await client.get('/api/method/x', query: {'uid': 'someone+erp@gmail.com'});

      expect(sent.queryParameters['uid'], 'someone+erp@gmail.com');
      expect(sent.query, contains('%2B'),
          reason: 'a literal + in the query string decodes to a space');
    });

    test('JSON-encodes non-string query values', () async {
      late Uri sent;
      final client = clientReturning((request) {
        sent = request.url;
        return http.Response('{"message":[]}', 200);
      });

      await client.get('/api/method/frappe.client.get_list', query: {
        'doctype': 'Has Role',
        'filters': [
          ['parent', '=', 'a@b.com'],
        ],
        'fields': ['role'],
      });

      expect(sent.queryParameters['filters'], '[["parent","=","a@b.com"]]');
      expect(sent.queryParameters['fields'], '["role"]');
      expect(sent.path, '/api/method/frappe.client.get_list');
    });
  });

  group('error parsing', () {
    test('prefers the user-facing _server_messages text', () {
      final body = jsonEncode({
        'exc_type': 'ValidationError',
        'exception': 'frappe.exceptions.ValidationError: Row 1: Item is required',
        '_server_messages': jsonEncode([
          jsonEncode({'message': '<b>Row 1:</b> Item is required'}),
        ]),
      });

      final client = clientReturning((_) => http.Response(body, 417));
      final error = client.exceptionFor(http.Response(body, 417));

      expect(error.message, 'Row 1: Item is required');
      expect(error.excType, 'ValidationError');
      expect(error.statusCode, 417);
      expect(client.baseUrl, isNotEmpty);
    });

    test('does not crash when "message" is a map rather than a string', () {
      final body = jsonEncode({
        'message': {'code': 42, 'detail': 'nested'},
      });

      final client = clientReturning((_) => http.Response(body, 400));
      final error = client.exceptionFor(http.Response(body, 400));

      expect(error.message, isNotEmpty);
      expect(error.message, isNot(contains('is not a subtype')));
    });

    test('falls back to the status line for non-JSON bodies', () {
      const body = '<html><body>502 Bad Gateway</body></html>';
      final client = clientReturning((_) => http.Response(body, 502));
      final error = client.exceptionFor(http.Response(body, 502));

      expect(error.message, contains('502'));
      expect(error.excType, isNull);
    });

    test('strips the exception class prefix', () {
      final body = jsonEncode({
        'exception': 'frappe.exceptions.PermissionError: Not permitted',
      });
      final client = clientReturning((_) => http.Response(body, 403));

      expect(client.exceptionFor(http.Response(body, 403)).message,
          'Not permitted');
    });

    test('parseResponse throws on non-2xx and returns the map otherwise', () {
      final client = clientReturning((_) => http.Response('{}', 200));

      expect(
        () => client.parseResponse(http.Response('{"exc_type":"X"}', 500)),
        throwsA(isA<NextApiException>()),
      );
      expect(
        client.parseResponse(http.Response('{"message":"ok"}', 200)),
        {'message': 'ok'},
      );
    });
  });

  group('NextApiException classification', () {
    test('401 and 403 are auth errors', () {
      expect(
        const NextApiException(statusCode: 401, message: 'x').isAuthError,
        isTrue,
      );
      expect(
        const NextApiException(statusCode: 403, message: 'x').isAuthError,
        isTrue,
      );
    });

    test('server and transport failures are not auth errors', () {
      // This is the distinction that stops an offline app from signing the
      // user out permanently.
      for (final code in [
        500,
        502,
        503,
        NextApiException.timeoutStatus,
      ]) {
        final error = NextApiException(statusCode: code, message: 'x');
        expect(error.isAuthError, isFalse, reason: 'status $code');
        expect(error.isTransportError, isTrue, reason: 'status $code');
      }
    });

    test('recognises Frappe auth exception types', () {
      expect(
        const NextApiException(
          statusCode: 417,
          message: 'x',
          excType: 'SessionExpired',
        ).isAuthError,
        isTrue,
      );
      expect(
        const NextApiException(
          statusCode: 417,
          message: 'x',
          excType: 'ValidationError',
        ).isAuthError,
        isFalse,
      );
    });
  });

  group('timeouts', () {
    test('a slow request fails with a timeout exception, not a hang', () async {
      final client = NextApiClient(
        baseUrl: 'https://erp.example.com',
        timeout: const Duration(milliseconds: 50),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.get('/api/method/slow'),
        throwsA(
          isA<NextApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            NextApiException.timeoutStatus,
          ),
        ),
      );
    });
  });
}
