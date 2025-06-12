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
    _verifySession();
  }

  Future<void> _verifySession() async {
    // Optionally, you can await any initialization if needed, or remove this line.
    if (!mounted) return;
    
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _redirectToLogin();
    } else {
      _loadUsername();
    }
  }

  Future<void> _loadUsername() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

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
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      Future.microtask(() => _redirectToLogin());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return PopScope(
      canPop: false, // Bloquea el botón físico/menú de retroceso
      onPopInvoked: (didPop) {
        if (!didPop) _redirectToLogin();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Bienvenido')),
        body: Center(
          child: Text(
            '¡Hola, $username!',
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
