// lib/add_edit_workout_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:evorun/database_helper.dart';
import 'package:evorun/workout_config.dart';

class AddEditWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic>? workout;
  final DateTime selectedDate;
  final String userEmail;

  const AddEditWorkoutScreen({super.key, this.workout, required this.selectedDate, required this.userEmail});

  @override
  State<AddEditWorkoutScreen> createState() => _AddEditWorkoutScreenState();
}

class _AddEditWorkoutScreenState extends State<AddEditWorkoutScreen> {
  late DateTime _dateForWorkout;
  String? _selectedWorkoutType;
  final List<String> _workoutDisplayNames = WorkoutVisualsService().getAllConfigs().values.map((info) => info.displayName).toList();

  final _durationController = TextEditingController();
  final _distanceController = TextEditingController();
  final _exerciseNameController = TextEditingController();
  final _weightController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController(); // Controller que faltava

  bool get isEditing => widget.workout != null;

  @override
  void initState() {
    super.initState();
    _dateForWorkout = widget.selectedDate;
    if (isEditing) {
      final workout = widget.workout!;
      _dateForWorkout = DateTime.parse(workout['workout_date']);
      _selectedWorkoutType = WorkoutVisualsService().getInfo(workout['workout_type']).displayName;
      _durationController.text = workout['duration_minutes']?.toString() ?? '';
      _distanceController.text = workout['distance_km']?.toString() ?? '';
      if (workout['details'] != null) {
        _exerciseNameController.text = workout['details']['exercise'] ?? '';
        _weightController.text = workout['details']['weight_kg']?.toString() ?? '';
        _setsController.text = workout['details']['sets']?.toString() ?? '';
        _repsController.text = workout['details']['reps']?.toString() ?? '';
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateForWorkout,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _dateForWorkout) {
      setState(() {
        _dateForWorkout = picked;
      });
    }
  }

  Future<void> _saveWorkout() async {
    if (_selectedWorkoutType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione um tipo de treino.'), backgroundColor: Colors.red));
      return;
    }

    final apiName = WorkoutVisualsService().getAllConfigs().values.firstWhere((info) => info.displayName == _selectedWorkoutType).apiName;
    final details = <String, dynamic>{};

    if (apiName == 'weightlifting') {
      details['exercise'] = _exerciseNameController.text.isNotEmpty ? _exerciseNameController.text : 'Musculação';
      details['sets'] = int.tryParse(_setsController.text) ?? 0;
      details['reps'] = int.tryParse(_repsController.text) ?? 0;
      details['weight_kg'] = double.tryParse(_weightController.text) ?? 0.0;
    }

    final distance = double.tryParse(_distanceController.text);
    final workoutData = {
      'user_email': widget.userEmail,
      'workout_type': apiName,
      'workout_date': _dateForWorkout.toIso8601String(),
      'duration_minutes': int.tryParse(_durationController.text),
      'distance_km': _selectedWorkoutType == 'Natação' ? (distance != null ? distance / 1000 : null) : distance,
      'details': jsonEncode(details),
    };

    if (isEditing) {
      await DatabaseHelper().updateWorkout(widget.workout!['id'], workoutData);
    } else {
      await DatabaseHelper().createWorkout(workoutData);
    }

    if(mounted) Navigator.pop(context);
  }

  // ===============================================================
  // O MÉTODO BUILD QUE ESTAVA FALTANDO COMEÇA AQUI
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Treino' : 'Adicionar Treino'),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Data do Treino'),
              subtitle: Text(DateFormat('EEEE, d MMMM y', 'pt_BR').format(_dateForWorkout)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
            ),
            const Divider(),
            DropdownButtonFormField<String>(
              value: _selectedWorkoutType,
              hint: const Text('Selecione o tipo de treino'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (String? newValue) => setState(() => _selectedWorkoutType = newValue),
              items: _workoutDisplayNames.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedWorkoutType == 'Corrida' || _selectedWorkoutType == 'Ciclismo' || _selectedWorkoutType == 'Natação')
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(
                  controller: _distanceController,
                  decoration: InputDecoration(labelText: _selectedWorkoutType == 'Natação' ? 'Distância (m)' : 'Distância (km)'),
                  keyboardType: TextInputType.number,
                ),
              ),
            if (_selectedWorkoutType == 'Musculação') ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(controller: _exerciseNameController, decoration: const InputDecoration(labelText: 'Nome do Treino (Ex: Treino A)')),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: _setsController, decoration: const InputDecoration(labelText: 'Séries'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(child: TextField(controller: _repsController, decoration: const InputDecoration(labelText: 'Repetições'), keyboardType: TextInputType.number)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(controller: _weightController, decoration: const InputDecoration(labelText: 'Carga Total (kg)'), keyboardType: TextInputType.number),
              ),
            ],
            TextField(controller: _durationController, decoration: const InputDecoration(labelText: 'Duração (min)'), keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saveWorkout, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Salvar Treino')),
          ],
        ),
      ),
    );
  }
}