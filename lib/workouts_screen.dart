// lib/workouts_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:evorun/add_edit_workout_screen.dart';
import 'package:evorun/config.dart';
import 'package:evorun/database_helper.dart';
import 'package:evorun/workout_config.dart';

class WorkoutsScreen extends StatefulWidget {
  final String token;
  final VoidCallback onDataChanged;
  const WorkoutsScreen({super.key, required this.token, required this.onDataChanged});

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
    _fetchWorkoutsFromLocalDb();
  }

  // Esta função agora apenas lê os dados locais. A sincronização é feita em outro lugar.
  Future<void> _fetchWorkoutsFromLocalDb() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
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
                  MaterialPageRoute(builder: (context) => AddEditWorkoutScreen(workout: workout, selectedDate: _selectedDay!)),
                );
                _fetchWorkoutsFromLocalDb();
                widget.onDataChanged(); // Notifica o MainScaffold
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
              widget.onDataChanged(); // Notifica o MainScaffold
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
    final type = workout['workout_type'].toLowerCase();

    if (workout['duration_minutes'] != null) { parts.add('${workout['duration_minutes']} min'); }
    if (workout['distance_km'] != null) {
      if (type == 'swimming') {
        parts.add('${(workout['distance_km'] * 1000).toStringAsFixed(0)} m');
      } else {
        parts.add('${workout['distance_km']} km');
      }
    }
    if (type == 'weightlifting' && workout['details'] != null && workout['details']['weight_kg'] != null) {
      parts.add('Carga: ${workout['details']['weight_kg']} kg');
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
          _fetchWorkoutsFromLocalDb();
          widget.onDataChanged();
        },
        backgroundColor: Colors.amber[800],
        child: const Icon(Icons.add),
      ),
    );
  }
}