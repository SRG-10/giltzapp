import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:GiltzApp/encryption_service.dart';
import 'package:flutter/services.dart';
import 'dart:async';
// ignore: deprecated_member_use

import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter

import 'web_utils.dart'
    if (dart.library.html) 'web_utils_web.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  // Variables de estado
  bool _clipboardActive = false;
  final int _clipboardSeconds = 10;
  Timer? _clipboardTimer;
  int _remainingSeconds = 0;
  double get _progress => _remainingSeconds / _clipboardSeconds;

  // Métodos de control
  void _startClipboardCountdown() {
    _clipboardActive = true;
    _remainingSeconds = _clipboardSeconds;
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0 && mounted) {
        setState(() => _remainingSeconds--);
      } else {
        _clearClipboard();
        timer.cancel();
      }
    });
  }

  void _clearClipboard() async {
    _clipboardTimer?.cancel();
    await Clipboard.setData(const ClipboardData(text: ''));
    if (mounted) {
      setState(() {
        _clipboardActive = false;
        _remainingSeconds = 0;
      });
    }
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    super.dispose();
  }




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

  Future<void> _addCategory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final userResponse = await _supabase
        .from('users')
        .select('id')
        .eq('auth_id', user.id)
        .single();
    final userId = userResponse['id'] as int;

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre de la categoría'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _supabase.from('categories').insert({
        'usuario_id': userId,
        'nombre': result,
      });
      await _loadCategories();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoría añadida')),
      );
    }
  }

  // MÉTODO PARA AGREGAR CONTRASEÑA
  Future<void> _addPassword() async {

    final masterKey = await EncryptionService.currentMasterKey;

      if (masterKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Sesión no válida')),
          );
        }
        return;
      }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Obtener clave maestra actual
      final masterKey = await EncryptionService.currentMasterKey;
      if (masterKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Sesión no válida')),
        );
        return;
      }

      // 2. Obtener datos del formulario
      final TextEditingController siteController = TextEditingController();
      final TextEditingController userController = TextEditingController();
      final TextEditingController passController = TextEditingController();
      final TextEditingController notesController = TextEditingController();

      final userResponse = await _supabase
        .from('users')
        .select('id')
        .eq('auth_id', user.id)
        .single();

      final userId = userResponse['id'] as int;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nueva contraseña'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: siteController,
                  decoration: const InputDecoration(labelText: 'Sitio'),
                ),
                TextField(
                  controller: userController,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                ),
                TextField(
                  controller: passController,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final sitio = siteController.text.trim();
                final nombreUsuario = userController.text.trim();
                final password = passController.text.trim();
                final notas = notesController.text.trim();

                if (sitio.isEmpty || password.isEmpty) return;

                // Obtener ID numérico del usuario
                final userResponse = await _supabase
                    .from('users')
                    .select('id')
                    .eq('auth_id', user.id)
                    .single();
                final userId = userResponse['id'] as int;

                // 3. Cifrar la contraseña
                final encrypted = await EncryptionService.encryptPassword(password, masterKey);

                // 4. Crear/actualizar sitio web
                final webSiteResponse = await _supabase
                    .from('web_sites')
                    .upsert({
                      'usuario_id': userId,
                      'nombre_sitio': sitio,
                    }, 
                    onConflict: 'nombre_sitio,usuario_id')
                    .select('id')
                    .single();
                
                final sitioWebId = webSiteResponse['id'] as int;

                // 5. Insertar contraseña cifrada
                await _supabase.from('passwords').insert({
                  'sitio_web_id': sitioWebId,
                  'nombre_usuario': nombreUsuario,
                  'hash_contrasena': encrypted['hash_contrasena'],
                  'iv': encrypted['iv'],
                  'auth_tag': encrypted['auth_tag'],
                  'notas': notas,
                  'user_id': userId,
                });

                if (encrypted['hash_contrasena'] == null || 
                    encrypted['iv'] == null || 
                    encrypted['auth_tag'] == null) {
                  throw Exception('Error: Datos cifrados incompletos');
                }

                await _loadPasswords();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contraseña añadida')),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }


  Future<void> _verifySession() async {
    if (!mounted) return;
    
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _redirectToLogin();
      return;
    }

    try {
      final masterKey = await EncryptionService.currentMasterKey;
      if (masterKey == null || !mounted) {
        _redirectToLogin();
        return;
      }
      
      await Future.wait([_loadUsername(), _loadPasswords(), _loadCategories()]);
    } catch (e) {
      if (mounted) _redirectToLogin();
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
          _loading = false; // Añade esto para forzar actualización
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _redirectToLogin();
      }
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
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final userResponse = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();
      final userId = userResponse['id'] as int;

      final response = await _supabase
        .from('passwords')
        .select('''
            id, 
            sitio_web_id, 
            nombre_usuario, 
            notas,
            hash_contrasena,
            iv,
            auth_tag
        ''')
        .eq('user_id', userId);


      if (mounted) {
        setState(() {
          _passwords = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false); // <- Añade esto
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
      await EncryptionService.clear();
      _redirectToLogin();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
      );
    }
  }

  void _copyToClipboard(BuildContext context, Map<String, dynamic> password) async {
  try {
    if (password['hash_contrasena'] == null || 
        password['iv'] == null || 
        password['auth_tag'] == null) {
      throw Exception('Datos cifrados incompletos');
    }

    final masterKey = await EncryptionService.currentMasterKey;
    if (masterKey == null || !mounted) return;

    final decrypted = await EncryptionService.decryptPassword(
      hashContrasena: password['hash_contrasena']!,
      ivBytes: password['iv']!,
      authTag: password['auth_tag']!,
      key: masterKey,
    );

    if (decrypted.isEmpty) throw Exception('Texto a copiar vacío');

    if (kIsWeb) {
      final isMobile = isMobileWeb();
      
      if (isMobileWeb()) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mostrar contraseña'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Por seguridad, la contraseña no se mostrará directamente.'),
                ElevatedButton(
                  child: const Text('Mostrar durante 5 segundos'),
                  onPressed: () async {
                    // Mostrar contraseña temporalmente aquí
                  },
                ),
                ElevatedButton(
                  child: const Text('Copiar al portapapeles'),
                  onPressed: () async {
                    // Copiar contraseña aquí
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
        //_startClipboardCountdown();
      } else {
        await Clipboard.setData(ClipboardData(text: decrypted));
        _startClipboardCountdown();
      }
    } else {
      await Clipboard.setData(ClipboardData(text: decrypted));
      _startClipboardCountdown();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contraseña copiada (válida por $_clipboardSeconds segundos)'),
          duration: Duration(seconds: _clipboardSeconds),
        ),
      );
    }

  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al copiar: ${e.toString()}')),
    );
  }
}

// Widget de la barra de progreso en el build



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
            if (_clipboardActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tiempo restante: $_remainingSeconds segundos',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _passwords.isEmpty
                  ? const Center(child: Text('No hay contraseñas guardadas'))
                  :ListView.builder(
                    itemCount: _passwords.length,
                    itemBuilder: (context, index) {
                      final password = _passwords[index];
                      
                      // Verificar integridad antes de mostrar
                      final bool isCorrupt = password['hash_contrasena'] == null || 
                                            password['iv'] == null || 
                                            password['auth_tag'] == null;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.lock),
                          title: Text(password['notas'] ?? 'Sin nombre'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Usuario: ${password['nombre_usuario'] ?? ''}'),
                              if (isCorrupt) 
                                const Text('⚠️ Contraseña corrupta', 
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Timer.run(() => _copyToClipboard(context, password)); // Ejecutar inmediatamente tras el gesto
                            },
                          ),
                        ),
                      );
                    },
                  )
            ),
            LinearProgressIndicator(
              value: _progress,
              minHeight: 3,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            )
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

