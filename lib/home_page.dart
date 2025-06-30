import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:GiltzApp/encryption_service.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:gpassword/gpassword.dart';
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_utils.dart'
    if (dart.library.html) 'web_utils_web.dart';


class PaginaInicio extends StatefulWidget {
  const PaginaInicio({super.key});

  @override
  State<PaginaInicio> createState() => _PaginaInicioState();
}

class PaginaNuevaPassword extends StatefulWidget {
  final List<Map<String, dynamic>> Function() obtenerCategorias;
  final Future<int?> Function(BuildContext) agregarCategoriasDialogo;

  const PaginaNuevaPassword({
    super.key,
    required this.obtenerCategorias,
    required this.agregarCategoriasDialogo,
  });

  @override
  State<PaginaNuevaPassword> createState() => _PaginaNuevaPasswordState();
}

class _PaginaNuevaPasswordState extends State<PaginaNuevaPassword> {
  final keyFormulario = GlobalKey<FormState>();
  final tituloController = TextEditingController();
  final usuarioController = TextEditingController();
  final passController = TextEditingController();
  final urlController = TextEditingController();
  bool passwordVisible = false;
  int? categoriaIdSeleccionada;

  @override
  Widget build(BuildContext context) {
    final categoriaActual = widget.obtenerCategorias();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: keyFormulario,
            child: Column(
              children: [
                TextFormField(
                  controller: tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Introduce un título' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: usuarioController,
                  decoration: const InputDecoration(
                    labelText: 'Correo o usuario',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Introduce usuario o correo' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passController,
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
                            await mostrarDialogoGeneradorPasswords(context, passController);
                          },
                        ),
                        IconButton(
                          icon: Icon(passwordVisible ? Icons.visibility_off : Icons.visibility),
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
                  validator: (value) => value == null || value.isEmpty ? 'Por favor ingresa la contraseña' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: urlController,
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
                  value: categoriaIdSeleccionada,
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
                    ...categoriaActual.map((cat) => DropdownMenuItem<int>(
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
                      // Llama al diálogo para crear categoría
                      final newCatId = await widget.agregarCategoriasDialogo(context);
                      if (newCatId != null) {
                        setState(() {
                          categoriaIdSeleccionada = newCatId;
                        });
                      }
                    } else {
                      setState(() {
                        categoriaIdSeleccionada = value;
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
                        if (keyFormulario.currentState!.validate()) {
                          Navigator.pop(context, {
                            'titulo': tituloController.text.trim(),
                            'usuario': usuarioController.text.trim(),
                            'password': passController.text.trim(),
                            'url': urlController.text.trim(),
                            'categoria_id': categoriaIdSeleccionada,
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

Future<void> mostrarDialogoGeneradorPasswords(BuildContext contexto, TextEditingController controller) async {
  int longitud = 16;
  bool usarMayus = true;
  bool usarNums = true;
  bool usarSimbolos = true;
  String generado = '';

  final gpassword = GPassword();

  void generate() {
    // Si todas están desmarcadas, solo minúsculas
    if (!usarMayus && !usarNums && !usarSimbolos) {
      generado = gpassword.generate(
        passwordLength: longitud,
        includeUppercase: false,
        includeLowercase: true,
        includeNumbers: false,
        includeSymbols: false,
      );
    } else {
      generado = gpassword.generate(
        passwordLength: longitud,
        includeUppercase: usarMayus,
        includeLowercase: true, // SIEMPRE minúsculas
        includeNumbers: usarNums,
        includeSymbols: usarSimbolos,
      );
    }
  }

    generate(); // Genera una inicial

    await showDialog(
      context: contexto,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final anchoPantalla = MediaQuery.of(context).size.width;
            final esMovil = anchoPantalla < 700;
            final anchoDialogo = esMovil ? anchoPantalla * 0.98 : 500.0;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
              title: const Text('Generar contraseña segura'),
              content: Container(
                width: anchoDialogo,
                constraints: const BoxConstraints(
                  minWidth: 280,
                  maxWidth: 600,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          readOnly: true,
                          controller: TextEditingController(text: generado),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña generada',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.copy),
                          ),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: generado));
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
                              value: longitud.toDouble(),
                              min: 8,
                              max: 64,
                              divisions: 56,
                              label: '$longitud',
                              onChanged: (v) => setState(() {
                                longitud = v.round();
                                generate();
                              }),
                            ),
                          ),
                          Text('$longitud'),
                        ],
                      ),
                      CheckboxListTile(
                        value: usarMayus,
                        onChanged: (v) => setState(() {
                          usarMayus = v!;
                          generate();
                        }),
                        title: const Text('Mayúsculas'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: usarNums,
                        onChanged: (v) => setState(() {
                          usarNums = v!;
                          generate();
                        }),
                        title: const Text('Números'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: usarSimbolos,
                        onChanged: (v) => setState(() {
                          usarSimbolos = v!;
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
                    controller.text = generado;
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

class PaginaEditarPassword extends StatefulWidget {
  final Map<String, dynamic> password;
  final Map<String, dynamic> sitioWeb;
  final List<Map<String, dynamic>> Function() obtenerCategorias; 
  final Future<int?> Function(BuildContext) agregarCategoriaDialogo; 
   
  const PaginaEditarPassword({
    super.key,
    required this.password,
    required this.sitioWeb,
    required this.obtenerCategorias,
    required this.agregarCategoriaDialogo, 
  });

  @override
  State<PaginaEditarPassword> createState() => _PaginaEditarPasswordState();
}

class _PaginaEditarPasswordState extends State<PaginaEditarPassword> {
  int? idCategoriaSeleccionada;
  late TextEditingController tituloController;
  late TextEditingController usuarioController;
  late TextEditingController passController;
  late TextEditingController urlController;
  bool passwordVisible = false;
  final keyFormulario = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool estaCargando = false;

  @override
  void initState() {
    super.initState();
    tituloController = TextEditingController(text: widget.sitioWeb['nombre_sitio']);
    usuarioController = TextEditingController(text: widget.password['nombre_usuario']);
    passController = TextEditingController();
    urlController = TextEditingController(text: widget.sitioWeb['enlace'] ?? '');
    idCategoriaSeleccionada = widget.sitioWeb['categoria_id'] as int?;

    cargarPasswordDescifrada();
  }

  Future<void> cargarPasswordDescifrada() async {
    final masterKey = await EncryptionService.masterKeyActual;
    if (masterKey == null) return;
    final descifrada = await EncryptionService.descifrarPassword(
      hashContrasena: widget.password['hash_contrasena'],
      ivBytes: widget.password['iv'],
      authTag: widget.password['auth_tag'],
      key: masterKey,
    );
    if (mounted) {
      setState(() {
      passController.text = descifrada;
    });
    }
  }

  Future<void> actualizarPassword() async {
    if (!keyFormulario.currentState!.validate()) return;
    
    setState(() => estaCargando = true);
    
    try {
      final masterKey = await EncryptionService.masterKeyActual;
      if (masterKey == null) return;
      
      // 1. Actualizar sitio web
      await supabase.from('web_sites').update({
        'nombre_sitio': tituloController.text.trim(),
        'enlace': urlController.text.trim(),
        'categoria_id': idCategoriaSeleccionada, 
      }).eq('id', widget.sitioWeb['id']);
      
      // 2. Actualizar contraseña (solo si cambió)
      final nuevaPassword = passController.text.trim();
      if (nuevaPassword.isNotEmpty) {
        final cifrado = await EncryptionService.cifrarPassword(nuevaPassword, masterKey);
        
        await supabase.from('passwords').update({
          'nombre_usuario': usuarioController.text.trim(),
          'hash_contrasena': cifrado['hash_contrasena'],
          'iv': cifrado['iv'],
          'auth_tag': cifrado['auth_tag'],
        }).eq('id', widget.password['id']);
      }
      
      Navigator.pop(context, true); // Indica éxito
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => estaCargando = false);
    }
  }

  Future<void> eliminarPassword() async {
    final confirmado = await showDialog<bool>(
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

    if (confirmado != true) return;
    
    setState(() => estaCargando = true);
    
    try {
      // 1. Eliminar contraseña
      await supabase.from('passwords')
        .delete()
        .eq('id', widget.password['id']);
      
      // 2. Eliminar sitio web si no hay más contraseñas asociadas
      final respuesta = await supabase
          .from('passwords')
          .select('id')
          .eq('sitio_web_id', widget.sitioWeb['id'])
          .count(CountOption.exact);

      final passwordsCount = respuesta.count;

      if (passwordsCount == 0) {
        await supabase.from('web_sites')
          .delete()
          .eq('id', widget.sitioWeb['id']);
      }
      
      Navigator.pop(context, true); // Indica éxito
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => estaCargando = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final categoriasActuales = widget.obtenerCategorias();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Contraseña'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: eliminarPassword,
            tooltip: 'Eliminar contraseña',
          ),
        ],
      ),
      body: estaCargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: keyFormulario,
                child: Column(
                  children: [
                    TextFormField(
                      controller: tituloController,
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
                      controller: usuarioController,
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
                      controller: passController,
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
                                await mostrarDialogoGeneradorPasswords(context, passController);
                              },
                            ),
                            IconButton(
                              icon: Icon(passwordVisible ? Icons.visibility_off : Icons.visibility),
                              tooltip: passwordVisible ? 'Ocultar' : 'Mostrar',
                              onPressed: () {
                                setState(() {
                                  passwordVisible = !passwordVisible;
                                });
                              },
                            )
                          ],
                        )
                      ),
                      obscureText: !passwordVisible,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: urlController,
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
                  value: idCategoriaSeleccionada,
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
                    ...categoriasActuales.map((cat) => DropdownMenuItem<int>(
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
                      // Llama al diálogo para crear categoría
                      final newCatId = await widget.agregarCategoriaDialogo(context);
                      if (newCatId != null) {
                        setState(() {
                          idCategoriaSeleccionada = newCatId;
                        });
                      }
                    } else {
                      setState(() {
                        idCategoriaSeleccionada = value;
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
                          onPressed: actualizarPassword,
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

class _PaginaInicioState extends State<PaginaInicio> {

  // Variables de estado
  bool portapapelesActivo = false;
  final int portapapelesSegundos = 10;
  Timer? portapapelesTemporizador;
  int segundosRestantes = 0;
  double get progreso => segundosRestantes / portapapelesSegundos;
  int? idCategoriaSeleccionada;
  final TextEditingController buscarController = TextEditingController();
  String textoBusqueda = '';

  final supabase = Supabase.instance.client;
  String? nombreUsuario;
  bool estaCargando = true;
  List<Map<String, dynamic>> passwords = [];
  List<Map<String, dynamic>> categorias = [];
  // Métodos de control
  void empezarCuentaPortapapeles() {
    portapapelesActivo = true;
    segundosRestantes = portapapelesSegundos;
    portapapelesTemporizador?.cancel();
    portapapelesTemporizador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (segundosRestantes > 0 && mounted) {
        setState(() => segundosRestantes--);
      } else {
        limpiarPortapapeles();
        timer.cancel();
      }
    });
  }

  void limpiarPortapapeles() async {
    portapapelesTemporizador?.cancel();
    await Clipboard.setData(const ClipboardData(text: ''));
    if (mounted) {
      setState(() {
        portapapelesActivo = false;
        segundosRestantes = 0;
      });
    }
  }

  @override
  void dispose() {
    portapapelesTemporizador?.cancel();
    buscarController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    verificarSesion();

    buscarController.addListener(() {
      setState(() {
        textoBusqueda = buscarController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> agregarCategoria() async {
    final usuario = supabase.auth.currentUser;
    if (usuario == null) return;

    final respuestaUsuario = await supabase
        .from('users')
        .select('id')
        .eq('auth_id', usuario.id)
        .single();
    final idUsuario = respuestaUsuario['id'] as int;

    final controller = TextEditingController();
    final resultado = await showDialog<String>(
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

    if (resultado != null && resultado.isNotEmpty) {
      await supabase.from('categories').insert({
        'usuario_id': idUsuario,
        'nombre': resultado,
      });
      await cargarCategorias();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoría añadida')),
      );
    }
  }

  // MÉTODO PARA AGREGAR CONTRASEÑA CON FORMULARIO VALIDADO
  Future<void> agregarPassword() async {
    final usuario = supabase.auth.currentUser;
    if (usuario == null) return;

    try {
      final masterKey = await EncryptionService.masterKeyActual;
      if (masterKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Sesión no válida')),
          );
        }
        return;
      }

      final resultado = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaginaNuevaPassword(
            obtenerCategorias: () => categorias, // Función que devuelve la lista ACTUALIZADA
            agregarCategoriasDialogo: agregarCategoriaDialogo,
          ),
        ),
      );

      if (resultado != null)
      {
        final respuestaUsuario = await supabase
                .from('users')
                .select('id')
                .eq('auth_id', usuario.id)
                .single();
        final idUsuario = respuestaUsuario['id'] as int;

        final titulo = resultado['titulo'] as String;
        final nombreUsuario = resultado['usuario'] as String;
        final password = resultado['password'] as String;
        final enlace = resultado['url'] as String;
        final categoriaId = resultado['categoria_id'] as int?;

        // Cifrar la contraseña
        final cifrada = await EncryptionService.cifrarPassword(
          password,
          masterKey,
        );

        // Crear/actualizar sitio web
        final respuestaWeb = await supabase
            .from('web_sites')
            .upsert({
              'usuario_id': idUsuario,
              'nombre_sitio': titulo,
              'enlace': enlace,
              'categoria_id': categoriaId,
            }, onConflict: 'nombre_sitio,usuario_id')
            .select('id')
            .single();

        final sitioWebId = respuestaWeb['id'] as int;

        // Insertar contraseña cifrada
        await supabase.from('passwords').insert({
          'sitio_web_id': sitioWebId,
          'nombre_usuario': nombreUsuario,
          'hash_contrasena': cifrada['hash_contrasena'],
          'iv': cifrada['iv'],
          'auth_tag': cifrada['auth_tag'],
          'user_id': idUsuario,
        });

        await cargarPasswords();
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

  Future<int?> agregarCategoriaDialogo(BuildContext context) async {
    final controller = TextEditingController();
    final resultado = await showDialog<String>(
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
    if (resultado != null && resultado.isNotEmpty) {
      final usuario = supabase.auth.currentUser;
      if (usuario == null) return null;
      final respuestaUsuario = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', usuario.id)
          .single();
      final idUsuario = respuestaUsuario['id'] as int;
      final respuestaInsert = await supabase.from('categories').insert({
        'usuario_id': idUsuario,
        'nombre': resultado,
      }).select('id').single();
      await cargarCategorias();
      return respuestaInsert['id'] as int?;
    }
    return null;
  }

  Future<void> verificarSesion() async {
    if (!mounted) return;
    
    final usuario = supabase.auth.currentUser;
    if (usuario == null) {
      redirigirLogin();
      return;
    }

    try {
      final masterKey = await EncryptionService.masterKeyActual;
      if (masterKey == null || !mounted) {
        redirigirLogin();
        return;
      }
      
      await Future.wait([cargarNombreUsuario(), cargarPasswords(), cargarCategorias()]);
    } catch (e) {
      if (mounted) redirigirLogin();
    }
  }

  Future<void> cargarNombreUsuario() async {
    final usuario = supabase.auth.currentUser;
    if (usuario == null) return;
    try {
      final respuesta = await supabase
          .from('users')
          .select('nombre_usuario, id')
          .eq('auth_id', usuario.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          nombreUsuario = respuesta?['nombre_usuario'] ?? usuario.email;
          estaCargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => estaCargando = false);
        redirigirLogin();
      }
    }
  }

  Future<void> cargarCategorias() async {
    final usuario = supabase.auth.currentUser;
    if (usuario == null) return;
    try {
      // Obtener el id bigint del usuario
      final respuestaUsuario = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', usuario.id)
          .single();
      final idUsuario = respuestaUsuario['id'] as int;

      final respuesta = await supabase
          .from('categories')
          .select('id, nombre')
          .eq('usuario_id', idUsuario);

      if (mounted) {
        setState(() {
          categorias = List<Map<String, dynamic>>.from(respuesta);
        });
      }
    } catch (e) {
      //
    }
  }

  Future<void> cargarPasswords() async {
    final usuario = supabase.auth.currentUser;
    if (usuario == null) {
      if (mounted) setState(() => estaCargando = false);
      return;
    }
    try {
      final respuestaUsuario = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', usuario.id)
          .single();
      final idUsuario = respuestaUsuario['id'] as int;

      final respuesta = await supabase
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
      .eq('user_id', idUsuario);


      if (mounted) {
        setState(() {
          passwords = List<Map<String, dynamic>>.from(respuesta);
          estaCargando = false;

        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => estaCargando = false); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando contraseñas: ${e.toString()}')),
        );
      }
    }
  }

  void redirigirLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> cerrarSesion() async {
    try {
      await supabase.auth.signOut();
      await EncryptionService.limpiar();
      redirigirLogin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
      );
    }
  }

  void copiarPortapapeles(BuildContext context, Map<String, dynamic> password) async {
    try {
      if (password['hash_contrasena'] == null || 
          password['iv'] == null || 
          password['auth_tag'] == null) {
        throw Exception('Datos cifrados incompletos');
      }

      final masterKey = await EncryptionService.masterKeyActual;
      if (masterKey == null || !mounted) return;

      final descifrado = await EncryptionService.descifrarPassword(
        hashContrasena: password['hash_contrasena']!,
        ivBytes: password['iv']!,
        authTag: password['auth_tag']!,
        key: masterKey,
      );

      if (descifrado.isEmpty) throw Exception('Texto a copiar vacío');

      if (kIsWeb) {

        
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
              content: Text('Por seguridad, no se permite ver ni copiar contraseñas en web.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        await Clipboard.setData(ClipboardData(text: descifrado));
        empezarCuentaPortapapeles();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contraseña copiada (válida por $portapapelesSegundos segundos)'),
            duration: Duration(seconds: portapapelesSegundos),
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

  String obtenerNombreCategoria(int? idCategoria) {
    if (idCategoria == null) return 'Todas';
    final categoria = categorias.firstWhere(
      (c) => c['id'] == idCategoria,
      orElse: () => {'nombre': 'Desconocida'},
    );
    return categoria['nombre'] ?? 'Sin nombre';
  }

  @override
  Widget build(BuildContext context) {
    final usuarioBuild = supabase.auth.currentUser;
    if (usuarioBuild == null) {
      Future.microtask(() => redirigirLogin());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (estaCargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Filtra las contraseñas por categoría seleccionada
    final passwordsFiltradas = passwords.where((p) {
      final sitioWeb = p['web_sites'] as Map<String, dynamic>?;
      final idCategoria = sitioWeb?['categoria_id'] as int?;

      // Filtrar por categoría si está seleccionada
      if (idCategoriaSeleccionada != null && idCategoria != idCategoriaSeleccionada) {
        return false;
      }

      // Si no hay texto de búsqueda, mostrar todo
      if (textoBusqueda.isEmpty) return true;

      // Campos a buscar
      final titulo = (sitioWeb?['nombre_sitio'] ?? '').toString().toLowerCase();
      final usuario = (p['nombre_usuario'] ?? '').toString().toLowerCase();
      final enlace = (sitioWeb?['enlace'] ?? '').toString().toLowerCase();

      // Buscar si el texto está en alguno de los campos
      return titulo.contains(textoBusqueda) ||
            usuario.contains(textoBusqueda) ||
            enlace.contains(textoBusqueda);
    }).toList();


    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) redirigirLogin();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icon.png',
                height: 32, 
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
                      Text(
                        this.nombreUsuario ?? 'Usuario',
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
                selected: idCategoriaSeleccionada == null,
                onTap: () {
                  setState(() {
                    idCategoriaSeleccionada = null;
                    Navigator.pop(context);
                  });
                },

              ),
                ExpansionTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Categorías'),
                  childrenPadding: const EdgeInsets.only(left: 32),
                  children: categorias.isEmpty
                      ? [
                          const ListTile(
                            title: Text('No hay categorías'),
                            enabled: false,
                          )
                        ]
                      : categorias.map((cat) => ListTile(
                            leading: const Icon(Icons.label_outline),
                            title: Text(cat['nombre'] ?? ''),
                            selected: idCategoriaSeleccionada == cat['id'],
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Eliminar categoría',
                              onPressed: () => eliminarCategoria(cat['id'] as int, cat['nombre']),
                            ),
                            onTap: () {
                              setState(() {
                                idCategoriaSeleccionada = cat['id'];
                                Navigator.pop(context);
                              });
                            },
                          )).toList(),
                ),

                ListTile(
                  leading: const Icon(Icons.vpn_key),
                  title: const Text('Agregar contraseña'),
                  onTap: agregarPassword, // Botón global
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Agregar categoría'),
                onTap: agregarCategoria,
              ),
             ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Editar perfil'),
                onTap: () async {
                  Navigator.pop(context);
                  final resultado = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaginaEditarPerfil()),
                  );
                  if (resultado == true) {
                    await cargarNombreUsuario(); // Vuelve a cargar el nombre de usuario actualizado
                    await cargarPasswords();
                    setState(() {}); // Fuerza el rebuild si es necesario
                  }
                },

              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Cerrar sesión'),
                onTap: cerrarSesion,
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Le damos la bienvenida, $nombreUsuario!',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
             Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: buscarController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar por título, usuario o sitio web',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: textoBusqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            buscarController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
            if (portapapelesActivo)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: progreso,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tiempo restante: $segundosRestantes segundos',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Botón contextual solo cuando hay categoría seleccionada
              if (idCategoriaSeleccionada != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Categoría: ${obtenerNombreCategoria(idCategoriaSeleccionada)}',
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
                          onPressed: () => agregarPasswordCategoria(idCategoriaSeleccionada!),
                        ),
                      ],
                    ),
                  ),
            Expanded(
              child: passwords.isEmpty
                  ? const Center(child: Text('No hay contraseñas guardadas'))
                  :ListView.builder(
                    itemCount: passwordsFiltradas.length,
                    itemBuilder: (context, index) {
                      final password = passwordsFiltradas[index];

                      final sitioWeb = password['web_sites'] ?? {};

                      final nombreSitio = sitioWeb['nombre_sitio'] ?? 'Sin título';
                      final logoBytes = sitioWeb['logo'];
                      final nombreUsuario = password['nombre_usuario']?.isNotEmpty ?? false 
                          ? password['nombre_usuario'] 
                          : 'Sin usuario';
                      
                      // Verificar integridad antes de mostrar
                      final bool esCorrupto = password['hash_contrasena'] == null || 
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
                              if (esCorrupto) 
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
                                  Timer.run(() => copiarPortapapeles(context, password));
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            final resultado = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaginaEditarPassword(
                                  password: password,
                                  sitioWeb: sitioWeb,
                                  obtenerCategorias: () => categorias,
                                  agregarCategoriaDialogo: agregarCategoriaDialogo,
                                ),
                              ),
                            );
                            
                            if (resultado == true) {
                              cargarPasswords(); // Recargar lista después de editar/eliminar
                            }
                          },
                        ),
                      );
                    },
                  )
            ),
            LinearProgressIndicator(
              value: progreso,
              minHeight: 3,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            )
          ],
        ),
      ),
    );
  }

  Future<void> agregarPasswordCategoria(int categoriaId) async {
    final usuario = supabase.auth.currentUser;
    if (usuario == null) return;

    try {
      final masterKey = await EncryptionService.masterKeyActual;
      if (masterKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Sesión no válida')),
          );
        }
        return;
      }

      final respuestausuario = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', usuario.id)
          .single();

      final idUsuario = respuestausuario['id'] as int;

      final tituloController = TextEditingController();
      final usuarioController = TextEditingController();
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
                          controller: tituloController,
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
                          controller: usuarioController,
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
                                    await mostrarDialogoGeneradorPasswords(context, passController);
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
                        final titulo = tituloController.text.trim();
                        final nombreUsuario = usuarioController.text.trim();
                        final password = passController.text.trim();
                        final enlace = urlController.text.trim();

                        // Cifrar la contraseña
                        final cifrado = await EncryptionService.cifrarPassword(
                          password,
                          masterKey,
                        );

                        // Crear/actualizar sitio web con la categoría seleccionada
                        final respuestaWeb = await supabase
                            .from('web_sites')
                            .upsert({
                              'usuario_id': idUsuario,
                              'nombre_sitio': titulo,
                              'enlace': enlace,
                              'categoria_id': categoriaId, 
                            }, onConflict: 'nombre_sitio,usuario_id')
                            .select('id')
                            .single();

                        final sitioWebId = respuestaWeb['id'] as int;

                        // Insertar contraseña cifrada
                        await supabase.from('passwords').insert({
                          'sitio_web_id': sitioWebId,
                          'nombre_usuario': nombreUsuario,
                          'hash_contrasena': cifrado['hash_contrasena'],
                          'iv': cifrado['iv'],
                          'auth_tag': cifrado['auth_tag'],
                          'user_id': idUsuario,
                        });

                        await cargarPasswords();
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
  
  Future<void> eliminarCategoria(int categoryId, String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Seguro que quieres eliminar la categoría "$nombre"? Las contraseñas asociadas quedarán sin categoría.'),
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
    if (confirmado != true) return;

    try {
      // 1. Quitar la categoría de todos los sitios web asociados
      await supabase
        .from('web_sites')
        .update({'categoria_id': null})
        .eq('categoria_id', categoryId);

      // 2. Eliminar la categoría
      await supabase
        .from('categories')
        .delete()
        .eq('id', categoryId);

      await cargarCategorias();
      await cargarPasswords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Categoría eliminada')),
        );
      }
      // Si la categoría eliminada estaba seleccionada, resetea la selección
      if (idCategoriaSeleccionada == categoryId) {
        setState(() => idCategoriaSeleccionada = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar categoría: $e')),
        );
      }
    }
  }

}

class PaginaEditarPerfil extends StatefulWidget {
  const PaginaEditarPerfil({super.key});

  @override
  State<PaginaEditarPerfil> createState() => _PaginaEditarPerfilState();
}

class _PaginaEditarPerfilState extends State<PaginaEditarPerfil> {
  final keyFormulario = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passActualController = TextEditingController();
  final passNuevaController = TextEditingController();
  final confirmarPassController = TextEditingController();
  bool passActualVisible = false;
  bool nuevaPassVisible = false;
  bool estaCargando = false;
  String? mensajeError;

  bool passwordCambiada = false;
  bool get minLongitud => passNuevaController.text.length >= 12;
  bool get tieneMayus => passNuevaController.text.contains(RegExp(r'[A-Z]'));
  bool get tieneMinus => passNuevaController.text.contains(RegExp(r'[a-z]'));
  bool get tieneNum => passNuevaController.text.contains(RegExp(r'\d'));
  bool get tieneSimbolo => passNuevaController.text.contains(RegExp(r'''[ªº\\!"|@·#$~%€&¬/()=?'¡¿`^[\]*+´{}\-\_\.\:\,\;\<\>"]'''));
  String? PassActualError;

  Widget crearRequisitosPassword() {
    if (passNuevaController.text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          "La contraseña debe contener:",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        crearRequisitosFila("Al menos 12 caracteres", minLongitud),
        crearRequisitosFila("Una letra mayúscula", tieneMayus),
        crearRequisitosFila("Una letra minúscula", tieneMinus),
        crearRequisitosFila("Un número", tieneNum),
        crearRequisitosFila("Un carácter especial", tieneSimbolo),
      ],
    );
  }

  Widget crearRequisitosFila(String text, bool met) {
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
    cargarPerfil();
  }

  Future<void> cargarPerfil() async {
    final usuario = Supabase.instance.client.auth.currentUser;
    if (usuario != null) {
      setState(() {
        emailController.text = usuario.email ?? '';
      });
      
      final respuesta = await Supabase.instance.client
          .from('users')
          .select('nombre_usuario')
          .eq('auth_id', usuario.id)
          .single();
      
      if (mounted) {
        setState(() {
          usernameController.text = respuesta['nombre_usuario'] ?? '';
        });
      }
    }
  }

  Future<void> actualizarPerfil() async {
    if (!keyFormulario.currentState!.validate()) return;
    
    setState(() {
      estaCargando = true;
      mensajeError = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final usuario = supabase.auth.currentUser;
      final nuevoEmail = emailController.text.trim();
      if (usuario == null) return;

      // 1. Actualizar email en Supabase Auth
      await supabase.auth.updateUser(
        UserAttributes(email: nuevoEmail),
      );

      // Actualizar nombre de usuario
      await supabase.from('users').update({
        'nombre_usuario': usernameController.text.trim()
      }).eq('auth_id', usuario.id);

      // Actualizar contraseña
      if (passNuevaController.text.isNotEmpty) {
        try {
          // Reautenticación
          await supabase.auth.signInWithPassword(
            email: usuario.email!,
            password: passActualController.text,
          );
        } on AuthException catch (e) {
          if (e.message.contains('Invalid login credentials')) {
            setState(() {
              PassActualError = 'La contraseña actual es incorrecta';
            });
            return;
          } else {
            setState(() {
              PassActualError = 'Error: ${e.message}';
            });
            return;
          }
        }
        // Si pasa la autenticación, limpia el error
        setState(() {
          PassActualError = null;
        });

        // Actualizar contraseña
        await supabase.auth.updateUser(
          UserAttributes(password: passNuevaController.text),
        );

        // Actualizar clave maestra
        final nuevaSalt = EncryptionService.generarSaltSeguro();
        final nuevaMasterKey = await EncryptionService.derivarMasterKey(
          passNuevaController.text,
          nuevaSalt,
        );
        
        await supabase.from('users').update({
          'salt': base64Encode(nuevaSalt),
        }).eq('auth_id', usuario.id);

        final respuestaUsuario = await supabase
          .from('users')
          .select('id')
          .eq('auth_id', usuario.id)
          .single();
        final idUsuario = respuestaUsuario['id'] as int; 
        
        await migrarPasswords(
          idUsuario: idUsuario, 
          nuevaKey: nuevaMasterKey,
        );
        await EncryptionService.initialize(nuevaMasterKey);
        passwordCambiada = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => mensajeError = 'Error: ${e.toString()}');
    } finally {
      setState(() => estaCargando = false);
    }
  }

  Future<void> migrarPasswords({
    required int idUsuario,
    required encrypt.Key nuevaKey,
  }) async {
    final supabase = Supabase.instance.client;
    final masterKey = await EncryptionService.masterKeyActual;
    if (masterKey == null) return;

    final passwords = await supabase
        .from('passwords')
        .select()
        .eq('user_id', idUsuario);

    for (final pwd in passwords) {
      final descifrado = await EncryptionService.descifrarPassword(
        hashContrasena: pwd['hash_contrasena'],
        ivBytes: pwd['iv'],
        authTag: pwd['auth_tag'],
        key: masterKey,
      );

      final cifrado = await EncryptionService.cifrarPassword(descifrado, nuevaKey);

      await supabase.from('passwords').update({
        'hash_contrasena': cifrado['hash_contrasena'],
        'iv': cifrado['iv'],
        'auth_tag': cifrado['auth_tag'],
      }).eq('id', pwd['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: keyFormulario,
          child: Column(
            children: [
              TextFormField(
                controller: usernameController,
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
                controller: passActualController,
                obscureText: !passActualVisible,
                onChanged: (_) {
                  if (PassActualError != null) {
                    setState(() => PassActualError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(passActualVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => passActualVisible = !passActualVisible),
                  ),
                  errorText: PassActualError,
                  
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Introduce tu contraseña actual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passNuevaController,
                obscureText: !nuevaPassVisible,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(nuevaPassVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => nuevaPassVisible = !nuevaPassVisible),
                  ),
                ),
                onChanged: (_) => setState(() {}), // Para refrescar los requisitos en tiempo real
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!minLongitud) return 'Mínimo 12 caracteres';
                    if (!tieneMayus) return 'Al menos una mayúscula';
                    if (!tieneMinus) return 'Al menos una minúscula';
                    if (!tieneNum) return 'Al menos un número';
                    if (!tieneSimbolo) return 'Al menos un carácter especial';
                  }
                  return null;
                },
              ),
              if (passNuevaController.text.isNotEmpty) crearRequisitosPassword(),

              const SizedBox(height: 16),
              TextFormField(
                controller: confirmarPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva contraseña',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (value) {
                  if (passNuevaController.text.isNotEmpty && value != passNuevaController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },

              ),
              const SizedBox(height: 32),
              if (mensajeError != null)
                Text(mensajeError!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: estaCargando ? null : actualizarPerfil,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: estaCargando
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
