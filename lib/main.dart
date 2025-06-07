import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'home_page.dart'; 
//import 'dart:io' show Platform;


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
      home: const AuthPage(),
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
  bool get _minLength => _regPasswordController.text.length >= 6;
  bool get _hasUpper => _regPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLower => _regPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _regPasswordController.text.contains(RegExp(r'\d'));

  void _toggleForm() { // Cambia entre login y registro
    if (_isLoading) return; // Evita cambios si está cargando
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _regPasswordController.clear();
      _regConfirmPasswordController.clear();
      limpiarCampos();
    });
  }

  void limpiarCampos() { // Limpia todos los campos de texto
    _loginPasswordVisible = false;
    _emailController.clear();
    _passwordController.clear();
    _usernameController.clear();
    _regEmailController.clear();
    _regPasswordController.clear();
    _regConfirmPasswordController.clear();
  }

  Future<void> _submitLogin() async { // Maneja el inicio de sesión
    if (_isLoading) return; // Evita múltiples envíos
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
        setState(() {
          _errorMessage = error.message;
        });
      } catch (e) {
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

  Future<void> _submitRegister() async { // Maneja el registro de usuario
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
            _isLoading = false;
          });
          return;
        }

        final response = await supabase.auth.signUp(
          email: _regEmailController.text,
          password: _regPasswordController.text,
          emailRedirectTo: 'https://srg-10.github.io/giltzapp_web/', // Cambia esto por tu URL de redirección
          data: {
            'username': _usernameController.text,
          },
        );
        if (response.user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro exitoso. Revisa tu email para confirmar la cuenta.')),
          );
          final hash = sha256.convert(utf8.encode(_regPasswordController.text)).toString();
          // Inserta el usuario en la tabla public.users
          // ignore: unused_local_variable
          await supabase.from('users').insert({
            'nombre_usuario': _usernameController.text,
            'correo_electronico': _regEmailController.text,
            'hash_contrasena_maestra': hash,
          });
          // Puedes manejar errores aquí si insertResponse tiene error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro exitoso. Revisa tu email para confirmar la cuenta.')),
          );
          _toggleForm();

        }
      } on AuthException catch (error) {
        setState(() {
          _errorMessage = error.message;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Error inesperado durante el registro';
        });
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
              if (!value.contains('@')) {
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
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
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
          TextButton(
            onPressed: _isLoading ? null : _toggleForm,
            child: const Text('¿No tienes cuenta? Regístrate'),
          ),
        ],
      ),
    );
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
              if (!value.contains('@')) {
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
        _buildRequirementRow("Al menos 6 caracteres", _minLength),
        _buildRequirementRow("Una letra mayúscula", _hasUpper),
        _buildRequirementRow("Una letra minúscula", _hasLower),
        _buildRequirementRow("Un número", _hasDigit),
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
}
