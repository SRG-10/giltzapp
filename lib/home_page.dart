import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:GiltzApp/encryption_service.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:gpassword/gpassword.dart';
// ignore: deprecated_member_use
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter

import 'web_utils.dart'
    if (dart.library.html) 'web_utils_web.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class NewPasswordPage extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Future<int?> Function(BuildContext) addCategoryFromDialog;

  const NewPasswordPage({
    super.key,
    required this.categories,
    required this.addCategoryFromDialog,
  });

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _urlController = TextEditingController();
  bool _passwordVisible = false;
  int? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  validator: (value) => value == null || value.isEmpty ? 'Introduce un título' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _userController,
                  decoration: const InputDecoration(
                    labelText: 'Correo o usuario',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Introduce usuario o correo' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
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
                        ),
                      ],
                    ),
                  ),
                  obscureText: !_passwordVisible,
                  maxLines: 1,
                  minLines: 1,
                  expands: false,
                  validator: (value) => value == null || value.isEmpty ? 'Por favor ingresa la contraseña' : null,
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
                    if (value == null || value.isEmpty) return 'Por favor ingresa la URL';
                    if (!value.contains('.')) return 'Introduce una URL válida';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text('Sin categoría'),
                    ),
                    ...widget.categories.map((cat) => DropdownMenuItem<int>(
                          value: cat['id'] as int,
                          child: Text(cat['nombre']),
                        )),
                    DropdownMenuItem<int>(
                      value: -1,
                      child: Row(
                        children: const [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 8),
                          Text('Agregar nueva categoría'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == -1) {
                      final newCatId = await widget.addCategoryFromDialog(context);
                      if (newCatId != null) {
                        setState(() {
                          selectedCategoryId = newCatId;
                        });
                      }
                    } else {
                      setState(() {
                        selectedCategoryId = value;
                      });
                    }
                  },
                  validator: (value) => null,
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
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(context, {
                            'titulo': _titleController.text.trim(),
                            'usuario': _userController.text.trim(),
                            'password': _passController.text.trim(),
                            'url': _urlController.text.trim(),
                            'categoria_id': selectedCategoryId,
                          });
                        }
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  final List<Map<String, dynamic>> categories; // <-- Nuevo parámetro
  final Future<int?> Function(BuildContext) addCategoryFromDialog; // <-- Nuevo parámetro

  
  const EditPasswordPage({
    super.key,
    required this.password,
    required this.webSite,
    required this.categories,
    required this.addCategoryFromDialog, // <-- Nuevo parámetro
  });

  @override
  State<EditPasswordPage> createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  int? selectedCategoryId; // <-- Declarar aquí
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
    selectedCategoryId = widget.webSite['categoria_id'] as int?;

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
    if (mounted) {
      setState(() {
      _passController.text = decrypted;
    });
    }
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
        'categoria_id': selectedCategoryId, // <-- aquí
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<int>(
                          value: null,
                          child: Text('Sin categoría'),
                        ),
                        ...widget.categories.map((cat) => DropdownMenuItem<int>(
                          value: cat['id'] as int,
                          child: Text(cat['nombre']),
                        )),
                        DropdownMenuItem<int>(
                          value: -1,
                          child: Row(
                            children: const [
                              Icon(Icons.add, size: 18),
                              SizedBox(width: 8),
                              Text('Agregar nueva categoría'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value == -1) {
                          final newCatId = await widget.addCategoryFromDialog(context);
                          if (newCatId != null) {
                            setState(() {
                              selectedCategoryId = newCatId;
                            });
                          }
                        } else {
                          setState(() {
                            selectedCategoryId = value;
                          });
                        }
                      },
                      validator: (value) => null,
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
  int? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';


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
    _searchController.dispose();
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

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
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

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewPasswordPage(
          categories: _categories,
          addCategoryFromDialog: _addCategoryFromDialog,
        ),
      ),
    );

    if (result != null)
    {
      final userResponse = await _supabase
              .from('users')
              .select('id')
              .eq('auth_id', user.id)
              .single();
      final userId = userResponse['id'] as int;

      final titulo = result['titulo'] as String;
      final nombreUsuario = result['usuario'] as String;
      final password = result['password'] as String;
      final enlace = result['url'] as String;
      final categoriaId = result['categoria_id'] as int?;

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
            'categoria_id': categoriaId,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña añadida')),
        );
      }

    }

  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}


