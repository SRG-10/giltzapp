import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show  kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
//import 'package:crypto/crypto.dart';
import 'home_page.dart'; 

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:encrypt/encrypt.dart' as encrypt;
import 'encryption_service.dart';
import 'dart:typed_data';

import 'web_utils.dart'
    if (dart.library.html) 'web_utils_web.dart';

// Use conditional import for web only
// ignore: uri_does_not_exist

// Conditional import for web platform
// Place this at the top of the file, after other imports
// ignore: uri_does_not_exist, deprecated_member_use


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://abioxiwzcrsemxllqznq.supabase.co',        
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiaW94aXd6Y3JzZW14bGxxem5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyNDAzOTgsImV4cCI6MjA2NDgxNjM5OH0.1xFPpUgEOJZPHnpbYm4GyQvjzCqptIcOO1dGEausiz8',
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Usa PKCE para mayor seguridad
    )
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'GiltzApp - Gestor de Contraseñas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final session = Supabase.instance.client.auth.currentSession;
          final isResetFlow = Uri.base.path == '/reset-password';

          // Solo muestra HomePage si hay sesión Y NO es flujo de reseteo
          if (session != null && !isResetFlow) {
            return const HomePage();
          } else {
            return const AuthPage();
          }
        },
      ),

      onGenerateRoute: (settings) {
        // Maneja rutas no definidas (opcional)
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Página no encontrada')),
          ),
        );
      },
    );
  }
}




class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();

  
}

class _AuthPageState extends State<AuthPage> {
  final _formKeyLogin = GlobalKey<FormState>();
  final _formKeyRegister = GlobalKey<FormState>();

  encrypt.Key? _currentMasterKey;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _resetPasswordVisible = false;


  // Controladores login
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loginPasswordVisible = false;

  // Controladores registro
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  final TextEditingController _regConfirmPasswordController = TextEditingController();
  bool _regPasswordVisible = false;

  String? _errorMessage;

  // Requisitos de contraseña
  bool get _minLength => _regPasswordController.text.length >= 12;
  bool get _hasUpper => _regPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLower => _regPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _regPasswordController.text.contains(RegExp(r'\d'));
  bool get _hasSpecial => _regPasswordController.text.contains(RegExp(r'''[ªº\\!"|@·#$~%€&¬/()=?'¡¿`^[\]*+´{}\-\_\.\:\,\;\<\>"]'''));

