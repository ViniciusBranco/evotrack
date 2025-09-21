// lib/main_scaffold.dart
import 'dart:convert';
import 'package:evorun/config.dart';
import 'package:evorun/configuracoes_screen.dart';
import 'package:evorun/database_helper.dart';
import 'package:evorun/login_screen.dart';
import 'package:evorun/perfil_screen.dart';
import 'package:evorun/workouts_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MainScaffold extends StatefulWidget {
  final String token;
  final String userEmail;
  const MainScaffold({super.key, required this.token, required this.userEmail});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  bool _hasUnsyncedChanges = false;
  bool _isSyncing = false;

  @override
  @override
  void initState() {
    super.initState();
    _checkForUnsyncedChanges();
  }

  Future<void> _checkForUnsyncedChanges() async {
    final hasChanges = await DatabaseHelper().hasUnsyncedChanges();
    if (mounted) {
      setState(() {
        _hasUnsyncedChanges = hasChanges;
      });
    }
  }

  Future<void> _syncLocalChangesToServer() async {
    if (_isSyncing) return;
    if (mounted) setState(() { _isSyncing = true; });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronizando...')));

    bool hadSuccess = true;
    bool isOffline = false;

    try {
      // 1. Sincronizar exclusões
      final workoutsToDelete = await DatabaseHelper().getWorkoutsToDelete();
      for (var workout in workoutsToDelete) {
        if (workout['api_id'] != null) {
          final url = Uri.parse('http://$apiDomain/api/v1/workouts/${workout['api_id']}');
          final response = await http.delete(url, headers: {'Authorization': 'Bearer ${widget.token}'});
          if (response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 404) {
            await DatabaseHelper().deleteWorkoutPermanently(workout['id']);
          } else {
            hadSuccess = false;
          }
        } else {
          await DatabaseHelper().deleteWorkoutPermanently(workout['id']);
        }
      }

      // 2. Sincronizar criações
      final workoutsToCreate = await DatabaseHelper().getWorkoutsToCreate();
      for (var workout in workoutsToCreate) {
        final url = Uri.parse('http://$apiDomain/api/v1/workouts/');
        final response = await http.post(
          url,
          headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            'workout_type': workout['workout_type'], 'workout_date': workout['workout_date'],
            'duration_minutes': workout['duration_minutes'], 'distance_km': workout['distance_km'],
            'details': jsonDecode(workout['details']),
          }),
        );
        if (response.statusCode == 201) {
          final newApiWorkout = jsonDecode(response.body);
          await DatabaseHelper().updateApiIdAndMarkSynced(workout['id'], newApiWorkout['id']);
        } else {
          hadSuccess = false;
          print('Erro ao criar treino ${workout['id']}: Status ${response.statusCode} - ${response.body}');
        }
      }

      // 3. Sincronizar atualizações
      final workoutsToUpdate = await DatabaseHelper().getWorkoutsToUpdate();
      for (var workout in workoutsToUpdate) {
        final url = Uri.parse('http://$apiDomain/api/v1/workouts/${workout['api_id']}');
        final response = await http.put(
          url,
          headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            'workout_type': workout['workout_type'], 'workout_date': workout['workout_date'],
            'duration_minutes': workout['duration_minutes'], 'distance_km': workout['distance_km'],
            'details': jsonDecode(workout['details']),
          }),
        );
        if (response.statusCode == 200) {
          await DatabaseHelper().markWorkoutAsSynced(workout['id']);
        } else {
          hadSuccess = false;
          print('Erro ao atualizar treino ${workout['id']}: Status ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      hadSuccess = false;
      isOffline = true;
      print('Erro de conexão durante a sincronização: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      if (isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servidor offline. Tente mais tarde.'), backgroundColor: Colors.orange));
      } else if (hadSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados sincronizados com sucesso!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alguns dados não puderam ser sincronizados.'), backgroundColor: Colors.red));
      }

      setState(() { _isSyncing = false; });
      _checkForUnsyncedChanges();
    }
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // A lista de páginas é criada AQUI DENTRO do build.
    final List<Widget> pages = <Widget>[
      const Center(child: Text('Tela de Início')),
      WorkoutsScreen(token: widget.token, userEmail: widget.userEmail, onDataChanged: _checkForUnsyncedChanges),
      const Center(child: Text('Tela de Relatórios')),
      PerfilScreen(
        onSync: _syncLocalChangesToServer,
        hasUnsyncedChanges: _hasUnsyncedChanges,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('EvoTrack'), backgroundColor: Colors.blue[800], automaticallyImplyLeading: false),
      // E usada AQUI com o nome correto 'pages' (sem underscore)
      body: pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          const BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Treinos'),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Relatórios'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                const Icon(Icons.person),
                if (_hasUnsyncedChanges)
                  Positioned(
                    top: -2, right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                      constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                    ),
                  )
              ],
            ),
            label: 'Perfil',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sair'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
