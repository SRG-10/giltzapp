import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show  kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'home_page.dart'; 
import 'package:encrypt/encrypt.dart' as encrypt;
import 'encryption_service.dart';
import 'dart:typed_data';
import 'web_utils.dart'
    if (dart.library.html) 'web_utils_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://abioxiwzcrsemxllqznq.supabase.co',        
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiaW94aXd6Y3JzZW14bGxxem5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyNDAzOTgsImV4cCI6MjA2NDgxNjM5OH0.1xFPpUgEOJZPHnpbYm4GyQvjzCqptIcOO1dGEausiz8',
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, 
    )
  );
  runApp(const App());
}

class App extends StatelessWidget{
  const App({super.key});

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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final sesion = Supabase.instance.client.auth.currentSession;
          final esReseteo = Uri.base.path == '/reset-password';

          // Solo muestra pagina de inicio si hay sesión Y NO es flujo de reseteo
          if (sesion != null && !esReseteo) {
            return const PaginaInicio();
          } else {
            return const PaginaAutenticacion();
          }
        },
      ),

      onGenerateRoute: (settings) {
        // Maneja rutas no definidas (opcional)
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Página no encontrada')),
          ),
        );
      },
    );
  }
}

class PaginaAutenticacion extends StatefulWidget {
  const PaginaAutenticacion({super.key});

  @override
  State<PaginaAutenticacion> createState() => _PaginaAutenticacionState();
}

class _PaginaAutenticacionState extends State<PaginaAutenticacion> {

  final keyFormularioLogin = GlobalKey<FormState>();
  final keyFormularioRegistro = GlobalKey<FormState>();
  final keyFormularioReset = GlobalKey<FormState>();

  encrypt.Key? keyMasterActual;

  bool esLogin = true;
  bool estaCargando = false;
  bool resetPasswordVisible = false;

  // Controladores login
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loginPasswordVisible = false;

  // Controladores registro
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController registroEmailController = TextEditingController();
  final TextEditingController registroPasswordController = TextEditingController();
  final TextEditingController registroConfirmPasswordController = TextEditingController();
  bool registroPasswordVisible = false;

  // Controladores reset
  final nuevaPasswordController = TextEditingController();
  final confirmarPasswordController = TextEditingController();
  bool _resetLoading = false;

  String? mensajeError;

  // Requisitos de contraseña
  bool get minLongitud => registroPasswordController.text.length >= 12;
  bool get tieneMayus => registroPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get tieneMinus => registroPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get tieneNums => registroPasswordController.text.contains(RegExp(r'\d'));
  bool get tieneSimbolo => registroPasswordController.text.contains(RegExp(r'''[ªº\\!"|@·#$~%€&¬/()=?'¡¿`^[\]*+´{}\-\_\.\:\,\;\<\>"]'''));

  bool get minLongitudReset => nuevaPasswordController.text.length >= 12;
  bool get tieneMayusReset => nuevaPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get tieneMinusReset => nuevaPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get tieneNumsReset => nuevaPasswordController.text.contains(RegExp(r'\d'));
  bool get tieneSimboloReset => nuevaPasswordController.text.contains(RegExp(r'''[ªº\\!"|@·#$~%€&¬/()=?'¡¿`^[\]*+´{}\-\_\.\:\,\;\<\>"]'''));

