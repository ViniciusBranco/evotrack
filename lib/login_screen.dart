// login_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:evorun/config.dart';
import 'package:evorun/database_helper.dart';
import 'package:evorun/dashboard_screen.dart';
import 'package:evorun/onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // A função agora retorna um Map com os dados ou null em caso de falha
  Future<Map<String, dynamic>?> _login() async {
    final url = Uri.parse('http://$apiDomain/api/v1/login/token');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': _emailController.text,
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        // Retorna o corpo do JSON em caso de sucesso
        return jsonDecode(response.body);
      } else {
        // Retorna nulo em caso de falha de login
        return null;
      }
    } catch (e) {
      print(e); // Apenas para debug
      // Retorna nulo em caso de erro de conexão
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (newContext) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'EvoRun',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                  ),
                  const SizedBox(height: 32),
                  // No ElevatedButton, dentro do método build
                  ElevatedButton(
                      onPressed: () async {
                        final loginData = await _login();

                        if (!mounted) return;

                        if (loginData != null) {
                          // Login online bem-sucedido, agora buscamos e salvamos os dados
                          final token = loginData['access_token'];
                          final profileUrl = Uri.parse('http://$apiDomain/api/v1/users/me/');

                          final profileResponse = await http.get(
                            profileUrl,
                            headers: {'Authorization': 'Bearer $token'},
                          );

                          if (!mounted) return;

                          if (profileResponse.statusCode == 200) {
                            final userProfile = jsonDecode(profileResponse.body);
                            final List<dynamic> workouts = userProfile['workouts'];

                            // *** AQUI ESTÁ A MÁGICA ***
                            // Salva o perfil e os treinos no banco de dados local
                            await DatabaseHelper().saveUserProfile(userProfile, token);
                            await DatabaseHelper().saveWorkouts(workouts);

                            // Agora, com os dados já salvos, decidimos para onde ir
                            if (userProfile['full_name'] == null) {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OnboardingScreen(token: token)));
                            } else {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardScreen(token: token)));
                            }
                          } else {
                            // Tratar erro ao buscar perfil, se necessário
                          }
                        } else {
                          // Login online falhou, tentar login offline
                          print('Login online falhou. Tentando login offline...');
                          final localProfile = await DatabaseHelper().getUserProfile(_emailController.text);

                          if (localProfile != null) {
                            // Usuário encontrado localmente, permitir acesso offline
                            print('Perfil local encontrado. Concedendo acesso offline.');

                            // Pegamos o token salvo localmente para usar nas próximas telas
                            final token = localProfile['token'] as String;

                            if (!mounted) return;

                            // A lógica de navegação é a mesma de antes
                            if (localProfile['full_name'] == null) {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OnboardingScreen(token: token)));
                            } else {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardScreen(token: token)));
                            }
                          } else {
                            // Usuário não encontrado localmente, acesso negado
                            print('Nenhum perfil local encontrado. Acesso offline negado.');
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Offline. Apenas contas já usadas neste aparelho podem entrar.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      },
                    child: const Text('Entrar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
