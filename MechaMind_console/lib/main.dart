import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/monitor_controller.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MechaMindConsoleApp());
}

class MechaMindConsoleApp extends StatelessWidget {
  const MechaMindConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MonitorController(),
      child: MaterialApp(
        title: 'MechaMind Console',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF020617),
        ),
        home: const _ConsoleShell(),
      ),
    );
  }
}

class _ConsoleShell extends StatelessWidget {
  const _ConsoleShell();

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MechaMind Console'),
        actions: [
          IconButton(
            onPressed: () {
              if (monitor.selectedMatchId != null) {
                monitor.clearMatchView();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              } else {
                monitor.refreshStatus();
              }
            },
            icon: Icon(
              monitor.selectedMatchId != null ? Icons.arrow_back : Icons.refresh,
            ),
            tooltip: monitor.selectedMatchId != null
                ? 'Torna alla lista'
                : 'Aggiorna stato',
          ),
        ],
      ),
      body: const HomeScreen(),
    );
  }
}
