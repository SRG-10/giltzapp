import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:GiltzApp/encryption_service.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:gpassword/gpassword.dart';
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

Future<void> showPasswordGeneratorDialog(BuildContext context, TextEditingController controller) async {
    int length = 16;
    bool useUpper = true;
    bool useNumbers = true;
    bool useSymbols = true;
    String generated = '';

    final gpassword = GPassword();

    void generate() {
      // Si todas están desmarcadas, solo minúsculas
      if (!useUpper && !useNumbers && !useSymbols) {
        generated = gpassword.generate(
          passwordLength: length,
          includeUppercase: false,
          includeLowercase: true,
          includeNumbers: false,
          includeSymbols: false,
        );
      } else {
        generated = gpassword.generate(
          passwordLength: length,
          includeUppercase: useUpper,
          includeLowercase: true, // SIEMPRE minúsculas
          includeNumbers: useNumbers,
          includeSymbols: useSymbols,
        );
      }
    }

    generate(); // Genera una inicial

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobile = screenWidth < 700;
            final dialogWidth = isMobile ? screenWidth * 0.98 : 500.0;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              title: const Text('Generar contraseña segura'),
              content: Container(
                width: dialogWidth,
                constraints: const BoxConstraints(
                  minWidth: 280,
                  maxWidth: 600,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Campo de contraseña generada, ancho fijo, saltos de línea
                      SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          readOnly: true,
                          controller: TextEditingController(text: generated),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña generada',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.copy),
                          ),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: generated));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Contraseña copiada')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Longitud:'),
                          Expanded(
                            child: Slider(
                              value: length.toDouble(),
                              min: 8,
                              max: 64,
                              divisions: 56,
                              label: '$length',
                              onChanged: (v) => setState(() {
                                length = v.round();
                                generate();
                              }),
                            ),
                          ),
                          Text('$length'),
                        ],
                      ),
                      CheckboxListTile(
                        value: useUpper,
                        onChanged: (v) => setState(() {
                          useUpper = v!;
                          generate();
                        }),
                        title: const Text('Mayúsculas'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: useNumbers,
                        onChanged: (v) => setState(() {
                          useNumbers = v!;
                          generate();
                        }),
                        title: const Text('Números'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: useSymbols,
                        onChanged: (v) => setState(() {
                          useSymbols = v!;
                          generate();
                        }),
                        title: const Text('Caracteres especiales'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Aleatorizar'),
                        onPressed: () => setState(() => generate()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    controller.text = generated;
                    Navigator.pop(context);
                  },
                  child: const Text('Usar esta contraseña'),
                ),
              ],
            );
          },
        );
      },
    );

  }

// Página de edición de contraseña
class EditPasswordPage extends StatefulWidget {
  final Map<String, dynamic> password;
  final Map<String, dynamic> webSite;
  
  const EditPasswordPage({
    super.key,
    required this.password,
    required this.webSite,
  });

