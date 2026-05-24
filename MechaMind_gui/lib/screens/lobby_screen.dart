import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_controller.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              game.matchId != null
                  ? 'In lobby — avversario trovato, avvio partita...'
                  : 'In lobby — in attesa di un avversario',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Client ID: ${game.clientId ?? '-'}'),
            if (game.matchId != null)
              Text('Partita: ${game.matchId}'),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => game.reset(),
              child: const Text('Annulla'),
            ),
          ],
        ),
      ),
    );
  }
}
