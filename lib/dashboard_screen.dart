// lib/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:evorun/main_scaffold.dart'; // Importe o novo shell

class DashboardScreen extends StatelessWidget {
  final String token;
  const DashboardScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    // A DashboardScreen agora apenas retorna o nosso shell reutilizável
    return MainScaffold(token: token);
  }
}