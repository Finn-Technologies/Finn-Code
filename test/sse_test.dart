import 'dart:convert';

import 'package:finn_code/data/services/sse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodeSseData ignores comments and yields JSON objects', () async {
    final body = Stream<List<int>>.fromIterable(<List<int>>[
      utf8.encode(': keep-alive\n\n'),
      utf8.encode('data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n'),
      utf8.encode('data: [DONE]\n\n'),
      utf8.encode('data: {"choices":[],"cost":"0"}\n\n'),
    ]);

    final events = await decodeSseData(body).toList();

    expect(events, hasLength(1));
    expect(events.single['choices'], isA<List<dynamic>>());
  });

  test('apiUri joins base paths without duplicating an endpoint', () {
    expect(
      apiUri('https://example.com/v1/', 'chat/completions').toString(),
      'https://example.com/v1/chat/completions',
    );
    expect(
      apiUri(
        'https://example.com/v1/chat/completions',
        'chat/completions',
      ).toString(),
      'https://example.com/v1/chat/completions',
    );
  });
}
