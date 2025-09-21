// lib/configuracoes_screen.dart
import 'package:flutter/material.dart';

class ConfiguracoesScreen extends StatelessWidget {
  final Future<void> Function() onSync;
  final bool hasUnsyncedChanges;

  const ConfiguracoesScreen({
    super.key,
    required this.onSync,
    required this.hasUnsyncedChanges,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          ListTile(
            // A propriedade 'enabled' controla se o ListTile é interativo
            enabled: hasUnsyncedChanges,
            // Se não houver mudanças, onTap é nulo, desabilitando o clique
            onTap: hasUnsyncedChanges ? onSync : null,
            leading: Icon(
              Icons.sync,
              // Muda a cor do ícone para cinza se estiver desabilitado
              color: hasUnsyncedChanges ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            title: const Text('Sincronizar Dados'),
            // O subtítulo agora também informa o status
            subtitle: Text(
              hasUnsyncedChanges
                  ? 'Enviar alterações locais para o servidor'
                  : 'Seus dados já estão sincronizados',
            ),
          ),
        ],
      ),
    );
  }
}