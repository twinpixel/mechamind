import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_models.dart';
import '../providers/monitor_controller.dart';
import 'monitor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _urlController;
  final _matchIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final monitor = context.read<MonitorController>();
    _urlController = TextEditingController(text: monitor.baseUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      monitor.connect();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _matchIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorController>();
    final status = monitor.status;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ServerCard(
          urlController: _urlController,
          matchIdController: _matchIdController,
          onApplyUrl: () {
            monitor.setBaseUrl(_urlController.text);
            monitor.connect();
          },
          onOpenById: () {
            final id = _matchIdController.text.trim();
            if (id.isEmpty) return;
            _openMatch(context, id);
          },
        ),
        if (monitor.error != null) ...[
          const SizedBox(height: 12),
          MaterialBanner(
            content: Text(monitor.error!),
            leading: const Icon(Icons.error_outline, color: Colors.redAccent),
            backgroundColor: const Color(0xFF450A0A),
            actions: [
              TextButton(
                onPressed: monitor.refreshStatus,
                child: const Text('Riprova'),
              ),
            ],
          ),
        ],
        if (status != null) ...[
          const SizedBox(height: 16),
          _StatusOverview(status: status, polling: monitor.polling),
        ],
        const SizedBox(height: 16),
        Text('Partite attive', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (status == null && monitor.error == null)
          const Center(child: CircularProgressIndicator())
        else if (status != null && status.matches.isEmpty)
          Text(
            'Nessuna partita in corso. Avvia due piloti (GUI, robot o MCP).',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...status!.matches.map(
            (m) => _MatchListTile(
              summary: m,
              onTap: () => _openMatch(context, m.id),
            ),
          ),
        if (status?.lastFinishedMatch != null) ...[
          const SizedBox(height: 20),
          Text(
            'Ultima partita conclusa',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _MatchListTile(
            summary: status!.lastFinishedMatch!,
            onTap: () => _openMatch(context, status.lastFinishedMatch!.id),
          ),
        ],
        if (status != null && status.lobby.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Lobby', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...status.lobby.map(
            (c) => ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: Text(c.name),
              subtitle: Text(c.clientId),
            ),
          ),
        ],
      ],
    );
  }

  void _openMatch(BuildContext context, String matchId) {
    context.read<MonitorController>().startMatchPolling(matchId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MonitorScreen()),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.urlController,
    required this.matchIdController,
    required this.onApplyUrl,
    required this.onOpenById,
  });

  final TextEditingController urlController;
  final TextEditingController matchIdController;
  final VoidCallback onApplyUrl;
  final VoidCallback onOpenById;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Server MechaMind',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL base',
                hintText: 'http://127.0.0.1:3000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => onApplyUrl(),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onApplyUrl,
              icon: const Icon(Icons.link),
              label: const Text('Connetti / aggiorna'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: matchIdController,
              decoration: const InputDecoration(
                labelText: 'ID partita (opzionale)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => onOpenById(),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onOpenById,
              icon: const Icon(Icons.visibility),
              label: const Text('Monitora per ID'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOverview extends StatelessWidget {
  const _StatusOverview({required this.status, required this.polling});

  final ServerStatus status;
  final bool polling;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          icon: Icons.schedule,
          label: 'Uptime',
          value: status.uptimeLabel,
        ),
        _StatChip(
          icon: Icons.people,
          label: 'Lobby',
          value: '${status.lobbyCount}',
        ),
        _StatChip(
          icon: Icons.sports_martial_arts,
          label: 'Partite attive',
          value: '${status.activeMatches}',
        ),
        _StatChip(
          icon: Icons.wifi,
          label: 'Connessi',
          value: '${status.connectedClients}/${status.registeredClients}',
        ),
        if (polling)
          const Chip(
            avatar: Icon(Icons.sync, size: 16),
            label: Text('Live'),
            backgroundColor: Color(0xFF14532D),
            labelStyle: TextStyle(color: Colors.lightGreenAccent),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
    );
  }
}

class _MatchListTile extends StatelessWidget {
  const _MatchListTile({required this.summary, required this.onTap});

  final MatchSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = summary.isRunning
        ? Colors.lightGreenAccent
        : Colors.blueGrey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            summary.isRunning ? Icons.play_circle : Icons.flag,
            color: statusColor,
          ),
        ),
        title: Text(summary.clientNames),
        subtitle: Text(
          '${summary.status} · turno ${summary.turn} · ${summary.shortId}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