  @override
  State<EditPasswordPage> createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  late TextEditingController _titleController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _urlController;
  bool _passwordVisible = false;
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.webSite['nombre_sitio']);
    _userController = TextEditingController(text: widget.password['nombre_usuario']);
    _passController = TextEditingController();
    _urlController = TextEditingController(text: widget.webSite['enlace'] ?? '');

    _loadDecryptedPassword();
  }

  Future<void> _loadDecryptedPassword() async {
    final masterKey = await EncryptionService.currentMasterKey;
    if (masterKey == null) return;
    final decrypted = await EncryptionService.decryptPassword(
      hashContrasena: widget.password['hash_contrasena'],
      ivBytes: widget.password['iv'],
      authTag: widget.password['auth_tag'],
      key: masterKey,
    );
    if (mounted) setState(() {
      _passController.text = decrypted;
    });
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final masterKey = await EncryptionService.currentMasterKey;
      if (masterKey == null) return;
      
      // 1. Actualizar sitio web
      await _supabase.from('web_sites').update({
        'nombre_sitio': _titleController.text.trim(),
        'enlace': _urlController.text.trim(),
      }).eq('id', widget.webSite['id']);
      
      // 2. Actualizar contraseña (solo si cambió)
      final newPassword = _passController.text.trim();
      if (newPassword.isNotEmpty) {
        final encrypted = await EncryptionService.encryptPassword(newPassword, masterKey);
        
        await _supabase.from('passwords').update({
          'nombre_usuario': _userController.text.trim(),
          'hash_contrasena': encrypted['hash_contrasena'],
          'iv': encrypted['iv'],
          'auth_tag': encrypted['auth_tag'],
        }).eq('id', widget.password['id']);
      }
      
      Navigator.pop(context, true); // Indica éxito
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar contraseña'),
        content: const Text('¿Estás seguro de eliminar esta contraseña permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      // 1. Eliminar contraseña
      await _supabase.from('passwords')
        .delete()
        .eq('id', widget.password['id']);
      
      // 2. Eliminar sitio web si no hay más contraseñas asociadas
      final response = await _supabase
          .from('passwords')
          .select('id')
          .eq('sitio_web_id', widget.webSite['id'])
          .count(CountOption.exact);

      final passwordsCount = response.count;

      if (passwordsCount == 0) {
        await _supabase.from('web_sites')
          .delete()
          .eq('id', widget.webSite['id']);
      }
      
      Navigator.pop(context, true); // Indica éxito
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Contraseña'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deletePassword,
            tooltip: 'Eliminar contraseña',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Introduce un título';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _userController,
                      decoration: const InputDecoration(
                        labelText: 'Correo o usuario',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Introduce usuario o correo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passController,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: Row (
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Generar contraseña segura',
                              onPressed: () async {
                                await showPasswordGeneratorDialog(context, _passController);
                              },
                            ),
                            IconButton(
                              icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                              tooltip: _passwordVisible ? 'Ocultar' : 'Mostrar',
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            )
                          ],
                        )
                      ),
                      obscureText: !_passwordVisible,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Sitio web',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Introduce la URL';
                        }
                        if (!value.contains('.')) {
                          return 'Introduce una URL válida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                          ),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
                        ),
                        ElevatedButton(
                          onPressed: _updatePassword,
                          child: const Text('Guardar Cambios'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
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
  // MÉTODO PARA AGREGAR CONTRASEÑA CON FORMULARIO VALIDADO
  Future<void> _addPassword() async {
  final user = _supabase.auth.currentUser;
  if (user == null) return;

  try {
    final masterKey = await EncryptionService.currentMasterKey;
    if (masterKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Sesión no válida')),
        );
      }
      return;
    }

    final userResponse = await _supabase
        .from('users')
        .select('id')
        .eq('auth_id', user.id)
        .single();

    final userId = userResponse['id'] as int;

    final titleController = TextEditingController();
    final userController = TextEditingController();
    final passController = TextEditingController();
    final urlController = TextEditingController();
    bool _passwordVisible = false;
    final _formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nueva contraseña'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa un título';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: userController,
                        decoration: const InputDecoration(
                          labelText: 'Correo o usuario',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa el usuario o correo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passController,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh), // Icono de generación
                                tooltip: 'Generar contraseña segura',
                                onPressed: () async {
                                  await showPasswordGeneratorDialog(context, passController);
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                                ),
                                tooltip: _passwordVisible ? 'Ocultar' : 'Mostrar',
                                onPressed: () {
                                  setState(() {
                                    _passwordVisible = !_passwordVisible;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        obscureText: !_passwordVisible,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa la contraseña';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'Sitio web',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa la URL';
                          }
                          if (!value.contains('.')) {
                            return 'Introduce una URL válida';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
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
                      final titulo = titleController.text.trim();
                      final nombreUsuario = userController.text.trim();
                      final password = passController.text.trim();
                      final enlace = urlController.text.trim();

                      // Cifrar la contraseña
                      final encrypted = await EncryptionService.encryptPassword(
                        password,
                        masterKey,
                      );

                      // Crear/actualizar sitio web
                      final webSiteResponse = await _supabase
                          .from('web_sites')
                          .upsert({
                            'usuario_id': userId,
                            'nombre_sitio': titulo,
                            'enlace': enlace,
                          }, onConflict: 'nombre_sitio,usuario_id')
                          .select('id')
                          .single();

                      final sitioWebId = webSiteResponse['id'] as int;

                      // Insertar contraseña cifrada
                      await _supabase.from('passwords').insert({
                        'sitio_web_id': sitioWebId,
                        'nombre_usuario': nombreUsuario,
                        'hash_contrasena': encrypted['hash_contrasena'],
                        'iv': encrypted['iv'],
                        'auth_tag': encrypted['auth_tag'],
                        'user_id': userId,
                      });

                      await _loadPasswords();
                      Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contraseña añadida')),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
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
        auth_tag,
        web_sites (
          id,
          nombre_sitio,
          enlace,
          logo
        )
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
      if (!mounted) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por seguridad, no se permite ver ni copiar contraseñas en web móvil.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      } else {

        await Clipboard.setData(ClipboardData(text: decrypted));
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

                      final webSite = password['web_sites'] ?? {};

                      final nombreSitio = webSite['nombre_sitio'] ?? 'Sin título';
                      final logoBytes = webSite['logo'];
                      final nombreUsuario = password['nombre_usuario']?.isNotEmpty ?? false 
                          ? password['nombre_usuario'] 
                          : 'Sin usuario';
                      
                      // Verificar integridad antes de mostrar
                      final bool isCorrupt = password['hash_contrasena'] == null || 
                                            password['iv'] == null || 
                                            password['auth_tag'] == null;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: (logoBytes != null && logoBytes.isNotEmpty)
                                      ? CircleAvatar(
                                          backgroundImage: MemoryImage(logoBytes),
                                          backgroundColor: Colors.transparent,
                                        )
                                      : const Icon(Icons.lock),
                          title: Text(nombreSitio),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Usuario: $nombreUsuario'),
                              if (isCorrupt) 
                                const Text('⚠️ Contraseña corrupta', 
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                           trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.person),
                                tooltip: 'Copiar usuario',
                                onPressed: () async {
                                  if (nombreUsuario.isNotEmpty) {
                                    await Clipboard.setData(ClipboardData(text: nombreUsuario));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Usuario copiado')),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                tooltip: 'Copiar contraseña',
                                onPressed: () {
                                  Timer.run(() => _copyToClipboard(context, password));
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditPasswordPage(
                                  password: password,
                                  webSite: webSite,
                                ),
                              ),
                            );
                            
                            if (result == true) {
                              _loadPasswords(); // Recargar lista después de editar/eliminar
                            }
                          },
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

