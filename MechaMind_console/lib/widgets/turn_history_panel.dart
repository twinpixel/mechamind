import 'package:flutter/material.dart';

import '../models/match_models.dart';

class TurnHistoryPanel extends StatelessWidget {
  const TurnHistoryPanel({
    super.key,
    required this.history,
    required this.nameForClient,
  });

  final List<TurnHistoryEntry> history;
  final String Function(String clientId) nameForClient;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nessun turno registrato ancora.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final reversed = history.reversed.toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              'Cronologia turni (${history.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: reversed.length,
              itemBuilder: (context, index) {
                final entry = reversed[index];
                return _TurnTile(
                  entry: entry,
                  nameForClient: nameForClient,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnTile extends StatelessWidget {
  const _TurnTile({
    required this.entry,
    required this.nameForClient,
  });

  final TurnHistoryEntry entry;
  final String Function(String clientId) nameForClient;

  @override
  Widget build(BuildContext context) {
    final clientIds = {
      ...entry.actions.keys,
      ...entry.results.keys,
    }.toList();

    return ListTile(
      dense: true,
      title: Text(
        'Turno ${entry.turn}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in clientIds)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${nameForClient(id)}: ${entry.describeAction(id)}'
                '${entry.describeResult(id).isEmpty ? '' : ' — ${entry.describeResult(id)}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
