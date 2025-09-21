// lib/workout_config.dart
import 'package:flutter/material.dart';

// Classe para guardar as propriedades de cada tipo de treino
class WorkoutInfo {
  final String apiName;
  final String displayName;
  final IconData icon;
  final Color color;

  WorkoutInfo({
    required this.apiName,
    required this.displayName,
    required this.icon,
    required this.color,
  });
}

// O nosso "dicionário" central
final Map<String, WorkoutInfo> workoutConfig = {
  'running': WorkoutInfo(
    apiName: 'running',
    displayName: 'Corrida',
    icon: Icons.directions_run,
    color: Colors.green,
  ),
  'cycling': WorkoutInfo(
    apiName: 'cycling',
    displayName: 'Ciclismo',
    icon: Icons.directions_bike,
    color: Colors.brown,
  ),
  'weightlifting': WorkoutInfo(
    apiName: 'weightlifting',
    displayName: 'Musculação',
    icon: Icons.fitness_center,
    color: Colors.purple,
  ),
  'stairs': WorkoutInfo(
    apiName: 'stairs',
    displayName: 'Escada',
    icon: Icons.stairs,
    color: Colors.amber,
  ),
  'swimming': WorkoutInfo(
    apiName: 'swimming',
    displayName: 'Natação',
    icon: Icons.pool,
    color: Colors.blue,
  ),
};

// Funções de ajuda para facilitar o acesso
WorkoutInfo getWorkoutInfo(String apiName) {
  return workoutConfig[apiName.toLowerCase()] ?? WorkoutInfo(
    apiName: 'unknown',
    displayName: apiName, // Mostra o nome desconhecido
    icon: Icons.help_outline,
    color: Colors.grey,
  );
}