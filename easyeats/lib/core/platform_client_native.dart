import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

http.Client createClient() => http.Client();
final _storage = FlutterSecureStorage();
Future<String?> readSetting(String key) => _storage.read(key: key);
Future<void> writeSetting(String key, String? value) => value == null
    ? _storage.delete(key: key)
    : _storage.write(key: key, value: value);
String? webHost() => null;
