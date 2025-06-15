import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:math';

class EncryptionService {

  static final _secureStorage = FlutterSecureStorage();
  static encrypt.Key? _currentMasterKey;

  static Future<void> initialize(encrypt.Key key) async {
    _currentMasterKey = key;
    final keyBase64 = base64Encode(key.bytes);
    await _secureStorage.write(
      key: 'master_key',
      value: keyBase64,
    );
  }

  static Future<encrypt.Key?> get currentMasterKey async {
    if (_currentMasterKey != null) return _currentMasterKey;
    
    final keyString = await _secureStorage.read(key: 'master_key');
    if (keyString != null) {
      return encrypt.Key(base64Decode(keyString));
    }
    return null;
  }

  static Future<void> clear() async {
    _currentMasterKey = null;
    await _secureStorage.delete(key: 'master_key');
  }

  static Future<encrypt.Key> deriveMasterKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      iterations: 310000,
      macAlgorithm: Hmac.sha256(),
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    return encrypt.Key(Uint8List.fromList(await secretKey.extractBytes()));
  }

  

  static Uint8List generateSecureSalt([int length = 32]) {
      final rand = Random.secure();
      return Uint8List.fromList(List.generate(length, (_) => rand.nextInt(256)));
    }

  // Cifrado AES-CBC con HMAC-SHA256
  static Future<Map<String, String>> encryptPassword(String plainText, encrypt.Key key) async {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Generar HMAC
    final hmac = Hmac.sha256();
    final hmacMac = await hmac.calculateMac(
      encrypted.bytes + iv.bytes,
      secretKey: SecretKey(key.bytes),
    );

    return {
      'hash_contrasena': base64Encode(encrypted.bytes),
      'iv': base64Encode(iv.bytes),
      'auth_tag': base64Encode(hmacMac.bytes),
    };
  }

  // Descifrado con verificación de integridad
  static Future<String> decryptPassword({
    required String hashContrasena,
    required String ivBytes,
    required String authTag,
    required encrypt.Key key,
  }) async {
    try {
      final iv = encrypt.IV(base64Decode(ivBytes));
      final encrypted = encrypt.Encrypted(base64Decode(hashContrasena));

      // Verificar HMAC
      final hmac = Hmac.sha256();
      final calculatedHmac = await hmac.calculateMac(
        encrypted.bytes + iv.bytes,
        secretKey: SecretKey(key.bytes),
      );

      if (!constantTimeCompare(
        base64Decode(authTag),
        calculatedHmac.bytes,
      )) {
        throw Exception('Integridad comprometida: datos manipulados');
      }

      if (encrypted.bytes.length < 16 || iv.bytes.length != 16) {
        throw Exception('Datos cifrados corruptos');
      }

      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      return encrypter.decrypt(encrypted, iv: iv);

    }
    catch (e) {
      if (e is ArgumentError) {
        throw Exception('Error de formato: $e');
      }
      rethrow;
    }
    
    
  }

  // Comparación segura en tiempo constante
  static bool constantTimeCompare(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

// Derivación de clave con PBKDF2

// Uso con Supabase
Future<void> main() async {
  await Supabase.initialize(
    url: 'https://abioxiwzcrsemxllqznq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiaW94aXd6Y3JzZW14bGxxem5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyNDAzOTgsImV4cCI6MjA2NDgxNjM5OH0.1xFPpUgEOJZPHnpbYm4GyQvjzCqptIcOO1dGEausiz8',
  );

  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser!;

  // Obtener salt del usuario
  final userData = await supabase
      .from('users')
      .select('salt')
      .eq('auth_id', user.id)
      .single();

  // Derivar clave maestra
  final masterKey = await EncryptionService.deriveMasterKey(
    'contraseña_maestra_secreta',
    base64Decode(userData['salt'] as String)
  );

  // Cifrar y guardar contraseña
  final encrypted = await EncryptionService.encryptPassword('contraseña', masterKey);
  await supabase.from('passwords').insert({
    'hash_contrasena': encrypted['hash_contrasena'],
    'iv': encrypted['iv'],
    'auth_tag': encrypted['auth_tag'],
    'user_id': user.id,
  });

  // Recuperar y descifrar
  final data = await supabase
      .from('passwords')
      .select()
      .eq('user_id', user.id)
      .single();

  if (data['hash_contrasena'] == null || 
    data['iv'] == null || 
    data['auth_tag'] == null) {
    throw Exception('Registro de contraseña corrupto');
}

  final decrypted = await EncryptionService.decryptPassword(
    hashContrasena: data['hash_contrasena'],
    ivBytes: data['iv'],
    authTag: data['auth_tag'],
    key: masterKey,
  );

  print('Contraseña descifrada: $decrypted');
}
