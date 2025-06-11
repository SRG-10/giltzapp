// lib/pages/reset_password_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web; // Importación correcta del paquete web

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({Key? key}) : super(key: key);

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleDeepLink();
  }

  Future<void> _handleDeepLink() async {
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    
    if (code == null) {
      setState(() => _error = 'Enlace inválido: falta el código de recuperación');
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.exchangeCodeForSession(code);
      
      // Limpia la URL después de procesar el código (solo en web)
      if (kIsWeb) {
        final currentUrl = web.window.location.href;
        final newUrl = currentUrl.replaceAll('?code=$code', '');
        web.window.history.replaceState(null, '', newUrl);
      }
    } on AuthException catch (e) {
      setState(() => _error = 'Error de autenticación: ${e.message}');
    } catch (e) {
      setState(() => _error = 'El enlace ha expirado o es inválido');
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      
      if (response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada. Inicia sesión.'),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } on AuthException catch (e) {
      setState(() => _error = 'Error al actualizar: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Error inesperado al actualizar la contraseña');
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text('Volver al login'),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contraseña',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Introduce una contraseña';
                          if (value.length < 12) return 'Mínimo 12 caracteres';
                          if (!value.contains(RegExp(r'[A-Z]'))) return 'Al menos una mayúscula';
                          if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) return 'Al menos un símbolo';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value != _passwordController.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _resetPassword,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Actualizar contraseña'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
