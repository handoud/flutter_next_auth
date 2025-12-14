import 'dart:convert';
import 'package:http/http.dart' as http;

/// HTTP client for NextERP API requests
class NextApiClient {
  final String baseUrl;
  final Duration timeout;
  String? _sessionId;

  NextApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
  });

  /// Set the session ID for authenticated requests
  void setSessionId(String? sid) {
    _sessionId = sid;
  }

  /// Get current session ID
  String? get sessionId => _sessionId;

  /// Make a POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add session cookie if available
    if (_sessionId != null) {
      defaultHeaders['Cookie'] = 'sid=$_sessionId';
    }

    // Merge custom headers
    final mergedHeaders = {...defaultHeaders, ...?headers};

    try {
      final response = await http
          .post(
            url,
            headers: mergedHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      // Extract and store session ID from response cookies
      _extractSessionId(response);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Make a GET request
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final defaultHeaders = {
      'Accept': 'application/json',
    };

    // Add session cookie if available
    if (_sessionId != null) {
      defaultHeaders['Cookie'] = 'sid=$_sessionId';
    }

    // Merge custom headers
    final mergedHeaders = {...defaultHeaders, ...?headers};

    try {
      final response = await http
          .get(
            url,
            headers: mergedHeaders,
          )
          .timeout(timeout);

      // Extract and store session ID from response cookies
      _extractSessionId(response);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Extract session ID from response cookies
  void _extractSessionId(http.Response response) {
    final cookies = response.headers['set-cookie'];
    if (cookies != null) {
      final sidMatch = RegExp(r'sid=([^;]+)').firstMatch(cookies);
      if (sidMatch != null) {
        _sessionId = sidMatch.group(1);
      }
    }
  }

  /// Parse JSON response
  Map<String, dynamic> parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw NextApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    }
  }

  /// Extract error message from response
  String _extractErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('exc')) {
        return data['exc'].toString();
      } else if (data.containsKey('message')) {
        return data['message'].toString();
      } else if (data.containsKey('_server_messages')) {
        final messages = jsonDecode(data['_server_messages']);
        if (messages is List && messages.isNotEmpty) {
          final firstMessage = jsonDecode(messages[0]);
          return firstMessage['message'] ?? 'Unknown error';
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Unknown error"}';
  }
}

/// Exception thrown when API request fails
class NextApiException implements Exception {
  final int statusCode;
  final String message;

  NextApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'NextApiException: $message (Status: $statusCode)';
}
