import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String? email;
  const HomePage({super.key, this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenido')),
      body: Center(
        child: Text(
          '¡Hola, $email!',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