Future<int?> _addCategoryFromDialog(BuildContext context) async {
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
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final userResponse = await _supabase
        .from('users')
        .select('id')
        .eq('auth_id', user.id)
        .single();
    final userId = userResponse['id'] as int;
    final insertResponse = await _supabase.from('categories').insert({
      'usuario_id': userId,
      'nombre': result,
    }).select('id').single();
    await _loadCategories();
    return insertResponse['id'] as int?;
  }
  return null;
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
          logo,
          categoria_id
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
      //final isMobile = isMobileWeb();
      
      if (isMobileWeb()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por seguridad, no se permite ver ni copiar contraseñas en web móvil.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por seguridad, no se permite ver ni copiar contraseñas en web, use la extensión.'),
            duration: Duration(seconds: 4),
          ),
        );
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


  
String _getCategoryName(int? categoryId) {
  if (categoryId == null) return 'Todas';
  final category = _categories.firstWhere(
    (c) => c['id'] == categoryId,
    orElse: () => {'nombre': 'Desconocida'},
  );
  return category['nombre'] ?? 'Sin nombre';
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

    // Filtra las contraseñas por categoría seleccionada
    final filteredPasswords = _passwords.where((p) {
      final webSite = p['web_sites'] as Map<String, dynamic>?;
      final categoriaId = webSite?['categoria_id'] as int?;

      // Filtrar por categoría si está seleccionada
      if (_selectedCategoryId != null && categoriaId != _selectedCategoryId) {
        return false;
      }

      // Si no hay texto de búsqueda, mostrar todo
      if (_searchText.isEmpty) return true;

      // Campos a buscar
      final titulo = (webSite?['nombre_sitio'] ?? '').toString().toLowerCase();
      final usuario = (p['nombre_usuario'] ?? '').toString().toLowerCase();
      final enlace = (webSite?['enlace'] ?? '').toString().toLowerCase();

      // Buscar si el texto está en alguno de los campos
      return titulo.contains(_searchText) ||
            usuario.contains(_searchText) ||
            enlace.contains(_searchText);
    }).toList();


    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _redirectToLogin();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icon.png',
                height: 32, // Ajusta el tamaño según tu logo
              ),
              const SizedBox(width: 12),
              const Text(''),
            ],
          ),
          centerTitle: true, // Centra el contenido en la AppBar
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
                leading: const Icon(Icons.all_inbox),
                title: const Text('Todas las categorías'),
                selected: _selectedCategoryId == null,
                onTap: () {
                  setState(() {
                    _selectedCategoryId = null;
                    Navigator.pop(context);
                  });
                },

              ),
              ExpansionTile(
                leading: const Icon(Icons.folder),
                title: const Text('Categorías'),
                childrenPadding: const EdgeInsets.only(left: 32),
                children: _categories.isEmpty
                    ? [
                        const ListTile(
                          title: Text('No hay categorías'),
                          enabled: false,
                        )
                      ]
                    : _categories.map((cat) => ListTile(
                          leading: const Icon(Icons.label_outline),
                          title: Text(cat['nombre'] ?? ''),
                          selected: _selectedCategoryId == cat['id'],
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = cat['id'];
                              Navigator.pop(context);
                            });
                          },
                        )).toList(),
              ),
                ListTile(
                  leading: const Icon(Icons.vpn_key),
                  title: const Text('Agregar contraseña'),
                  onTap: _addPassword, // Botón global
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Agregar categoría'),
                onTap: _addCategory,
              ),
             ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar perfil'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                  if (result == true) {
                    await _loadUsername(); // Vuelve a cargar el nombre de usuario actualizado
                    setState(() {}); // Fuerza el rebuild si es necesario
                  }
                },

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
             Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar por título, usuario o sitio web',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
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
              // Botón contextual solo cuando hay categoría seleccionada
              if (_selectedCategoryId != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Categoría: ${_getCategoryName(_selectedCategoryId)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar contraseña'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: () => _addPasswordForCategory(_selectedCategoryId!),
                        ),
                      ],
                    ),
                  ),
            Expanded(
              child: _passwords.isEmpty
                  ? const Center(child: Text('No hay contraseñas guardadas'))
                  :ListView.builder(
                    itemCount: filteredPasswords.length,
                    itemBuilder: (context, index) {
                      final password = filteredPasswords[index];

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
                                  categories: _categories,
                                  addCategoryFromDialog: _addCategoryFromDialog,
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
      ),
    );
  }

  Future<void> _addPasswordForCategory(int categoriaId) async {
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
      bool passwordVisible = false;
      final formKey = GlobalKey<FormState>();

      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Nueva contraseña'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
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
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Generar contraseña segura',
                                  onPressed: () async {
                                    await showPasswordGeneratorDialog(context, passController);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    passwordVisible ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  tooltip: passwordVisible ? 'Ocultar' : 'Mostrar',
                                  onPressed: () {
                                    setState(() {
                                      passwordVisible = !passwordVisible;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          obscureText: !passwordVisible,
                          maxLines: 1,
                          minLines: 1,
                          expands: false,
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
                        // NO incluyas el selector de categoría aquí
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
                      if (formKey.currentState!.validate()) {
                        final titulo = titleController.text.trim();
                        final nombreUsuario = userController.text.trim();
                        final password = passController.text.trim();
                        final enlace = urlController.text.trim();

                        // Cifrar la contraseña
                        final encrypted = await EncryptionService.encryptPassword(
                          password,
                          masterKey,
                        );

                        // Crear/actualizar sitio web con la categoría seleccionada
                        final webSiteResponse = await _supabase
                            .from('web_sites')
                            .upsert({
                              'usuario_id': userId,
                              'nombre_sitio': titulo,
                              'enlace': enlace,
                              'categoria_id': categoriaId, // <-- Aquí se asocia la categoría
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

  
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _currentPassVisible = false;
  bool _newPassVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPassController,
                obscureText: !_currentPassVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_currentPassVisible 
                      ? Icons.visibility_off 
                      : Icons.visibility),
                    onPressed: () => setState(() => _currentPassVisible = !_currentPassVisible),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa tu contraseña actual';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPassController,
                obscureText: !_newPassVisible,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_newPassVisible 
                      ? Icons.visibility_off 
                      : Icons.visibility),
                    onPressed: () => setState(() => _newPassVisible = !_newPassVisible),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa una nueva contraseña';
                  if (value.length < 12) return 'Mínimo 12 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (value) {
                  if (value != _newPassController.text) return 'Las contraseñas no coinciden';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Actualizar contraseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Reautenticar con contraseña actual
      await supabase.auth.signInWithPassword(
        email: user.email!,
        password: _currentPassController.text,
      );

      // 2. Actualizar contraseña en Supabase Auth
      await supabase.auth.updateUser(
        UserAttributes(password: _newPassController.text),
      );

      // 3. Actualizar clave maestra de cifrado
      final userResponse = await supabase
          .from('users')
          .select('id, salt')
          .eq('auth_id', user.id)
          .single();
      
      final newSalt = EncryptionService.generateSecureSalt();
      final newMasterKey = await EncryptionService.deriveMasterKey(
        _newPassController.text,
        newSalt,
      );

      // 4. Actualizar salt en base de datos
      await supabase.from('users').update({
        'salt': base64Encode(newSalt),
      }).eq('id', userResponse['id']);

      // 5. Migrar contraseñas a nueva clave
      await _migratePasswords(
        userId: userResponse['id'] as int,
        newKey: newMasterKey,
      );

      // 6. Actualizar clave en memoria
      await EncryptionService.initialize(newMasterKey);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _migratePasswords({
    required int userId,
    required encrypt.Key newKey,
  }) async {
    final supabase = Supabase.instance.client;
    final masterKey = await EncryptionService.currentMasterKey;
    if (masterKey == null) return;

    final passwords = await supabase
        .from('passwords')
        .select()
        .eq('user_id', userId);

    for (final pwd in passwords) {
      final decrypted = await EncryptionService.decryptPassword(
        hashContrasena: pwd['hash_contrasena'],
        ivBytes: pwd['iv'],
        authTag: pwd['auth_tag'],
        key: masterKey,
      );

      final encrypted = await EncryptionService.encryptPassword(decrypted, newKey);

      await supabase.from('passwords').update({
        'hash_contrasena': encrypted['hash_contrasena'],
        'iv': encrypted['iv'],
        'auth_tag': encrypted['auth_tag'],
      }).eq('id', pwd['id']);
    }
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _currentPassVisible = false;
  bool _newPassVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _passwordChanged = false;
  bool get _minLength => _newPassController.text.length >= 12;
  bool get _hasUpper => _newPassController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLower => _newPassController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _newPassController.text.contains(RegExp(r'\d'));
  bool get _hasSpecial => _newPassController.text.contains(RegExp(r'''[ªº\\!"|@·#$~%€&¬/()=?'¡¿`^[\]*+´{}\-\_\.\:\,\;\<\>"]'''));

  Widget _buildPasswordRequirements() {
    if (_newPassController.text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
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

  Widget _buildRequirementRow(String text, bool met) {
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


  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _emailController.text = user.email ?? '';
      });
      
      final response = await Supabase.instance.client
          .from('users')
          .select('nombre_usuario')
          .eq('auth_id', user.id)
          .single();
      
      if (mounted) {
        setState(() {
          _usernameController.text = response['nombre_usuario'] ?? '';
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final newemail = _emailController.text.trim();
      if (user == null) return;

      // 1. Actualizar email en Supabase Auth
      await supabase.auth.updateUser(
        UserAttributes(email: newemail),
      );

      // Actualizar nombre de usuario
      await supabase.from('users').update({
        'nombre_usuario': _usernameController.text.trim()
      }).eq('auth_id', user.id);

      // Actualizar contraseña si se proporcionó
      if (_newPassController.text.isNotEmpty) {
        // Reautenticación
        await supabase.auth.signInWithPassword(
          email: user.email!,
          password: _currentPassController.text,
        );

        // Actualizar contraseña
        await supabase.auth.updateUser(
          UserAttributes(password: _newPassController.text),
        );

        // Actualizar clave maestra
        final newSalt = EncryptionService.generateSecureSalt();
        final newMasterKey = await EncryptionService.deriveMasterKey(
          _newPassController.text,
          newSalt,
        );
        
        await supabase.from('users').update({
          'salt': base64Encode(newSalt),
        }).eq('auth_id', user.id);

        final userResponse = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', user.id)
          .single();
        final userId = userResponse['id'] as int; // <- userId disponible
        
        await _migratePasswords(
          userId: userId,  // Añade este parámetro
          newKey: newMasterKey,
        );
        await EncryptionService.initialize(newMasterKey);
        _passwordChanged = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _migratePasswords({
    required int userId,
    required encrypt.Key newKey,
  }) async {
    final supabase = Supabase.instance.client;
    final masterKey = await EncryptionService.currentMasterKey;
    if (masterKey == null) return;

    final passwords = await supabase
        .from('passwords')
        .select()
        .eq('user_id', userId);

    for (final pwd in passwords) {
      final decrypted = await EncryptionService.decryptPassword(
        hashContrasena: pwd['hash_contrasena'],
        ivBytes: pwd['iv'],
        authTag: pwd['auth_tag'],
        key: masterKey,
      );

      final encrypted = await EncryptionService.encryptPassword(decrypted, newKey);

      await supabase.from('passwords').update({
        'hash_contrasena': encrypted['hash_contrasena'],
        'iv': encrypted['iv'],
        'auth_tag': encrypted['auth_tag'],
      }).eq('id', pwd['id']);
    }
  }
  
  // ... (métodos _migratePasswords y dispose similares a ChangePasswordPage)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un nombre de usuario';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentPassController,
                obscureText: !_currentPassVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_currentPassVisible 
                      ? Icons.visibility_off 
                      : Icons.visibility),
                    onPressed: () => setState(() => _currentPassVisible = !_currentPassVisible),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPassController,
                obscureText: !_newPassVisible,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_newPassVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _newPassVisible = !_newPassVisible),
                  ),
                ),
                onChanged: (_) => setState(() {}), // Para refrescar los requisitos en tiempo real
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!_minLength) return 'Mínimo 12 caracteres';
                    if (!_hasUpper) return 'Al menos una mayúscula';
                    if (!_hasLower) return 'Al menos una minúscula';
                    if (!_hasDigit) return 'Al menos un número';
                    if (!_hasSpecial) return 'Al menos un carácter especial';
                  }
                  return null;
                },
              ),
              if (_newPassController.text.isNotEmpty) _buildPasswordRequirements(),

              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (value) {
                  if (_newPassController.text.isNotEmpty && value != _newPassController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },

              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
