// lib/workout_config.dart
import 'package:flutter/material.dart';
import 'package:evorun/database_helper.dart';

// Classe para guardar as propriedades de cada tipo de treino
class WorkoutInfo {
  final String apiName;
  final String displayName;
  final IconData icon;
  Color color; // A cor não é 'final', pode ser alterada

  WorkoutInfo({
    required this.apiName,
    required this.displayName,
    required this.icon,
    required this.color,
  });
}

// Serviço Singleton para gerenciar as configurações visuais dos treinos
class WorkoutVisualsService {
  // Padrão Singleton para garantir uma única instância
  static final WorkoutVisualsService _instance = WorkoutVisualsService._internal();
  factory WorkoutVisualsService() => _instance;
  WorkoutVisualsService._internal();

  // O mapa de trabalho "vivo" que o app usa
  final Map<String, WorkoutInfo> _config = {
    'running': WorkoutInfo(apiName: 'running', displayName: 'Corrida', icon: Icons.directions_run, color: Colors.green),
    'cycling': WorkoutInfo(apiName: 'cycling', displayName: 'Ciclismo', icon: Icons.directions_bike, color: Colors.brown),
    'weightlifting': WorkoutInfo(apiName: 'weightlifting', displayName: 'Musculação', icon: Icons.fitness_center, color: Colors.purple),
    'stairs': WorkoutInfo(apiName: 'stairs', displayName: 'Escada', icon: Icons.stairs, color: Colors.amber),
    'swimming': WorkoutInfo(apiName: 'swimming', displayName: 'Natação', icon: Icons.pool, color: Colors.blue),
    'no_workout': WorkoutInfo(
      apiName: 'no_workout',
      displayName: 'Dia Sem Treino',
      icon: Icons.calendar_month_outlined,
      color: Colors.grey.shade300,
    ),
  };

  // O gabarito "somente leitura" com as cores padrão
  final Map<String, Color> _defaultColors = {
    'running': Colors.green,
    'cycling': Colors.brown,
    'weightlifting': Colors.purple,
    'stairs': Colors.amber,
    'swimming': Colors.blue,
    'no_workout': Colors.grey.shade300,
  };

  // Carrega as cores customizadas do banco e atualiza o mapa de trabalho
  Future<void> loadColorsFromDb(String userEmail) async {
    final customColors = await DatabaseHelper().loadWorkoutColors(userEmail);
    // Primeiro, restaura para o padrão para limpar cores de sessões antigas
    _config.forEach((key, info) {
      if (_defaultColors.containsKey(key)) {
        info.color = _defaultColors[key]!;
      }
    });
    // Depois, aplica as cores customizadas do usuário atual
    customColors.forEach((key, color) {
      if (_config.containsKey(key)) {
        _config[key]!.color = color;
      }
    });
    print('Cores customizadas carregadas.');
  }

  // Atualiza uma cor, tanto em memória quanto no banco
  Future<void> updateColor(String userEmail, String workoutTypeId, Color newColor) async {
    if (_config.containsKey(workoutTypeId)) {
      _config[workoutTypeId]!.color = newColor;
      await DatabaseHelper().saveWorkoutColor(userEmail, workoutTypeId, newColor);
    }
  }

  // Reseta as cores para o padrão
  Future<void> resetToDefaults(String userEmail) async {
    await DatabaseHelper().clearWorkoutColors(userEmail);
    _config.forEach((key, value) {
      if (_defaultColors.containsKey(key)) {
        value.color = _defaultColors[key]!;
      }
    });
    print('Cores resetadas para o padrão em memória.');
  }

  // Retorna a informação de um treino específico
  WorkoutInfo getInfo(String apiName) {
    return _config[apiName.toLowerCase()] ?? WorkoutInfo(
      apiName: 'unknown',
      displayName: apiName,
      icon: Icons.help_outline,
      color: Colors.grey,
    );
  }

  // Retorna toda a configuração
  Map<String, WorkoutInfo> getAllConfigs() => _config;
}