  void _toggleForm() {
    if (_isLoading) return;
    
    // Primero actualiza el estado para cambiar de formulario
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });

    // Limpia solo los campos relevantes después de la actualización
    _regPasswordController.clear();
    _regConfirmPasswordController.clear();
    _usernameController.clear();
    _regEmailController.clear();
    _emailController.clear();
    _passwordController.clear();
  }


  void limpiarCampos() {
    _loginPasswordVisible = false;
    _emailController.clear();
    _passwordController.clear();
  }

  Future<void> _submitLogin() async {
    if (_isLoading) return;
    if (_formKeyLogin.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        final userData = await supabase
            .from('users')
            .select('salt')
            .eq('auth_id', response.user!.id)
            .single();

        final salt = base64Decode(userData['salt'] as String);
        final masterKey = await EncryptionService.deriveMasterKey(_passwordController.text, salt);

        await EncryptionService.initialize(masterKey);

        if(!mounted) return; // Verifica si el widget sigue montado

        if (mounted)
        {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
        }
        

      } on AuthException catch (error) {
        // Mostrar el error en un AlertDialog
        if (mounted) { setState(() => _isLoading = false); }
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error de inicio de sesión'),
            content: Text(error.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() {
          _errorMessage = error.message;
        });
      } catch (e) {
        if (mounted)
        {
          showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Error inesperado'),
            content: Text('Error inesperado durante el login'),
          ),
        );
        setState(() {
          _errorMessage = 'Error inesperado durante el login';
        });
        }
       
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitRegister() async {
    if (_isLoading) return; // Evita múltiples envíos
    if (_formKeyRegister.currentState!.validate() && _minLength && _hasUpper && _hasLower && _hasDigit) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final supabase = Supabase.instance.client;

        final existing = await supabase
            .from('users')
            .select()
            .or('correo_electronico.eq.${_regEmailController.text},nombre_usuario.eq.${_usernameController.text}')
            .maybeSingle();

        if (existing != null) {
          setState(() {
            _errorMessage = 'El correo electrónico o el nombre de usuario ya están en uso.';
          });
          showDialog(
            // ignore: use_build_context_synchronously
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error de registro'),
              content: Text(_errorMessage!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        final response = await supabase.auth.signUp(
          email: _regEmailController.text,
          password: _regPasswordController.text,
          emailRedirectTo: 'giltzapp.vercel.app', // Cambia esto por tu URL de redirección
          data: {
            'username': _usernameController.text,
          },
        );
        if (response.user != null) {
          final salt = EncryptionService.generateSecureSalt();
          final masterKey = await EncryptionService.deriveMasterKey(_regPasswordController.text, salt);
          //final hash = sha256.convert(utf8.encode(_regPasswordController.text)).toString();
          await supabase.from('users').insert({
            'auth_id': response.user!.id,
            'nombre_usuario': _usernameController.text,
            'correo_electronico': _regEmailController.text,
            'hash_contrasena_maestra': base64Encode(masterKey.bytes),
            'salt': base64Encode(salt),
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro exitoso. Revisa tu email para confirmar la cuenta. También consulta la carpeta de spam.')),
          );
          setState(() {
            _isLogin = true;
          });
          // Solo limpiar los campos de registro, no los de login
          _regPasswordController.clear();
          _regConfirmPasswordController.clear();
          _usernameController.clear();
          _regEmailController.clear();
        }
      } on AuthException catch (error) {
        String mensaje;
        // Intenta decodificar el mensaje si es un JSON
        try {
          final decoded = jsonDecode(error.message);
          if (decoded is Map && decoded['message'] == 'Error sending confirmation email') {
            mensaje = 'No se pudo enviar el correo de confirmación.';
          } else {
            mensaje = decoded['message'] ?? 'Error desconocido durante el registro.';
          }
        } catch (_) {
          // Si no es un JSON, usa el mensaje original
          if (error.message.contains('Error sending confirmation email')) {
            mensaje = 'No se pudo enviar el correo de confirmación.';
          } else {
            mensaje = error.message;
          }
        }
        setState(() {
          _errorMessage = mensaje;
        });
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error de registro'),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Error inesperado durante el registro';
        });
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Error inesperado'),
            content: Text('Ha ocurrido un error inesperado durante el registro.'),
            actions: [
              TextButton(
                onPressed: null, // O Navigator.of(context).pop()
                child: Text('OK'),
              ),
            ],
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = "La contraseña no cumple todos los requisitos.";
      });
    }
  }

  @override
  void dispose() { // Limpia los controladores al eliminar el widget
    _currentMasterKey?.bytes.fillRange(0, _currentMasterKey!.bytes.length, 0); // Limpia el contenido del master key
    _currentMasterKey = null;
    _loginPasswordVisible = false;
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  final _resetFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _resetLoading = false;

  @override
  Widget build(BuildContext context) {
    if (_showResetPassword) {
      // Muestra el formulario de reseteo
      return _buildResetPasswordForm();
    }
    // Si no es reseteo, muestra login o registro
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Iniciar sesión' : 'Registrarse'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _isLogin ? _buildLoginForm() : _buildRegisterForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

Widget _buildResetPasswordForm() {
  return PopScope(
    canPop: false, // Bloquea el pop por defecto
    // ignore: deprecated_member_use
    onPopInvoked: (didPop) async {
      if (!didPop) {
        _redirectToLogin(); // Cierra sesión y limpia todo
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Restablecer contraseña'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _resetFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Introduce tu nueva contraseña',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _newPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _resetPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _resetPasswordVisible = !_resetPasswordVisible;
                              });
                            },
                          ),
                        ),
                        obscureText: !_resetPasswordVisible,
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa la nueva contraseña';
                          if (!_minLengthReset) return 'Mínimo 12 caracteres';
                          if (!_hasUpperReset) return 'Al menos una mayúscula';
                          if (!_hasLowerReset) return 'Al menos una minúscula';
                          if (!_hasDigitReset) return 'Al menos un número';
                          if (!_hasSpecialReset) return 'Al menos un carácter especial';
                          return null;
                        },
                      ),
                      if (_newPasswordController.text.isNotEmpty) _buildPasswordRequirementsReset(),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Confirma la contraseña';
                          if (value != _newPasswordController.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _resetLoading ? null : _submitResetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _resetLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Actualizar contraseña'),
                        ),
                      ),
                      if (_resetError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _resetError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showResetPassword = false;
                            _resetError = null;
                          });
                        },
                        child: const Text('Volver al login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}


// Añade estas variables en tu estado
bool get _minLengthReset => _newPasswordController.text.length >= 12;
bool get _hasUpperReset => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
bool get _hasLowerReset => _newPasswordController.text.contains(RegExp(r'[a-z]'));
bool get _hasDigitReset => _newPasswordController.text.contains(RegExp(r'\d'));
bool get _hasSpecialReset => _newPasswordController.text.contains(RegExp(r'''[ªº\\!"|@·#$~%€&¬/()=?'¡¿`^[\]*+´{}\-\_\.\:\,\;\<\>"]'''));

Widget _buildPasswordRequirementsReset() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      const Text(
        "La contraseña debe contener:",
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 4),
      _buildRequirementRow("Al menos 12 caracteres", _minLengthReset),
      _buildRequirementRow("Una letra mayúscula", _hasUpperReset),
      _buildRequirementRow("Una letra minúscula", _hasLowerReset),
      _buildRequirementRow("Un número", _hasDigitReset),
      _buildRequirementRow("Un carácter especial", _hasSpecialReset),
    ],
  );
}






