// lib/pages/reset_password_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (code != null) {
      try {
        final supabase = Supabase.instance.client;
        await supabase.auth.exchangeCodeForSession(code);
      } catch (e) {
        setState(() {
          _error = "El enlace no es válido o ha expirado.";
        });
      }
    } else {
      setState(() {
        _error = "No se encontró el código de recuperación.";
      });
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
          const SnackBar(content: Text('Contraseña actualizada. Inicia sesión.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        setState(() {
          _error = "No se pudo actualizar la contraseña.";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error al actualizar la contraseña.";
      });
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
              ? Text(_error!, style: const TextStyle(color: Colors.red))
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Introduce una contraseña';
                          }
                          if (value.length < 12) {
                            return 'Mínimo 12 caracteres';
                          }
                          // ...otros requisitos...
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                        obscureText: true,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _loading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _resetPassword,
                              child: const Text('Actualizar contraseña'),
                            ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
