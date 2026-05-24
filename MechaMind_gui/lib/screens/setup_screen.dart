import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_controller.dart';
import '../widgets/build_editor.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _serverUrlCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _authorCtrl;

  @override
  void initState() {
    super.initState();
    final game = context.read<GameController>();
    _serverUrlCtrl = TextEditingController(text: game.serverUrl);
    _nameCtrl = TextEditingController(text: game.mechaName);
    _authorCtrl = TextEditingController(text: game.author);
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _nameCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'MechaMind Pilot',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Connettiti via WebSocket, registra il mecha e pilotarlo in battaglia. '
          'Funziona su Web, macOS e desktop.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'http://127.0.0.1:3000',
                    helperText: 'WebSocket: ws://host:port/ws',
                  ),
                  controller: _serverUrlCtrl,
                  onChanged: (v) => game.serverUrl = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Nome mecha'),
                  controller: _nameCtrl,
                  onChanged: (v) => game.mechaName = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Autore'),
                  controller: _authorCtrl,
                  onChanged: (v) => game.author = v,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        BuildEditor(
          mechaBuild: game.build,
          onChanged: game.updateBuild,
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Ogni turno ha 3 minuti per default. Per cambiare il limite, '
              'avvia il server con TURN_TIMEOUT_MS=300000 (5 min) o simile.',
            ),
          ),
        ),
        if (game.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            game.errorMessage!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: game.build.isValid ? () => game.register() : null,
          icon: const Icon(Icons.link),
          label: const Text('Connetti e registra'),
        ),
      ],
    );
  }
}