Future<void> _submitResetPassword() async {
  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;
    
    // 1. Obtener clave actual antes del cambio
    final userData = await supabase
        .from('users')
        .select('salt, hash_contrasena_maestra')
        .eq('auth_id', user.id)
        .single();

    if (userData['salt'] == null) {
      throw Exception('Usuario no tiene salt registrado');
    }

    // Verificar formato base64
      try {
        base64Decode(userData['salt'] as String);
      } catch (e) {
        throw Exception('Formato de salt inválido');
      }

    final currentSalt = Uint8List.fromList(userData['salt'] as List<int>);
    _currentMasterKey = await EncryptionService.deriveMasterKey(
      _passwordController.text, // Contraseña actual
      currentSalt,
    );

    // 2. Generar nuevos componentes de seguridad
    final newSalt = EncryptionService.generateSecureSalt();
    final newMasterKey = await EncryptionService.deriveMasterKey(
      _newPasswordController.text,
      newSalt,
    );

    // 3. Actualizar en transacción
    await supabase.rpc('update_user_credentials', params: {
      'user_id': user.id,
      'new_password': _newPasswordController.text,
      'new_hash': base64Encode(newMasterKey.bytes),
      'new_salt': base64Encode(newSalt),
    });

    // 4. Migrar contraseñas con ambas claves
    await _migratePasswords(
      userId: user.id,
      oldKey: _currentMasterKey!,
      newKey: newMasterKey,
    );

    // 5. Limpiar clave anterior
    _currentMasterKey = null;

  } on PostgrestException catch (e) {
    setState(() => _resetError = 'Error de base de datos: ${e.message}');
  } catch (e) {
    setState(() => _resetError = 'Error inesperado: ${e.toString()}');
  } finally {
    setState(() => _resetLoading = false);
  }
}

