import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_controller.dart';

class FinishedScreen extends StatelessWidget {
  const FinishedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final outcome = game.gameOver?['outcome'] ?? 'UNKNOWN';
    final reason = game.gameOver?['reason'] ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              outcome == 'WIN'
                  ? Icons.emoji_events
                  : outcome == 'LOSE'
                      ? Icons.sentiment_dissatisfied
                      : Icons.handshake,
              size: 72,
              color: outcome == 'WIN' ? Colors.amber : Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              outcome,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text('Motivo: $reason'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => game.reset(),
              child: const Text('Nuova partita'),
            ),
          ],
        ),
      ),
    );
  }
}
