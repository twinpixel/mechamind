import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_action.dart';
import '../providers/game_controller.dart';

class ActionPanel extends StatefulWidget {
  const ActionPanel({super.key});

  @override
  State<ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends State<ActionPanel> {
  int _energy = 1;
  int _dx = 0;
  int _dy = 0;
  int? _boundTurn;
  Timer? _countdownTimer;
  DateTime? _trackedDeadline;

  int _componentMax(String action, dynamic vehicle) {
    final build = vehicle.build as Map<String, int>;
    switch (action) {
      case 'SCAN':
        return build['radar'] ?? 10;
      case 'FIRE':
        return build['cannon'] ?? 18;
      case 'MOVE':
        return build['propulsion'] ?? 12;
      default:
        return vehicle.energy as int;
    }
  }

  int _energyLimit(String action, dynamic vehicle) {
    final pool = vehicle.energy as int;
    if (action == 'IDLE') return pool;
    final cap = _componentMax(action, vehicle);
    return pool < cap ? pool : cap;
  }

  void _syncTurnEnergy(int turn, dynamic vehicle, GameController game) {
    if (_boundTurn == turn) return;
    _boundTurn = turn;
    final limit = _energyLimit(game.selectedAction, vehicle);
    _energy = limit > 0 ? limit.clamp(1, limit) : 0;
    if (game.selectedAction == 'SCAN') {
      game.setScanPreviewRadius(_energy);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _syncCountdown(DateTime? deadline) {
    if (deadline == _trackedDeadline) return;
    _trackedDeadline = deadline;
    _countdownTimer?.cancel();
    if (deadline == null) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  String _formatRemaining(Duration remaining) {
    final totalSeconds = remaining.inSeconds.clamp(0, 999999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _clampEnergyForAction(String action, dynamic vehicle) {
    final limit = _energyLimit(action, vehicle);
    if (_energy > limit) _energy = limit > 0 ? limit : 0;
    if (_energy < 1 && action != 'IDLE') _energy = 1;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final pending = game.pendingAction;
    final action = game.selectedAction;

    if (pending == null) {
      _syncCountdown(null);
      return _SidebarShell(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 16),
                Text(
                  game.lastScan?['pending'] == true
                      ? 'Scan inviato — attendi l\'avversario...'
                      : 'Turno avversario — attendi...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final v = pending.vehicle;
    _syncTurnEnergy(pending.turn, v, game);
    _clampEnergyForAction(action, v);
    final actionLimit = _energyLimit(action, v);
    final deadline = game.actionDeadline;
    _syncCountdown(deadline);
    final remaining = deadline != null
        ? deadline.difference(DateTime.now())
        : Duration.zero;
    final isUrgent = remaining.inSeconds <= 30 && remaining.inSeconds > 0;

    return _SidebarShell(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Comandi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Turno ${pending.turn}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (deadline != null)
                  Text(
                    remaining.isNegative
                        ? 'SCADUTO'
                        : _formatRemaining(remaining),
                    style: TextStyle(
                      color: isUrgent || remaining.isNegative
                          ? Colors.orangeAccent
                          : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'SCAN', label: Text('SCAN')),
                ButtonSegment(value: 'FIRE', label: Text('FIRE')),
                ButtonSegment(value: 'MOVE', label: Text('MOVE')),
                ButtonSegment(value: 'IDLE', label: Text('IDLE')),
              ],
              selected: {action},
              onSelectionChanged: (s) {
                final picked = s.first;
                game.setSelectedAction(picked);
                setState(() => _clampEnergyForAction(picked, v));
                if (picked == 'SCAN') {
                  game.setScanPreviewRadius(_energy);
                }
              },
            ),
            const SizedBox(height: 12),
            if (action == 'SCAN') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C4A6E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.lightBlueAccent),
                ),
                child: Text(
                  'Centro: (${game.scanTargetX ?? v.x}, ${game.scanTargetY ?? v.y})\n'
                  'Raggio: $_energy (max ${game.radarMax})\n'
                  'Tocca la mappa a sinistra',
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Energia / raggio: $_energy'),
              Slider(
                value: _energy
                    .clamp(1, actionLimit > 0 ? actionLimit : 1)
                    .toDouble(),
                min: 1,
                max: (actionLimit > 0 ? actionLimit : 1).toDouble(),
                divisions: actionLimit > 1 ? actionLimit - 1 : 1,
                label: 'raggio $_energy',
                onChanged: (val) {
                  setState(() => _energy = val.round());
                  game.setScanPreviewRadius(_energy);
                },
              ),
            ],
            if (action == 'FIRE') ...[
              Text(
                'Bersaglio: (${game.fireTargetX ?? '-'}, ${game.fireTargetY ?? '-'})',
              ),
              const SizedBox(height: 8),
              Text('Energia: $_energy / $actionLimit'),
              Slider(
                value: _energy
                    .clamp(1, actionLimit > 0 ? actionLimit : 1)
                    .toDouble(),
                min: 1,
                max: (actionLimit > 0 ? actionLimit : 1).toDouble(),
                divisions: actionLimit > 1 ? actionLimit - 1 : 1,
                onChanged: (val) => setState(() => _energy = val.round()),
              ),
            ],
            if (action == 'MOVE') ...[
              Text('Energia: $_energy / $actionLimit'),
              Slider(
                value: _energy
                    .clamp(1, actionLimit > 0 ? actionLimit : 1)
                    .toDouble(),
                min: 1,
                max: (actionLimit > 0 ? actionLimit : 1).toDouble(),
                divisions: actionLimit > 1 ? actionLimit - 1 : 1,
                onChanged: (val) => setState(() => _energy = val.round()),
              ),
              TextFormField(
                initialValue: '$_dx',
                decoration: const InputDecoration(labelText: 'dx'),
                keyboardType: TextInputType.number,
                onChanged: (t) => _dx = int.tryParse(t) ?? 0,
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: '$_dy',
                decoration: const InputDecoration(labelText: 'dy'),
                keyboardType: TextInputType.number,
                onChanged: (t) => _dy = int.tryParse(t) ?? 0,
              ),
              const SizedBox(height: 4),
              Text(
                '|dx|+|dy| <= $_energy (attuale: ${_dx.abs() + _dy.abs()})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _submit(game, v),
              icon: const Icon(Icons.send),
              label: Text('Esegui $action'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(GameController game, dynamic vehicle) {
    final action = game.selectedAction;
    GameAction gameAction;
    int? scanSx;
    int? scanSy;

    switch (action) {
      case 'MOVE':
        gameAction = GameAction.move(energy: _energy, dx: _dx, dy: _dy);
      case 'FIRE':
        final tx = game.fireTargetX ?? vehicle.x as int;
        final ty = game.fireTargetY ?? vehicle.y as int;
        gameAction = GameAction.fire(
          energy: _energy,
          targetX: tx,
          targetY: ty,
        );
      case 'SCAN':
        scanSx = game.scanTargetX ?? vehicle.x as int;
        scanSy = game.scanTargetY ?? vehicle.y as int;
        gameAction = GameAction.scan(
          energy: _energy,
          scanX: scanSx,
          scanY: scanSy,
        );
      default:
        gameAction = GameAction.idle();
    }
    game.submitAction(gameAction);

    if (action == 'SCAN' && context.mounted && scanSx != null && scanSy != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scan inviato — area ($scanSx, $scanSy) raggio $_energy',
          ),
          backgroundColor: const Color(0xFF0C4A6E),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _SidebarShell extends StatelessWidget {
  const _SidebarShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F172A),
      child: child,
    );
  }
}
