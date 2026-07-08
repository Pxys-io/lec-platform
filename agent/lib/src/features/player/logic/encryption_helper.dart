import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class EncryptionHelper {
  static const _encryptionKey = String.fromEnvironment(
    'ENCRYPTION_KEY',
    defaultValue: 'my_32_char_super_secret_key_!!!!',
  );
  static final _key = Key.fromUtf8(_encryptionKey); // 32 bytes for AES-256
  static final _iv = IV.fromLength(16);

  static Uint8List encrypt(Uint8List data) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: _iv);
    return encrypted.bytes;
  }

  static Uint8List decrypt(Uint8List data) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(Encrypted(data), iv: _iv);
    return Uint8List.fromList(decrypted);
  }
}
