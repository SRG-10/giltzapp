import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:math';


class EncryptionService {

  static final almacenamientoSeguro = FlutterSecureStorage();
  static encrypt.Key? _masterKeyActual;

  static Future<void> initialize(encrypt.Key key) async {
    try {
      _masterKeyActual = key;
      final keyBase64 = base64Encode(key.bytes);
      await almacenamientoSeguro.write(
        key: 'master_key',
        value: keyBase64,
        webOptions: const WebOptions(
        ), 
      );
    } catch (e) {
      print('Error guardando clave: $e');
    }
  }

  static Future<encrypt.Key?> get masterKeyActual async {
    if (_masterKeyActual != null) return _masterKeyActual;
    
    final keyString = await almacenamientoSeguro.read(key: 'master_key');
    if (keyString != null) {
      return encrypt.Key(base64Decode(keyString));
    }
    return null;
  }

  static Future<void> limpiar() async {
    _masterKeyActual = null;
    await almacenamientoSeguro.delete(key: 'master_key');
  }

  static Future<encrypt.Key> derivarMasterKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      iterations: 310000,
      macAlgorithm: Hmac.sha256(),
      bits: 256,
    );

    final keySecreto = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    return encrypt.Key(Uint8List.fromList(await keySecreto.extractBytes()));
  }

  static Uint8List generarSaltSeguro([int length = 32]) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  // Cifrado AES-CBC con HMAC-SHA256
  static Future<Map<String, String>> cifrarPassword(String textoPlano, encrypt.Key key) async {
    final cifrar = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );

    final iv = encrypt.IV.fromSecureRandom(16);
    final cifrado = cifrar.encrypt(textoPlano, iv: iv);

    // Generar HMAC
    final hmac = Hmac.sha256();
    final hmacMac = await hmac.calculateMac(
      cifrado.bytes + iv.bytes,
      secretKey: SecretKey(key.bytes),
    );

    return {
      'hash_contrasena': base64Encode(cifrado.bytes),
      'iv': base64Encode(iv.bytes),
      'auth_tag': base64Encode(hmacMac.bytes),
    };
  }

  // Descifrado con verificación de integridad
  static Future<String> descifrarPassword({
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

      if (!compararConsTiempo(
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
  static bool compararConsTiempo(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int resultado = 0;
    for (int i = 0; i < a.length; i++) {
      resultado |= a[i] ^ b[i];
    }
    return resultado == 0;
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
  final usuario = supabase.auth.currentUser!;

  // Obtener salt del usuario
  final userData = await supabase
      .from('users')
      .select('salt')
      .eq('auth_id', usuario.id)
      .single();

  // Derivar clave maestra
  final masterKey = await EncryptionService.derivarMasterKey(
    'contraseña_maestra_secreta',
    base64Decode(userData['salt'] as String)
  );

  // Cifrar y guardar contraseña
  final cifrado = await EncryptionService.cifrarPassword('contraseña', masterKey);

  await supabase.from('passwords').insert({
    'hash_contrasena': cifrado['hash_contrasena'],
    'iv': cifrado['iv'],
    'auth_tag': cifrado['auth_tag'],
    'user_id': usuario.id,
  });

  // Recuperar y descifrar
  final datos = await supabase
      .from('passwords')
      .select()
      .eq('user_id', usuario.id)
      .single();

  if (datos['hash_contrasena'] == null || datos['iv'] == null || datos['auth_tag'] == null) {
    throw Exception('Registro de contraseña corrupto');
  }

  final descifrado = await EncryptionService.descifrarPassword(
    hashContrasena: datos['hash_contrasena'],
    ivBytes: datos['iv'],
    authTag: datos['auth_tag'],
    key: masterKey,
  );

  print('Contraseña descifrada: $descifrado');
}
