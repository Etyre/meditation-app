import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meditation_timer/infra/sheets/webhook_sheets_logger.dart';

const exec = 'https://script.google.com/macros/s/abc/exec';
const echo = 'https://script.googleusercontent.com/macros/echo?key=1';

void main() {
  test('attaches the secret to the posted body', () async {
    Map<String, dynamic>? sent;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response('{"ok":true}', 200);
    });
    final logger = WebhookSheetsLogger(
        getUrl: () => exec, getSecret: () => ' s3cret ', client: client);
    expect(await logger.postPayload({'a': 1}), isTrue);
    expect(sent, {'a': 1, 'secret': 's3cret'});
  });

  test('omits the secret key when none is set', () async {
    Map<String, dynamic>? sent;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response('{"ok":true}', 200);
    });
    final logger = WebhookSheetsLogger(getUrl: () => exec, client: client);
    expect(await logger.postPayload({'a': 1}), isTrue);
    expect(sent!.containsKey('secret'), isFalse);
  });

  test('follows the Apps Script redirect and honours a rejection', () async {
    final methods = <String>[];
    final client = MockClient((req) async {
      methods.add('${req.method} ${req.url}');
      if (req.method == 'POST') {
        return http.Response('', 302, headers: {'location': echo});
      }
      return http.Response('{"ok":false,"error":"bad secret"}', 200);
    });
    final logger = WebhookSheetsLogger(
        getUrl: () => exec, getSecret: () => 'wrong', client: client);
    expect(await logger.postPayload({'a': 1}), isFalse);
    expect(methods, ['POST $exec', 'GET $echo']);
  });

  test('redirect to an accepting reply counts as delivered', () async {
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        return http.Response('', 302, headers: {'location': echo});
      }
      return http.Response('{"ok":true}', 200);
    });
    final logger = WebhookSheetsLogger(getUrl: () => exec, client: client);
    expect(await logger.postPayload({'a': 1}), isTrue);
  });

  test('a failed confirmation fetch still counts as delivered', () async {
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        return http.Response('', 302, headers: {'location': echo});
      }
      throw http.ClientException('offline');
    });
    final logger = WebhookSheetsLogger(getUrl: () => exec, client: client);
    expect(await logger.postPayload({'a': 1}), isTrue);
  });

  test('unparseable body is treated as delivered; 4xx/5xx are not', () async {
    var status = 200;
    final client = MockClient(
        (req) async => http.Response('<html>thanks</html>', status));
    final logger = WebhookSheetsLogger(getUrl: () => exec, client: client);
    expect(await logger.postPayload({'a': 1}), isTrue);
    status = 500;
    expect(await logger.postPayload({'a': 1}), isFalse);
  });

  test('no URL means not delivered', () async {
    final logger = WebhookSheetsLogger(getUrl: () => '  ');
    expect(await logger.postPayload({'a': 1}), isFalse);
  });
}
