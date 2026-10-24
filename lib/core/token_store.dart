import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _s = FlutterSecureStorage();
  static const _a = 'access';
  static const _r = 'refresh';

  Future<String?> get access => _s.read(key: _a);
  Future<String?> get refresh => _s.read(key: _r);

  Future<void> save({required String access, String? refresh}) async {
    await _s.write(key: _a, value: access);
    if (refresh != null) await _s.write(key: _r, value: refresh);
  }

  Future<void> clear() async {
    await _s.delete(key: _a);
    await _s.delete(key: _r);
  }
}
