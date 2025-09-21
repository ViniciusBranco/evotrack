// onboarding_screen.dart
import 'package:flutter/material.dart';

import 'package:evorun/dashboard_screen.dart'; // Precisaremos disto para a navegação
import 'package:evorun/login_screen.dart';


class OnboardingScreen extends StatefulWidget {
  final String token;
  const OnboardingScreen({super.key, required this.token});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Controllers para os campos do formulário
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  // Adicione mais controladores se precisar, como para os dias de treino

  void _saveProfile() {
    // TODO: Adicionar lógica para salvar dados no backend e no DB local
    print('Salvando perfil...');

    // Após salvar, navega para o dashboard
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(token: widget.token),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete seu Perfil'),
        backgroundColor: Colors.blue[800],
      ),
      // Permite que a tela role se o teclado cobrir os campos
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Precisamos de mais algumas informações para começar.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome Completo'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Idade'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Peso (kg)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _heightController,
              decoration: const InputDecoration(labelText: 'Altura (cm)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botão Cancelar
                TextButton(
                  onPressed: () {
                    // Substitui a tela de Onboarding pela de Login
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text('Cancelar'),
                ),
                // Botão Salvar
                ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text('Salvar e Continuar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}