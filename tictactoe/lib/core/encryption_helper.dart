// lib/core/encryption_helper.dart
import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionHelper {
  static final _storage = FlutterSecureStorage();
  static const _keyStorageKey = 'encryption_key';

  static Future<Encrypter> _getEncrypter() async {
    String? base64Key = await _storage.read(key: _keyStorageKey);
    if (base64Key == null) {
      final key = Key.fromSecureRandom(32);
      base64Key = base64.encode(key.bytes);
      await _storage.write(key: _keyStorageKey, value: base64Key);
    }
    final keyBytes = base64.decode(base64Key);
    final key = Key(keyBytes);
    return Encrypter(AES(key));
  }

  static Future<String> encrypt(String plainText) async {
    final encrypter = await _getEncrypter();
    final iv = IV.fromLength(16); // Same IV each time = okay for this use case
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  static Future<String> decrypt(String encryptedText) async {
  try {
    final encrypter = await _getEncrypter();
    final iv = IV.fromLength(16);
    return encrypter.decrypt64(encryptedText, iv: iv);
  } catch (_) {
    return encryptedText; // fallback to plain if not base64
  }
}

}
