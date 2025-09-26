// lib/database_helper.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Padrão Singleton para garantir uma única instância do banco
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Função para dizer se há algo para sincronizar
  Future<bool> hasUnsyncedChanges() async {
    final db = await database;
    final toCreate = await db.query('workouts', where: 'api_id IS NULL AND synced = 0');
    final toUpdate = await db.query('workouts', where: 'api_id IS NOT NULL AND synced = 0');
    final toDelete = await db.query('workouts', where: 'to_be_deleted = 1');
    return toCreate.isNotEmpty || toUpdate.isNotEmpty || toDelete.isNotEmpty;
  }

  // Método para criar um novo treino localmente
  Future<void> createWorkout(Map<String, dynamic> workout) async {
    final db = await database;
    workout['synced'] = 0; // Marca como não sincronizado
    await db.insert('workouts', workout);
    print('Novo treino salvo localmente (não sincronizado).');
  }

// Método para atualizar um treino existente
  Future<void> updateWorkout(int id, Map<String, dynamic> workout) async {
    final db = await database;
    workout['synced'] = 0; // Marca como não sincronizado
    await db.update('workouts', workout, where: 'id = ?', whereArgs: [id]);
    print('Treino ID $id atualizado localmente (não sincronizado).');
  }

  Future<List<Map<String, dynamic>>> getWorkoutsToCreate() async {
    final db = await database;
    return await db.query('workouts', where: 'api_id IS NULL AND synced = 0');
  }

  // Busca treinos atualizados localmente (com api_id mas não sincronizados)
  Future<List<Map<String, dynamic>>> getWorkoutsToUpdate() async {
    final db = await database;
    return await db.query('workouts', where: 'api_id IS NOT NULL AND synced = 0');
  }

  // Atualiza um treino local com o api_id recebido do servidor e marca como sincronizado
  Future<void> updateApiIdAndMarkSynced(int localId, int apiId) async {
    final db = await database;
    await db.update(
      'workouts',
      {'api_id': apiId, 'synced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // Apenas marca um treino existente como sincronizado
  Future<void> markWorkoutAsSynced(int localId) async {
    final db = await database;
    await db.update('workouts', {'synced': 1}, where: 'id = ?', whereArgs: [localId]);
  }

  // Busca apenas os treinos marcados para exclusão
  Future<List<Map<String, dynamic>>> getWorkoutsToDelete() async {
    final db = await database;
    return await db.query('workouts', where: 'to_be_deleted = 1');
  }

// Exclui um treino permanentemente do banco de dados local
  Future<void> deleteWorkoutPermanently(int id) async {
    final db = await database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
    print('Workout ID $id excluído permanentemente do banco local.');
  }

  Future<List<Map<String, dynamic>>> getWorkouts(String userEmail) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workouts',
      where: 'to_be_deleted = 0 AND user_email = ?', // Filtra por email
      whereArgs: [userEmail],
    );

    // O 'details' está salvo como uma string JSON, precisamos decodificá-lo
    if (maps.isNotEmpty) {
      return maps.map((workout) {
        final newWorkout = Map<String, dynamic>.from(workout);
        if (newWorkout['details'] != null) {
          newWorkout['details'] = jsonDecode(newWorkout['details'] as String);
        }
        return newWorkout;
      }).toList();
    }
    return [];
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'evorun_local.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> markWorkoutForDeletion(int id) async {
    final db = await database;
    await db.update(
      'workouts',
      {'to_be_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    print('Workout ID $id marcado para exclusão.');
  }

  // Cria as tabelas, espelhando a estrutura do seu projeto Python
  void _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        email TEXT PRIMARY KEY,
        full_name TEXT,
        age INTEGER,
        weight_kg REAL,
        height_cm REAL,
        token TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        api_id INTEGER UNIQUE,
        user_email TEXT NOT NULL,
        workout_type TEXT,
        workout_date TEXT,
        duration_minutes INTEGER,
        distance_km REAL,
        details TEXT,
        to_be_deleted INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
    CREATE TABLE workout_colors (
      user_email TEXT NOT NULL,
      workout_type_id TEXT NOT NULL,
      color_value INTEGER NOT NULL,
      PRIMARY KEY (user_email, workout_type_id)
    )
  ''');
  }

  // Método para buscar um perfil de usuário pelo email
  Future<Map<String, dynamic>?> getUserProfile(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_profile',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Método para salvar/atualizar o perfil do usuário
  Future<void> saveUserProfile(Map<String, dynamic> userProfile, String token) async {
    final db = await database;
    // Prepara os dados para inserção
    Map<String, dynamic> profileToSave = {
      'email': userProfile['email'],
      'full_name': userProfile['full_name'],
      'age': userProfile['age'],
      'weight_kg': userProfile['weight_kg'],
      'height_cm': userProfile['height_cm'],
      'token': token, // Salva o token também!
    };
    await db.insert(
      'user_profile',
      profileToSave,
      conflictAlgorithm: ConflictAlgorithm.replace, // Se já existir, substitui
    );
    print("Perfil de ${userProfile['email']} salvo localmente.");
  }

  // Agora recebe o email do usuário para associar aos treinos
  Future<void> saveWorkouts(List<dynamic> workouts, String userEmail) async {
    final db = await database;
    final batch = db.batch();

    for (var workout in workouts) {
      batch.insert(
        'workouts',
        {
          'api_id': workout['id'],
          'user_email': userEmail, // Associa o treino ao usuário
          'workout_type': workout['workout_type'],
          'workout_date': workout['workout_date'],
          'duration_minutes': workout['duration_minutes'],
          'distance_km': workout['distance_km'],
          'details': jsonEncode(workout['details']),
          'to_be_deleted': 0,
          'synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    print("${workouts.length} treinos de $userEmail salvos localmente.");
  }

  // Salva ou atualiza uma cor customizada
  Future<void> saveWorkoutColor(String userEmail, String workoutTypeId, Color color) async {
    final db = await database;
    await db.insert(
      'workout_colors',
      {
        'user_email': userEmail,
        'workout_type_id': workoutTypeId,
        'color_value': color.toARGB32(), // Salva o valor inteiro da cor
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('Cor salva para $workoutTypeId: ${color.toARGB32()}');
  }

// Carrega todas as cores customizadas de um usuário
  Future<Map<String, Color>> loadWorkoutColors(String userEmail) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workout_colors',
      where: 'user_email = ?',
      whereArgs: [userEmail],
    );

    return {
      for (var map in maps)
        map['workout_type_id']: Color(map['color_value']),
    };
  }

  // Limpa todas as cores customizadas de um usuário
  Future<void> clearWorkoutColors(String userEmail) async {
    final db = await database;
    await db.delete(
      'workout_colors',
      where: 'user_email = ?',
      whereArgs: [userEmail],
    );
    print('Cores customizadas de $userEmail foram resetadas no banco de dados.');
  }
}