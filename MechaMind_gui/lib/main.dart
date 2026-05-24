import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/game_controller.dart';
import 'screens/battle_screen.dart';
import 'screens/finished_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/setup_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameController(),
      child: const MechaMindApp(),
    ),
  );
}

class MechaMindApp extends StatelessWidget {
  const MechaMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechaMind Pilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF020617),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();

    Widget body;
    switch (game.phase) {
      case PilotPhase.setup:
        body = const SetupScreen();
      case PilotPhase.lobby:
        body = const LobbyScreen();
      case PilotPhase.battle:
        body = const BattleScreen();
      case PilotPhase.finished:
        body = const FinishedScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MechaMind Pilot'),
        actions: [
          if (game.phase != PilotPhase.setup)
            IconButton(
              onPressed: () => game.reset(),
              icon: const Icon(Icons.logout),
              tooltip: 'Esci',
            ),
        ],
      ),
      body: body,
    );
  }
}
