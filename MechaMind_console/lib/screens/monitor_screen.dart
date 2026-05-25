import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_models.dart';
import '../providers/monitor_controller.dart';
import '../widgets/mecha_stats_card.dart';
import '../widgets/observer_grid.dart';
import '../widgets/turn_history_panel.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorController>();
    final snapshot = monitor.snapshot;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) monitor.clearMatchView();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            snapshot != null
                ? 'Partita · turno ${snapshot.turn}'
                : 'Monitor partita',
          ),
          actions: [
            IconButton(
              onPressed: monitor.refreshMatch,
              icon: const Icon(Icons.refresh),
              tooltip: 'Aggiorna',
            ),
          ],
        ),
        body: _buildBody(context, monitor),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MonitorController monitor) {
    if (monitor.loading && monitor.snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (monitor.error != null && monitor.snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(monitor.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: monitor.refreshMatch,
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = monitor.snapshot;
    if (snapshot == null) {
      return const Center(child: Text('Nessun dato partita'));
    }

    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _MapSection(snapshot: snapshot)),
          Expanded(
            flex: 2,
            child: _SidePanel(
              snapshot: snapshot,
              history: monitor.history,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: _MapSection(snapshot: snapshot),
        ),
        Expanded(
          child: _SidePanel(
            snapshot: snapshot,
            history: monitor.history,
          ),
        ),
      ],
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.snapshot});

  final MatchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MatchHeader(snapshot: snapshot),
          const SizedBox(height: 8),
          Expanded(
            child: ObserverGrid(mechas: snapshot.clients),
          ),
        ],
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.snapshot});

  final MatchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = snapshot.isRunning
        ? 'In corso'
        : 'Terminata (${snapshot.endReason ?? '—'})';

    String? winnerLabel;
    if (!snapshot.isRunning && snapshot.winnerId != null) {
      winnerLabel = snapshot.nameFor(snapshot.winnerId!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          statusLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            color: snapshot.isRunning
                ? Colors.lightGreenAccent
                : Colors.blueGrey,
          ),
        ),
        if (winnerLabel != null)
          Text('Vincitore: $winnerLabel', style: theme.textTheme.bodyMedium),
        Text(
          'ID: ${snapshot.id}',
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.snapshot,
    required this.history,
  });

  final MatchSnapshot snapshot;
  final List<TurnHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.cyanAccent, Colors.orangeAccent];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < snapshot.clients.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MechaStatsCard(
                mecha: snapshot.clients[i],
                accent: colors[i % colors.length],
                isActiveTurn: false,
              ),
            ),
          Expanded(
            child: TurnHistoryPanel(
              history: history,
              nameForClient: (id) => snapshot.nameFor(id) ?? id,
            ),
          ),
        ],
      ),
    );
  }
}
