import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();

 
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  String? username;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _redirectToLogin();
      } else {
        _loadUsername();
      }
    });
  }


  Future<void> _loadUsername() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _redirectToLogin();
      return;
    }

    try {
      final response = await _supabase
          .from('users')
          .select('nombre_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          username = response?['nombre_usuario'] ?? user.email;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) _redirectToLogin();
    }
  }

  void _redirectToLogin() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenido')),
      body: Center(
        child: Text(
          '¡Hola, $username!',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
