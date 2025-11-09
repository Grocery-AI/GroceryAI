import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 跨平台存儲服務 - 使用 FlutterSecureStorage
abstract class StorageService {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class NativeStorageService implements StorageService {
  final _secureStorage = const FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) async {
    return await _secureStorage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) async {
    await _secureStorage.delete(key: key);
  }
}

/// 取得適合的存儲服務
StorageService getStorageService() {
  return NativeStorageService();
}

/// 全局存儲實例
final storage = getStorageService();
