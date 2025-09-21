// lib/workouts_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:evorun/add_edit_workout_screen.dart';
import 'package:evorun/config.dart';
import 'package:evorun/database_helper.dart';
import 'package:evorun/workout_config.dart'; // Importa nossa nova configuração central

class WorkoutsScreen extends StatefulWidget {
  final String token;
  const WorkoutsScreen({super.key, required this.token});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  bool _isLoading = true;
  List<dynamic> _workouts = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _filteredWorkouts = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    // 1. Carrega a UI imediatamente com os dados locais
    _fetchWorkoutsFromLocalDb();

    // 2. Inicia a sincronização em segundo plano
    _syncLocalChangesToServer();
  }

  Future<void> _fetchWorkoutsFromLocalDb() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    print('Carregando treinos do banco de dados local para exibição...');
    final localWorkouts = await DatabaseHelper().getWorkouts();

    if (mounted) {
      setState(() {
        _workouts = localWorkouts;
        _isLoading = false;
        _filterWorkoutsForSelectedDay();
      });
    }
  }

  Future<void> _syncLocalChangesToServer() async {
    print('Iniciando sincronização com o servidor...');

    // 1. Sincronizar exclusões
    final workoutsToDelete = await DatabaseHelper().getWorkoutsToDelete();
    for (var workout in workoutsToDelete) {
      if (workout['api_id'] != null) {
        final url = Uri.parse('http://$apiDomain/api/v1/workouts/${workout['api_id']}');
        try {
          final response = await http.delete(
            url,
            headers: {'Authorization': 'Bearer ${widget.token}'},
          );
          // SÓ DELETA LOCALMENTE SE O SERVIDOR CONFIRMAR (200, 204) OU SE JÁ NÃO EXISTIR LÁ (404)
          if (response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 404) {
            await DatabaseHelper().deleteWorkoutPermanently(workout['id']);
          }
          // Se for 401 (acesso negado) ou outro erro, NADA acontece localmente.
        } catch (e) {
          print('Sem conexão para deletar. Tentando na próxima vez.');
          break; // Para a sincronização se não houver conexão
        }
      } else {
        await DatabaseHelper().deleteWorkoutPermanently(workout['id']);
      }
    }

    // TODO: Sincronizar criações (POST) e atualizações (PUT)

    // 2. Sincronizar CRIAÇÕES
    final workoutsToCreate = await DatabaseHelper().getWorkoutsToCreate();
    for (var workout in workoutsToCreate) {
      final url = Uri.parse('http://$apiDomain/api/v1/workouts/');
      try {
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json; charset=UTF-8',
          },
          // O corpo precisa ser um mapa sem o 'id' local e com 'details' decodificado
          body: jsonEncode({
            'workout_type': workout['workout_type'],
            'workout_date': workout['workout_date'],
            'duration_minutes': workout['duration_minutes'],
            'distance_km': workout['distance_km'],
            'details': jsonDecode(workout['details']),
          }),
        );
        if (response.statusCode == 201) { // 201 Created
          final newApiWorkout = jsonDecode(response.body);
          await DatabaseHelper().updateApiIdAndMarkSynced(workout['id'], newApiWorkout['id']);
          print('Workout local ${workout['id']} criado no servidor com api_id ${newApiWorkout['id']}.');
        }
      } catch (e) { print('Sem conexão para criar. Tentando na próxima vez.'); break; }
    }

    // 3. Sincronizar ATUALIZAÇÕES
    final workoutsToUpdate = await DatabaseHelper().getWorkoutsToUpdate();
    for (var workout in workoutsToUpdate) {
      final url = Uri.parse('http://$apiDomain/api/v1/workouts/${workout['api_id']}');
      try {
        final response = await http.put(
          url,
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode({
            'workout_type': workout['workout_type'],
            'workout_date': workout['workout_date'],
            'duration_minutes': workout['duration_minutes'],
            'distance_km': workout['distance_km'],
            'details': jsonDecode(workout['details']),
          }),
        );
        if (response.statusCode == 200) { // 200 OK
          await DatabaseHelper().markWorkoutAsSynced(workout['id']);
          print('Workout ${workout['api_id']} atualizado no servidor.');
        }
      } catch (e) { print('Sem conexão para atualizar. Tentando na próxima vez.'); break; }
    }
    print('Sincronização finalizada.');
    // Após sincronizar, recarrega a lista para refletir quaisquer exclusões permanentes
    _fetchWorkoutsFromLocalDb();
  }

  Future<void> _fetchWorkouts() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    await _syncLocalChangesToServer();

    final localWorkouts = await DatabaseHelper().getWorkouts();
    if (mounted) {
      setState(() {
        _workouts = localWorkouts;
        _isLoading = false;
        _filterWorkoutsForSelectedDay();
      });
    }
  }

  void _filterWorkoutsForSelectedDay() {
    if (_selectedDay == null) return;
    setState(() {
      _filteredWorkouts = _workouts.where((workout) {
        final workoutDate = DateTime.parse(workout['workout_date']);
        return isSameDay(workoutDate, _selectedDay);
      }).toList();
    });
  }

  void _showWorkoutOptions(BuildContext context, Map<String, dynamic> workout) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditWorkoutScreen(workout: workout, selectedDate: _selectedDay!),
                  ),
                );
                _fetchWorkouts();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, workout['id']);
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, int workoutId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir este treino?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await DatabaseHelper().markWorkoutForDeletion(workoutId);
              setState(() {
                _workouts.removeWhere((w) => w['id'] == workoutId);
                _filteredWorkouts.removeWhere((w) => w['id'] == workoutId);
              });
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  List<dynamic> _getWorkoutsForDay(DateTime day) {
    return _workouts.where((w) => isSameDay(DateTime.parse(w['workout_date']), day)).toList();
  }

  String _buildSubtitle(Map<String, dynamic> workout) {
    final parts = <String>[];
    if (workout['duration_minutes'] != null) {
      parts.add('${workout['duration_minutes']} min');
    }
    if (workout['distance_km'] != null) {
      parts.add('${workout['distance_km']} km');
    }
    final type = workout['workout_type'].toLowerCase();
    if (workout['distance_km'] != null) {
      if (type == 'swimming') {
        // Converte km para metros para exibir
        parts.add('${(workout['distance_km'] * 1000).toStringAsFixed(0)} m');
      } else {
        parts.add('${workout['distance_km']} km');
      }
    }
    if (type == 'weightlifting') {
      if (workout['details'] != null && workout['details']['weight_kg'] != null) {
        parts.add('Carga: ${workout['details']['weight_kg']} kg');
      }
    }
    return parts.isNotEmpty ? parts.join(' | ') : 'Sem detalhes';
  }

  String _formatSelectedDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('EEEE, d MMMM y', 'pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TableCalendar(
            locale: 'pt_BR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const { CalendarFormat.month: 'Mês' },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _filterWorkoutsForSelectedDay();
              });
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            calendarBuilders: CalendarBuilders(
              selectedBuilder: (context, day, focusedDay) {
                final workoutsForDay = _getWorkoutsForDay(day);
                final colors = workoutsForDay.map((w) => getWorkoutInfo(w['workout_type']).color).toSet().toList();
                return Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blue[800]!, width: 2)),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: colors.length > 1 ? LinearGradient(colors: colors) : null, color: colors.length == 1 ? colors.first : null),
                    child: Text('${day.day}', style: TextStyle(color: colors.isNotEmpty ? Colors.white : Colors.black)),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                final workoutsForDay = _getWorkoutsForDay(day);
                if (workoutsForDay.isNotEmpty) {
                  final colors = workoutsForDay.map((w) => getWorkoutInfo(w['workout_type']).color).toSet().toList();
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: colors.length > 1 ? LinearGradient(colors: colors) : null, color: colors.length == 1 ? colors.first : null),
                    child: Text('${day.day}', style: TextStyle(color: colors.isNotEmpty ? Colors.white : Colors.black)),
                  );
                }
                return null;
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(_formatSelectedDate(_selectedDay), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredWorkouts.isEmpty
                ? const Center(child: Text('Nenhum treino para este dia.'))
                : ListView.builder(
              itemCount: _filteredWorkouts.length,
              itemBuilder: (context, index) {
                final workout = _filteredWorkouts[index];
                final workoutInfo = getWorkoutInfo(workout['workout_type']);
                return ListTile(
                  leading: Icon(workoutInfo.icon, color: workoutInfo.color),
                  title: Text(workoutInfo.displayName),
                  subtitle: Text(_buildSubtitle(workout)),
                  onTap: () => _showWorkoutOptions(context, workout),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditWorkoutScreen(selectedDate: _selectedDay ?? DateTime.now()),
            ),
          );
          _fetchWorkouts();
        },
        backgroundColor: Colors.amber[800],
        child: const Icon(Icons.add),
      ),
    );
  }
}