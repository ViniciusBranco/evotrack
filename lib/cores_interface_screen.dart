// lib/cores_interface_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:evorun/database_helper.dart';
import 'package:evorun/workout_config.dart';

class CoresInterfaceScreen extends StatefulWidget {
  final String userEmail;
  const CoresInterfaceScreen({super.key, required this.userEmail});

  @override
  State<CoresInterfaceScreen> createState() => _CoresInterfaceScreenState();
}

class _CoresInterfaceScreenState extends State<CoresInterfaceScreen> {
  void _pickColor(BuildContext context, String workoutTypeId) {
    Color pickerColor = WorkoutVisualsService().getInfo(workoutTypeId).color;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escolha uma cor'),
        content: SingleChildScrollView(
          child: ColorPicker(pickerColor: pickerColor, onColorChanged: (color) => pickerColor = color),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            child: const Text('Salvar'),
            onPressed: () {
              setState(() {
                WorkoutVisualsService().updateColor(widget.userEmail, workoutTypeId, pickerColor);
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // NOVA FUNÇÃO: Diálogo de confirmação para o reset
  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetar Cores'),
        content: const Text('Tem certeza que deseja restaurar as cores padrão? Esta ação não pode ser desfeita.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            child: const Text('Resetar', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await WorkoutVisualsService().resetToDefaults(widget.userEmail);
              if (mounted) {
                setState(() {}); // Força a reconstrução da tela para mostrar as cores padrão
                Navigator.of(ctx).pop(); // Fecha o diálogo
                // Mostra o "toast" de confirmação
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cores restauradas para o padrão.'), backgroundColor: Colors.green),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cores da Interface'),
        backgroundColor: Colors.blue[800],
        // NOVO: Botão de Ação para o reset
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            tooltip: 'Restaurar Padrão',
            onPressed: _showResetConfirmationDialog,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: WorkoutVisualsService().getAllConfigs().length,
        itemBuilder: (context, index) {
          final workoutTypeId = WorkoutVisualsService().getAllConfigs().keys.elementAt(index);
          final workoutInfo = WorkoutVisualsService().getInfo(workoutTypeId);

          return ListTile(
            leading: Icon(workoutInfo.icon, color: workoutInfo.color),
            title: Text(workoutInfo.displayName),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: workoutInfo.color, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
            ),
            onTap: () => _pickColor(context, workoutTypeId),
          );
        },
      ),
    );
  }
}