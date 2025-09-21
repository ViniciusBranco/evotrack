// lib/main_scaffold.dart
import 'package:flutter/material.dart';

import 'package:evorun/login_screen.dart';
import 'package:evorun/workouts_screen.dart';
import 'package:evorun/add_edit_workout_screen.dart';


class MainScaffold extends StatefulWidget {
  final String token;
  const MainScaffold({super.key, required this.token});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Inicializa a lista de páginas aqui, passando o token para a WorkoutsScreen
    _pages = <Widget>[
      const Center(child: Text('Tela de Início')),
      WorkoutsScreen(token: widget.token), // Passe o token aqui
      const Center(child: Text('Tela de Relatórios')),
      const Center(child: Text('Tela de Perfil')),
    ];
  }

  void _onItemTapped(int index) {
    // O índice 4 é o botão 'Sair' (último da lista)
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('EvoRun'),
        backgroundColor: Colors.blue[800],
        automaticallyImplyLeading: false,
      ),
      // O corpo da tela agora mostra a página selecionada da nossa lista
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Treinos'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Relatórios'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sair'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigoAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}