  final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,3}$');
  final RegExp passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$&*~.,;:_\-+=?¿¡!%/(){}\[\]]).{12,}$');

  bool esPasswordRecuperar = false;

  bool mostrarResetPassword = false;
  String? codReset;
  String? resetError;

  void cambiarFormulario() {
    if (estaCargando) return;
    
    // Primero actualiza el estado para cambiar de formulario
    setState(() {
      esLogin = !esLogin;
      mensajeError = null;
    });

    // Limpia solo los campos relevantes después de la actualización
    registroPasswordController.clear();
    registroConfirmPasswordController.clear();
    usernameController.clear();
    registroEmailController.clear();
    emailController.clear();
    passwordController.clear();
  }

  void limpiarCampos() {
    loginPasswordVisible = false;
    emailController.clear();
    passwordController.clear();
  }

  Future<void> enviarLogin() async {
    if (estaCargando) return;
    if (keyFormularioLogin.currentState!.validate()) {
      setState(() {
        estaCargando = true;
        mensajeError = null;
      });
      try {
        final supabase = Supabase.instance.client;
        final respuesta = await supabase.auth.signInWithPassword(
          email: emailController.text,
          password: passwordController.text,
        );

        final datosUsuario = await supabase
            .from('users')
            .select('salt')
            .eq('auth_id', respuesta.user!.id)
            .single();

        final salt = base64Decode(datosUsuario['salt'] as String);
        final masterKey = await EncryptionService.derivarMasterKey(passwordController.text, salt);

        await EncryptionService.initialize(masterKey);

        if (mounted)
        {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PaginaInicio()));
        }
        

      } on AuthException catch (error) {
        if (mounted) {setState(() => mensajeError = error.message);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error de inicio de sesión'),
              content: Text(error.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted)
        {
          setState(() => mensajeError = 'Error inesperado durante el login');
          showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Error inesperado'),
            content: Text('Error inesperado durante el login'),
          ),
        );
        }
       
      } finally {
        if (mounted){
          setState(() {
          estaCargando = false;
        });
        }
        
      }
    }
  }

  Future<void> enviarRegistro() async {
    if (estaCargando) return; // Evita múltiples envíos
    if (keyFormularioRegistro.currentState!.validate() && minLongitud && tieneMayus && tieneMinus && tieneNums) {
      setState(() {
        estaCargando = true;
        mensajeError = null;
      });
      try {
        final supabase = Supabase.instance.client;

        final existe = await supabase
            .from('users')
            .select()
            .or('correo_electronico.eq.${registroEmailController.text},nombre_usuario.eq.${usernameController.text}')
            .maybeSingle();

        if (existe != null) {
          setState(() {
            mensajeError = 'El correo electrónico o el nombre de usuario ya están en uso.';
            estaCargando = false;
          });
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error de registro'),
              content: Text(mensajeError!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        final respuesta = await supabase.auth.signUp(
          email: registroEmailController.text,
          password: registroPasswordController.text,
          emailRedirectTo: 'giltzapp.vercel.app',
          data: {
            'username': usernameController.text,
          },
        );

        if (respuesta.user != null) {
          final salt = EncryptionService.generarSaltSeguro();
          final masterKey = await EncryptionService.derivarMasterKey(registroPasswordController.text, salt);
          await supabase.from('users').insert({
            'auth_id': respuesta.user!.id,
            'nombre_usuario': usernameController.text,
            'correo_electronico': registroEmailController.text,
            'hash_contrasena_maestra': base64Encode(masterKey.bytes),
            'salt': base64Encode(salt),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registro exitoso. Revisa tu email para confirmar la cuenta. También consulta la carpeta de spam.')),
            );
          }
          
          setState(() {
            esLogin = true;
            estaCargando = false;
          });
          // Solo limpiar los campos de registro, no los de login
          registroPasswordController.clear();
          registroConfirmPasswordController.clear();
          usernameController.clear();
          registroEmailController.clear();
        }
      } on AuthException catch (error) {
        String mensaje;
        // Intenta decodificar el mensaje si es un JSON
        try {
          final decodificado = jsonDecode(error.message);
          if (decodificado is Map && decodificado['message'] == 'Error sending confirmation email') {
            mensaje = 'No se pudo enviar el correo de confirmación.';
          } else {
            mensaje = decodificado['message'] ?? 'Error desconocido durante el registro.';
          }
        } catch (_) {
          // Si no es un JSON, usa el mensaje original
          if (error.message.contains('Error sending confirmation email')) {
            mensaje = 'No se pudo enviar el correo de confirmación.';
          } else {
            mensaje = error.message;
          }
        }
        setState(() {
          mensajeError = mensaje;
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error de registro'),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        setState(() {
          mensajeError = 'Error inesperado durante el registro';
        });
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Error inesperado'),
            content: Text('Ha ocurrido un error inesperado durante el registro.'),
            actions: [
              TextButton(
                onPressed: null, // O Navigator.of(context).pop()
                child: Text('OK'),
              ),
            ],
          ),
        );
      } finally {
        setState(() {
          estaCargando = false;
        });
      }
    } else {
      setState(() {
        mensajeError = "La contraseña no cumple todos los requisitos.";
      });
    }
  }

  @override
  void dispose() { // Limpia los controladores al eliminar el widget
    keyMasterActual?.bytes.fillRange(0, keyMasterActual!.bytes.length, 0); // Limpia el contenido del master key
    keyMasterActual = null;
    loginPasswordVisible = false;
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    registroEmailController.dispose();
    registroPasswordController.dispose();
    registroConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (mostrarResetPassword) {
      // Muestra el formulario de reseteo
      return crearFormularioResetPassword();
    }
    // Si no es reseteo, muestra login o registro
    return Scaffold(
      appBar: AppBar(
        title: Text(esLogin ? 'Iniciar sesión' : 'Registrarse'),
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
                child: esLogin ? crearFormularioLogin() : construirFormularioRegistro(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget crearFormularioResetPassword() {
    return PopScope(
      canPop: false, // Bloquea el pop por defecto
      onPopInvoked: (didPop) async {
        if (!didPop) {
          redirigirALogin(); // Cierra sesión y limpia todo
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Restablecer contraseña'),
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
                  child: Form(
                    key: keyFormularioReset,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Introduce tu nueva contraseña',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: nuevaPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                resetPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  resetPasswordVisible = !resetPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !resetPasswordVisible,
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Ingresa la nueva contraseña';
                            if (!minLongitudReset) return 'Mínimo 12 caracteres';
                            if (!tieneMayusReset) return 'Al menos una mayúscula';
                            if (!tieneMinusReset) return 'Al menos una minúscula';
                            if (!tieneNumsReset) return 'Al menos un número';
                            if (!tieneSimboloReset) return 'Al menos un carácter especial';
                            return null;
                          },
                        ),
                        if (nuevaPasswordController.text.isNotEmpty) crearRequisitosResetPassword(),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmarPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Confirma la contraseña';
                            if (value != nuevaPasswordController.text) return 'Las contraseñas no coinciden';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _resetLoading ? null : enviarResetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _resetLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Actualizar contraseña'),
                          ),
                        ),
                        if (resetError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              resetError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              mostrarResetPassword = false;
                              resetError = null;
                            });
                          },
                          child: const Text('Volver al login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget crearRequisitosResetPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          "La contraseña debe contener:",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        construirFilaRequisitos("Al menos 12 caracteres", minLongitudReset),
        construirFilaRequisitos("Una letra mayúscula", tieneMayusReset),
        construirFilaRequisitos("Una letra minúscula", tieneMinusReset),
        construirFilaRequisitos("Un número", tieneNumsReset),
        construirFilaRequisitos("Un carácter especial", tieneSimboloReset),
      ],
    );
  }

  bool esBase64(String str) {
    try {
      base64Decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> enviarResetPassword() async {
    try {
      final supabase = Supabase.instance.client;
      final usuario = supabase.auth.currentUser!;
      
      // 1. Obtener clave actual antes del cambio
      final datosUsuario = await supabase
          .from('users')
          .select('salt, hash_contrasena_maestra')
          .eq('auth_id', usuario.id)
          .single();


      final dynamic idDatos = datosUsuario['id'];
      final int idUsuarioBigInt;

      if (idDatos is int) {
        idUsuarioBigInt = idDatos;
      } else {
        idUsuarioBigInt = int.parse(idDatos.toString()); // Conversión segura
      }

      Uint8List saltActual;
      if (datosUsuario['salt'] == null) {
        saltActual = EncryptionService.generarSaltSeguro();
        await supabase.from('users').update({'salt': base64Encode(saltActual)});
      } else {
        saltActual = base64Decode(datosUsuario['salt'] as String);
      }

      if (datosUsuario['salt'] == null) {
        throw Exception('Usuario no tiene salt registrado');
      }

      // Verificar formato base64
        try {
          base64Decode(datosUsuario['salt'] as String);
        } catch (e) {
          throw Exception('Formato de salt inválido');
        }

      keyMasterActual = await EncryptionService.derivarMasterKey(
        passwordController.text, // Contraseña actual
        saltActual,
      );

      // 2. Generar nuevos componentes de seguridad
      final saltNueva = EncryptionService.generarSaltSeguro();
      final nuevaMasterKey = await EncryptionService.derivarMasterKey(
        nuevaPasswordController.text,
        saltNueva,
      );

      // 3. Actualizar en transacción
      await supabase.rpc('update_user_credentials', params: {
        'user_id': usuario.id,
        'new_password': nuevaPasswordController.text,
        'new_hash': base64Encode(nuevaMasterKey.bytes),
        'new_salt': base64Encode(saltNueva),
      });

      // 4. Migrar contraseñas con ambas claves
      await migrarPasswords(
        idUsuario: idUsuarioBigInt,
        oldKey: keyMasterActual!,
        newKey: nuevaMasterKey,
      );

      // 5. Limpiar clave anterior
      keyMasterActual = null;

    } on PostgrestException catch (e) {
      setState(() => resetError = 'Error de base de datos: ${e.message}');
    } catch (e) {
      setState(() => resetError = 'Error inesperado X: ${e.toString()}');
    } finally {
      setState(() => _resetLoading = false);
    }
  }

  Future<void> migrarPasswords({required int idUsuario, required encrypt.Key oldKey, required encrypt.Key newKey,}) async {

    final supabase = Supabase.instance.client;
    
    final passwords = await supabase
        .from('passwords')
        .select()
        .eq('user_id', idUsuario);

    for (final pwd in passwords) {

      if (pwd['hash_contrasena'] == null || pwd['iv'] == null || pwd['auth_tag'] == null) continue;

      // Descifrar con clave antigua
      final descifrado = await EncryptionService.descifrarPassword(
        hashContrasena: pwd['hash_contrasena'] as String,
        ivBytes: pwd['iv'] as String,
        authTag: pwd['auth_tag'] as String,
        key: oldKey,
      );
      
      // Cifrar con nueva clave
      final cifrado = await EncryptionService.cifrarPassword(descifrado, newKey);
      
      // Actualizar con todos los campos requeridos
      await supabase.from('passwords').update({
        'hash_contrasena': cifrado['hash_contrasena'],
        'iv': cifrado['iv'],
        'auth_tag': cifrado['auth_tag'],
      }).eq('id', pwd['id']);
    }
  } 

  void redirigirALogin() async {
    // 1. Cierra la sesión PKCE generada por el enlace de recuperación
    await Supabase.instance.client.auth.signOut(); 
    
    // 2. Limpia el estado del formulario
    setState(() {
      mostrarResetPassword = false;
      resetError = null;
      nuevaPasswordController.clear();
      confirmarPasswordController.clear();
      esLogin = true;
    });

    if (kIsWeb) {
      clearWebUrl(); // Esto solo hará algo en web
    }
      
    
    // 4. Redirige al login y elimina el historial de navegación
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Widget crearFormularioLogin() { // Construye el formulario de inicio de sesión
    mensajeError = null; // Resetea el mensaje de error al construir el formulario
    return Form(
      key: keyFormularioLogin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: emailController,
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
              if (!RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  loginPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    loginPasswordVisible = !loginPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !loginPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu contraseña';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (mensajeError != null)
            Text(
              mensajeError!,
              style: const TextStyle(color: Colors.red),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: estaCargando ? null : enviarLogin,
              child: estaCargando
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: estaCargando ? null : mostrarDialogoPasswordOlvidada,
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
              TextButton(
                onPressed: estaCargando ? null : cambiarFormulario,
                child: const Text('Regístrate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void mostrarDialogoPasswordOlvidada() {
    final emailOlvidadoController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? emailError;
    bool cargando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Recuperar contraseña',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailOlvidadoController,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: const Icon(Icons.email),
                          border: const OutlineInputBorder(),
                          errorText: emailError,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                            return 'Correo no válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: cargando
                              ? null
                              : () async {
                                  setState(() {
                                    emailError = null;
                                    cargando = true;
                                  });
                                  if (formKey.currentState!.validate()) {
                                    final email = emailOlvidadoController.text.trim();
                                    final supabase = Supabase.instance.client;
                                    final respuesta = await supabase
                                        .from('users')
                                        .select()
                                        .eq('correo_electronico', email)
                                        .maybeSingle();

                                    if (respuesta == null) {
                                      setState(() {
                                        emailError = 'Correo no registrado';
                                        cargando = false;
                                      });
                                    } else {
                                      await enviarEmailResetPasswordYMostrarExito(email);
                                      Navigator.pop(context);
                                    }
                                  } else {
                                    setState(() => cargando = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: cargando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Enviar'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> enviarEmailResetPasswordYMostrarExito(String email) async {
    setState(() => estaCargando = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://giltzapp.vercel.app/reset-password', 
      );
      // Muestra mensaje de éxito tipo registro y vuelve al login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo enviado. Revisa tu correo para restablecer la contraseña. También consulta la carpeta de spam.'),
          duration: Duration(seconds: 5),
        ),
      );
      if (!esLogin) {
        setState(() {
          esLogin = true; // Cambia a la pantalla de login
        });
      }
    } on AuthException catch (error) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() => estaCargando = false);
    }
  }

  Widget construirFormularioRegistro() { // Construye el formulario de registro
    mensajeError = null; // Resetea el mensaje de error al construir el formulario
    return Form(
      key: keyFormularioRegistro,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: usernameController,
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
            controller: registroEmailController,
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
              if (!RegExp(r'^[^@]+@[^@]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: registroPasswordController,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  registroPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    registroPasswordVisible = !registroPasswordVisible;
                  });
                },
              ),
            ),
            obscureText: !registroPasswordVisible,
            onChanged: (_) => setState(() {}), // Actualiza requisitos en tiempo real
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu contraseña';
              }
              return null;
            },
          ),
          if (registroPasswordController.text.isNotEmpty) construirRequisitosPassword(),
          const SizedBox(height: 16),
          TextFormField(
            controller: registroConfirmPasswordController,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
            obscureText: true, 
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor confirma tu contraseña';
              }
              if (value != registroPasswordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (mensajeError != null)
            Text(
              mensajeError!,
              style: const TextStyle(color: Colors.red),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: estaCargando ? null : enviarRegistro,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: estaCargando
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
            onPressed: estaCargando ? null : cambiarFormulario,
            child: const Text('¿Ya tienes cuenta? Inicia sesión'),
          ),
        ],
      ),
    );
  }

  Widget construirRequisitosPassword() { // Construye los requisitos de la contraseña
    if (registroPasswordController.text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          "La contraseña debe contener:",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        construirFilaRequisitos("Al menos 12 caracteres", minLongitud),
        construirFilaRequisitos("Una letra mayúscula", tieneMayus),
        construirFilaRequisitos("Una letra minúscula", tieneMinus),
        construirFilaRequisitos("Un número", tieneNums),
        construirFilaRequisitos("Un carácter especial", tieneSimbolo),
      ],
    );
  }

  Widget construirFilaRequisitos(String text, bool met) { // Construye una fila para cada requisito de contraseña
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

  @override
  void initState() {
    super.initState();
    comprobarResetPassword();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final evento = data.event;
      if (evento == AuthChangeEvent.passwordRecovery) {
        setState(() {
          mostrarResetPassword = true;
          esPasswordRecuperar = true;

        });
      }
    });

  }

  void comprobarResetPassword() {
    final uri = Uri.base;
    if (uri.path == '/reset-password' && uri.queryParameters['code'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          mostrarResetPassword = true;
          codReset = uri.queryParameters['code'];
        });
      });
    }
  }

}