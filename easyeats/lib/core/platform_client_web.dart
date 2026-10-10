import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

http.Client createClient() => BrowserClient()..withCredentials = true;
Future<String?> readSetting(String key) async =>
    ['server', 'session_closed'].contains(key)
    ? web.window.localStorage.getItem(key)
    : null;
Future<void> writeSetting(String key, String? value) async {
  if (!['server', 'session_closed'].contains(key)) return;
  if (value == null) {
    web.window.localStorage.removeItem(key);
  } else {
    web.window.localStorage.setItem(key, value);
  }
}

String? webHost() => web.window.location.hostname;
