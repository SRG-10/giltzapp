import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'home_page.dart'; 
//import 'dart:io' show Platform;
import 'pages/reset_password_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://abioxiwzcrsemxllqznq.supabase.co',        
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiaW94aXd6Y3JzZW14bGxxem5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyNDAzOTgsImV4cCI6MjA2NDgxNjM5OH0.1xFPpUgEOJZPHnpbYm4GyQvjzCqptIcOO1dGEausiz8', 
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
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
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthPage(),
        '/reset-password': (context) => const ResetPasswordPage(),
      },
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

  bool _isLogin = true;
  bool _isLoading = false;

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
      if (response.user != null) {
        limpiarCampos();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(email: response.user!.email),
          ),
        );
      }
    } on AuthException catch (error) {
      // Mostrar el error en un AlertDialog
      showDialog(
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
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('Error inesperado'),
          content: Text('Error inesperado durante el login'),
        ),
      );
      setState(() {
        _errorMessage = 'Error inesperado durante el login';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  }

  Future<void> _submitRegister() async {
    if (_isLoading) return; // Evita múltiples envíos
    if (_formKeyRegister.currentState!.validate() &&
        _minLength && _hasUpper && _hasLower && _hasDigit) {
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
          final hash = sha256.convert(utf8.encode(_regPasswordController.text)).toString();
          await supabase.from('users').insert({
            'nombre_usuario': _usernameController.text,
            'correo_electronico': _regEmailController.text,
            'hash_contrasena_maestra': hash,
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
    _loginPasswordVisible = false;
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) { // Construye la interfaz de usuario
    // Si el usuario ya está autenticado, redirige a la página de inicio
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
  final _forgotEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _emailError;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _forgotEmailController,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: const Icon(Icons.email),
                errorText: _emailError,
              ),
              keyboardType: TextInputType.emailAddress,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu correo';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                  return 'Correo no válido';
                }
                return _emailError; // Muestra el error de existencia aquí
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final email = _forgotEmailController.text.trim();
                  
                  // Verificar si el correo existe en Supabase
                  final supabase = Supabase.instance.client;
                  final response = await supabase
                      .from('users')
                      .select()
                      .eq('correo_electronico', email)
                      .maybeSingle();

                  final user = response;
                  if (user == null) {
                    setState(() => _emailError = 'Correo no registrado');
                  } else {
                    Navigator.pop(context);
                    _sendPasswordResetEmailAndShowSuccess(email);
                  }
                }
              },
              child: const Text('Enviar'),
            ),
          ],
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

  /*@override
void initState() {
  // Aquí puedes inicializar cualquier cosa que necesites antes de que el widget se construya
  super.initState();
  _handleEmailConfirmation();
}

Future<void> _handleEmailConfirmation() async {
  final uri = Uri.base;
  final code = uri.queryParameters['code'];
  if (code != null) {
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.exchangeCodeForSession(code);
      // Ahora el usuario está autenticado, puedes redirigirlo a la home o mostrar un mensaje
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(email: supabase.auth.currentUser?.email ?? ''),
        ),
      );
    } catch (e) {
      // Maneja el error si el código es inválido o expiró
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al confirmar el correo: $e')),
      );
    }
  }
}*/
}
