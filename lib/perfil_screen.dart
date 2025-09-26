// lib/perfil_screen.dart
import 'package:flutter/material.dart';
import 'package:evorun/configuracoes_screen.dart';

class PerfilScreen extends StatelessWidget {
  final Future<void> Function() onSync;
  final bool hasUnsyncedChanges; // Novo parâmetro
  final String userEmail; // Novo parâmetro

  const PerfilScreen({
    super.key,
    required this.onSync,
    required this.hasUnsyncedChanges, // Novo parâmetro
    required this.userEmail, // Novo parâmetro
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Configurações'),
          // O trailing agora é o indicador
          trailing: hasUnsyncedChanges
              ? Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          )
              : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConfiguracoesScreen(
                  userEmail: userEmail, // Passe o email para a próxima tela
                  onSync: onSync,
                  hasUnsyncedChanges: hasUnsyncedChanges, // Passa para a próxima tela
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}