Future<void> _migratePasswords({required String userId, required encrypt.Key oldKey, required encrypt.Key newKey,}) async {

  final supabase = Supabase.instance.client;
  
  final passwords = await supabase
      .from('passwords')
      .select()
      .eq('user_id', userId);

  for (final pwd in passwords) {

    if (pwd['hash_contrasena'] == null || pwd['iv'] == null || pwd['auth_tag'] == null) continue;

    // Descifrar con clave antigua
    final decrypted = await EncryptionService.decryptPassword(
      hashContrasena: pwd['hash_contrasena'] as String,
      ivBytes: pwd['iv'] as String,
      authTag: pwd['auth_tag'] as String,
      key: oldKey,
    );
    
    // Cifrar con nueva clave
    final encrypted = await EncryptionService.encryptPassword(decrypted, newKey);
    
    // Actualizar con todos los campos requeridos
    await supabase.from('passwords').update({
      'hash_contrasena': encrypted['hash_contrasena'],
      'iv': encrypted['iv'],
      'auth_tag': encrypted['auth_tag'],
    }).eq('id', pwd['id']);
  }
} 

  void _redirectToLogin() async {
  // 1. Cierra la sesión PKCE generada por el enlace de recuperación
  await Supabase.instance.client.auth.signOut(); 
  
  // 2. Limpia el estado del formulario
  setState(() {
    _showResetPassword = false;
    _resetError = null;
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _isLogin = true;
  });

  if (kIsWeb) {
    clearWebUrl(); // Esto solo hará algo en web, en móvil no hace nada.
  }
    
  
  // 4. Redirige al login y elimina el historial de navegación
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}


  final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,3}$');
  // Expresión regular para validar correos electrónicos
  final RegExp passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~.,;:_\-+=?¿¡!%/(){}\[\]]).{12,}$');

  Widget _buildLoginForm() { // Construye el formulario de inicio de sesión
    _errorMessage = null; // Resetea el mensaje de error al construir el formulario
    return Form(
      key: _formKeyLogin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu correo';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _loginPasswordVisible = !_loginPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !_loginPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu contraseña';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitLogin,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Iniciar sesión'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isLoading ? null : _showForgotPasswordDialog,
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              TextButton(
                onPressed: _isLoading ? null : _toggleForm,
                child: const Text('Regístrate'),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _showForgotPasswordDialog() {
    final forgotEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? emailError;
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Recuperar contraseña',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: forgotEmailController,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(Icons.email),
                          border: const OutlineInputBorder(),
                          errorText: emailError,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                            return 'Correo no válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  setState(() {
                                    emailError = null;
                                    loading = true;
                                  });
                                  if (formKey.currentState!.validate()) {
                                    final email = forgotEmailController.text.trim();
                                    final supabase = Supabase.instance.client;
                                    final response = await supabase
                                        .from('users')
                                        .select()
                                        .eq('correo_electronico', email)
                                        .maybeSingle();

                                    if (response == null) {
                                      setState(() {
                                        emailError = 'Correo no registrado';
                                        loading = false;
                                      });
                                    } else {
                                      await _sendPasswordResetEmailAndShowSuccess(email);
                                      Navigator.pop(context);
                                    }
                                  } else {
                                    setState(() => loading = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Enviar'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  Future<void> _sendPasswordResetEmailAndShowSuccess(String email) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://giltzapp.vercel.app/reset-password', // Tu URL de recuperación
      );
      // Muestra mensaje de éxito tipo registro y vuelve al login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo enviado. Revisa tu correo para restablecer la contraseña. También consulta la carpeta de spam.'),
          duration: Duration(seconds: 5),
        ),
      );
      if (!_isLogin) {
        setState(() {
          _isLogin = true; // Cambia a la pantalla de login
        });
      }
    } on AuthException catch (error) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }



  Widget _buildRegisterForm() { // Construye el formulario de registro
    _errorMessage = null; // Resetea el mensaje de error al construir el formulario
    return Form(
      key: _formKeyRegister,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Nombre de usuario',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa un nombre de usuario';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regEmailController,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu correo';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regPasswordController,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _regPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _regPasswordVisible = !_regPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !_regPasswordVisible,
            onChanged: (_) => setState(() {}), // Actualiza requisitos en tiempo real
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu contraseña';
              }
              return null;
            },
          ),
          if (_regPasswordController.text.isNotEmpty) _buildPasswordRequirements(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regConfirmPasswordController,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
            obscureText: true, // No hay icono de ojo aquí
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor confirma tu contraseña';
              }
              if (value != _regPasswordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Registrarse'),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _toggleForm,
            child: const Text('¿Ya tienes cuenta? Inicia sesión'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirements() { // Construye los requisitos de la contraseña
    if (_regPasswordController.text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          "La contraseña debe contener:",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        _buildRequirementRow("Al menos 12 caracteres", _minLength),
        _buildRequirementRow("Una letra mayúscula", _hasUpper),
        _buildRequirementRow("Una letra minúscula", _hasLower),
        _buildRequirementRow("Un número", _hasDigit),
        _buildRequirementRow("Un carácter especial", _hasSpecial),
      ],
    );
  }

  Widget _buildRequirementRow(String text, bool met) { // Construye una fila para cada requisito de contraseña
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.cancel,
          color: met ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: met ? Colors.green : Colors.red,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ignore: unused_field
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    // Aquí puedes inicializar cualquier cosa que necesites antes de que el widget se construya
    super.initState();
    _checkForPasswordReset();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _showResetPassword = true;
          _isPasswordRecovery = true;
          // Puedes limpiar controladores aquí si quieres
        });
      }
    });
    //_handleEmailConfirmation();
  }

  bool _showResetPassword = false;
  // ignore: unused_field
  String? _resetCode;
  String? _resetError;

  void _checkForPasswordReset() {
    final uri = Uri.base;
    if (uri.path == '/reset-password' && uri.queryParameters['code'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showResetPassword = true;
          _resetCode = uri.queryParameters['code'];
        });
      });
    }
  }

}