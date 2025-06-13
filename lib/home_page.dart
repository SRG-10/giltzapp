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
  List<Map<String, dynamic>> _passwords = [];
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _verifySession();
  }

  Future<void> _verifySession() async {
    if (!mounted) return;
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _redirectToLogin();
    } else {
      await Future.wait([_loadUsername(), _loadPasswords(), _loadCategories()]);
    }
  }

  Future<void> _loadUsername() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final response = await _supabase
          .from('users')
          .select('nombre_usuario, id')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          username = response?['nombre_usuario'] ?? user.email;
        });
      }
    } catch (e) {
      if (mounted) _redirectToLogin();
    }
  }

  Future<void> _loadCategories() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      // Obtener el id bigint del usuario
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();
      final userId = userResponse['id'] as int;

      final response = await _supabase
          .from('categories')
          .select('id, nombre')
          .eq('usuario_id', userId);

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      // Manejo de errores opcional
    }
  }

  Future<void> _loadPasswords() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();
      final userId = userResponse['id'] as int;

      final response = await _supabase
          .from('passwords')
          .select('id, sitio_web_id, nombre_usuario, notas')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _passwords = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando contraseñas: ${e.toString()}')),
        );
      }
    }
  }

  void _redirectToLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      _redirectToLogin();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
      );
    }
  }

  void _addCategory() {
    // Aquí puedes abrir un diálogo o navegar a una pantalla para agregar categoría
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función para agregar categoría (por implementar)')),
    );
  }

  void _addPassword() {
    // Aquí puedes abrir un diálogo o navegar a una pantalla para agregar contraseña
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función para agregar contraseña (por implementar)')),
    );
  }

  void _copyToClipboard(Map<String, dynamic> password) {
    // Implementar lógica de descifrado aquí
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función en desarrollo')),
    );
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
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _redirectToLogin();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestor de Contraseñas'),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary, // Usa el color primario del tema
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.account_circle, size: 48, color: Theme.of(context).colorScheme.onPrimary),
                      // Y para el nombre de usuario:
                      Text(
                        username ?? 'Usuario',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 20,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Categorías'),
                subtitle: _categories.isEmpty
                    ? const Text('No hay categorías')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _categories
                            .map((cat) => Text(cat['nombre'] ?? '', style: const TextStyle(fontSize: 14)))
                            .toList(),
                      ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Agregar categoría'),
                onTap: _addCategory,
              ),
              ListTile(
                leading: const Icon(Icons.vpn_key),
                title: const Text('Agregar contraseña'),
                onTap: _addPassword,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Cerrar sesión'),
                onTap: _signOut,
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Bienvenido, $username!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _passwords.isEmpty
                  ? const Center(child: Text('No hay contraseñas guardadas'))
                  : ListView.builder(
                      itemCount: _passwords.length,
                      itemBuilder: (context, index) {
                        final password = _passwords[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.lock),
                            title: Text(password['notas'] ?? 'Sin nombre'),
                            subtitle: Text(password['nombre_usuario'] ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copyToClipboard(password),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addPassword,
          tooltip: 'Agregar contraseña',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
