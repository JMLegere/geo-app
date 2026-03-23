import 'dart:convert';

import 'package:http/http.dart';

import 'package:earth_nova/core/services/observability_buffer.dart';

/// HTTP client decorator that emits [api_request] and [api_response]
/// observability events for every Supabase network call.
///
/// Injected into [Supabase.initialize(httpClient:)] so all REST,
/// Edge Function, and Auth calls are automatically instrumented
/// without per-site boilerplate.
///
/// Also detects non-JSON responses (from ad blockers, privacy extensions,
/// VPNs, or CDN error pages) and logs the raw body loudly before the
/// Supabase client tries to parse it and throws a cryptic FormatException.
class ObservableHttpClient extends BaseClient {
  ObservableHttpClient([Client? inner]) : _inner = inner ?? Client();

  final Client _inner;

  /// Paths that should NOT be logged to avoid circular logging
  /// (the observability buffer itself writes to app_events).
  static const _skipPaths = {'/rest/v1/app_logs'};

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final path = request.url.path;
    if (_skipPaths.any(path.endsWith)) {
      return _inner.send(request);
    }

    final operation = _parseOperation(request);
    final target = _parseTarget(request);

    ObservabilityBuffer.instance?.event('api_request', {
      'method': request.method,
      'operation': operation,
      'target': target,
    });

    // ignore: avoid_print
    print('[API] → ${request.method} $operation $target');

    final sw = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      sw.stop();

      final status = response.statusCode < 400 ? 'ok' : 'error';
      ObservabilityBuffer.instance?.event('api_response', {
        'method': request.method,
        'operation': operation,
        'target': target,
        'status_code': response.statusCode,
        'duration_ms': sw.elapsedMilliseconds,
        'status': status,
      });

      // ignore: avoid_print
      print(
        '[API] ← ${response.statusCode} $operation $target '
        '${sw.elapsedMilliseconds}ms',
      );

      // ── Non-JSON response detection ─────────────────────────────────
      // Ad blockers, privacy extensions, and VPN browser extensions can
      // intercept requests to *.supabase.co and return HTML error pages,
      // plain text, or blocked-content responses instead of JSON. The
      // Supabase client will then throw a cryptic FormatException like
      // "Unexpected identifier 'version'" when it tries to JSON-parse.
      //
      // We intercept here: read the body, check if it's valid JSON,
      // and if not, log the raw body loudly so we can diagnose.
      final contentType = response.headers['content-type'] ?? '';
      final expectsJson = path.contains('/rest/') ||
          path.contains('/rpc/') ||
          path.contains('/functions/') ||
          path.contains('/auth/');

      // 204 No Content and 201 Created with empty body are valid — don't flag.
      final hasBody = response.statusCode != 204 && response.contentLength != 0;

      if (expectsJson && hasBody && !contentType.contains('json')) {
        // Read the body to log it, then re-wrap into a new StreamedResponse
        // so downstream consumers can still read it (streams are single-use).
        final bodyBytes = await response.stream.toBytes();
        final bodyPreview =
            utf8.decode(bodyBytes, allowMalformed: true).substring(
                  0,
                  bodyBytes.length > 500 ? 500 : bodyBytes.length,
                );

        // ignore: avoid_print
        print(
          '[API] ⚠️ NON-JSON RESPONSE for $operation $target '
          '(content-type: $contentType). '
          'Body preview: $bodyPreview',
        );
        ObservabilityBuffer.instance?.event('api_non_json_response', {
          'method': request.method,
          'operation': operation,
          'target': target,
          'status_code': response.statusCode,
          'content_type': contentType,
          'body_preview': bodyPreview,
          'duration_ms': sw.elapsedMilliseconds,
        });

        // Re-wrap body so downstream still gets the bytes (and the error).
        return StreamedResponse(
          ByteStream.fromBytes(bodyBytes),
          response.statusCode,
          contentLength: bodyBytes.length,
          headers: response.headers,
          reasonPhrase: response.reasonPhrase,
          request: response.request,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
        );
      }

      return response;
    } catch (e) {
      sw.stop();

      ObservabilityBuffer.instance?.event('api_response', {
        'method': request.method,
        'operation': operation,
        'target': target,
        'duration_ms': sw.elapsedMilliseconds,
        'status': 'error',
        'error': '$e',
      });

      // ignore: avoid_print
      print(
        '[API] ← ERR $operation $target '
        '${sw.elapsedMilliseconds}ms $e',
      );

      rethrow;
    }
  }

  /// Derive a human-readable operation from method + path.
  ///
  /// REST:   POST /rest/v1/profiles      → "upsert"
  /// RPC:    POST /rest/v1/rpc/func_name → "rpc:func_name"
  /// Edge:   POST /functions/v1/fn_name  → "edge:fn_name"
  /// Auth:   POST /auth/v1/token         → "auth:token"
  String _parseOperation(BaseRequest request) {
    final path = request.url.path;

    if (path.contains('/functions/v1/')) {
      final fn = path.split('/functions/v1/').last.split('?').first;
      return 'edge:$fn';
    }

    if (path.contains('/rpc/')) {
      final fn = path.split('/rpc/').last.split('?').first;
      return 'rpc:$fn';
    }

    if (path.contains('/auth/v1/')) {
      final segment = path.split('/auth/v1/').last.split('?').first;
      return 'auth:$segment';
    }

    // REST: map HTTP method to semantic operation
    return switch (request.method) {
      'GET' => 'select',
      'POST' => 'upsert',
      'PATCH' => 'update',
      'PUT' => 'upsert',
      'DELETE' => 'delete',
      _ => request.method.toLowerCase(),
    };
  }

  /// Extract the target resource (table name, function name, auth endpoint).
  String _parseTarget(BaseRequest request) {
    final path = request.url.path;

    if (path.contains('/functions/v1/')) {
      return path.split('/functions/v1/').last.split('?').first;
    }

    if (path.contains('/rpc/')) {
      return path.split('/rpc/').last.split('?').first;
    }

    if (path.contains('/auth/v1/')) {
      return 'auth';
    }

    if (path.contains('/rest/v1/')) {
      return path.split('/rest/v1/').last.split('?').first;
    }

    // Storage or unknown
    return path.split('/').last.split('?').first;
  }
}
