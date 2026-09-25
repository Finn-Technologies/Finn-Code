import 'dart:async';
import 'dart:convert';

Stream<Map<String, dynamic>> decodeSseData(Stream<List<int>> body) async* {
  await for (final line
      in body.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty || line.startsWith(':')) continue;
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trimLeft();
    if (payload.isEmpty) continue;
    if (payload == '[DONE]') return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) yield decoded;
    } on FormatException {
      // Ignore keep-alive or provider-specific non-JSON SSE frames.
    }
  }
}

Never throwHttpError(String provider, int statusCode, String body) {
  var detail = body.trim();
  if (detail.length > 320) detail = '${detail.substring(0, 320)}…';
  throw AgentGatewayException(
    '$provider request failed ($statusCode)${detail.isEmpty ? '' : ': $detail'}',
    statusCode: statusCode,
  );
}

class AgentGatewayException implements Exception {
  const AgentGatewayException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

Uri apiUri(String baseUrl, String path, {Map<String, String>? query}) {
  final base = Uri.parse(
    baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
  );
  final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
  if (base.path.endsWith('/$normalizedPath')) {
    return base.replace(queryParameters: query);
  }
  final joinedPath =
      '${base.path.replaceAll(RegExp(r'/$'), '')}/$normalizedPath';
  return base.replace(path: joinedPath, queryParameters: query);
}
