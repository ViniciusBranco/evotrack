// lib/login_screen.dart
import 'dart:convert';
import 'package:evorun/config.dart';
import 'package:evorun/dashboard_screen.dart';
import 'package:evorun/database_helper.dart';
import 'package:evorun/main_scaffold.dart';
import 'package:evorun/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    final savedPassword = prefs.getString('password');
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    if (rememberMe && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = rememberMe;
      });
    }
  }

  Future<void> _handleRememberMe() async {
    print('--- Iniciando _handleRememberMe ---');
    print('O valor de _rememberMe no momento do salvamento é: $_rememberMe');
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('email', _emailController.text);
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('rememberMe', true);
      print('Credenciais salvas.');
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.remove('rememberMe');
      print('Credenciais removidas.');
    }
  }

  Future<Map<String, dynamic>?> _loginApi() async {
    final url = Uri.parse('http://$apiDomain/api/v1/login/token');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': _emailController.text, 'password': _passwordController.text},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Erro de conexão na API de login: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('EvoTrack', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: _isLoading ? null : (bool? value) {
                          setState(() { _rememberMe = value ?? false; });
                        },
                      ),
                      const Text('Lembrar-me'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      setState(() { _isLoading = true; });

                      Map<String, dynamic>? userProfile;
                      String? token;

                      try {
                        final loginData = await _loginApi();

                        if (loginData != null) {
                          // --- LÓGICA DE LOGIN ONLINE ---
                          token = loginData['access_token'];
                          final profileUrl = Uri.parse('http://$apiDomain/api/v1/users/me/');
                          final profileResponse = await http.get(
                            profileUrl,
                            headers: {'Authorization': 'Bearer $token'},
                          );
                          if (mounted && profileResponse.statusCode == 200) {
                            userProfile = jsonDecode(profileResponse.body);
                            await DatabaseHelper().saveUserProfile(userProfile!, token!);
                            await DatabaseHelper().saveWorkouts(userProfile['workouts']);
                          }
                        } else {
                          // --- LÓGICA DE LOGIN OFFLINE ---
                          print('Login online falhou. Tentando login offline...');
                          userProfile = await DatabaseHelper().getUserProfile(_emailController.text);
                          if (userProfile != null) {
                            token = userProfile['token'] as String?;
                          }
                        }

                        // --- LÓGICA COMUM APÓS SUCESSO (ONLINE OU OFFLINE) ---
                        if (mounted && userProfile != null && token != null) {
                          await _handleRememberMe(); // CHAMADO AQUI, NO CAMINHO DE SUCESSO

                          if (userProfile['full_name'] == null) {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => OnboardingScreen(token: token!)));
                          } else {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScaffold(token: token!)));
                          }
                        } else if(mounted) {
                          // --- FALHA FINAL ---
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Offline ou credenciais incorretas. Apenas contas já usadas podem entrar.'), backgroundColor: Colors.orange),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() { _isLoading = false; });
                        }
                      }
                    },
                    child: const Text('Entrar'),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}