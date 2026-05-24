import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_controller.dart';
import '../widgets/action_panel.dart';
import '../widgets/battle_grid.dart';
import '../widgets/scan_feedback_banner.dart';

/// Fixed width for the command sidebar (map keeps the rest).
const kBattleSidebarWidth = 320.0;

class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final vehicle = game.currentVehicle ?? game.pendingAction?.vehicle;
    final lastScan = game.lastScan;
    final overlay = game.scanOverlay;

    if (vehicle == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Caricamento partita...'),
          ],
        ),
      );
    }

    final scanFoundX =
        lastScan != null && lastScan['found'] == true && lastScan['pending'] != true
            ? (lastScan['x'] as num?)?.toInt()
            : null;
    final scanFoundY =
        lastScan != null && lastScan['found'] == true && lastScan['pending'] != true
            ? (lastScan['y'] as num?)?.toInt()
            : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;

        if (narrow) {
          return _NarrowLayout(
            game: game,
            vehicle: vehicle,
            lastScan: lastScan,
            scanFoundX: scanFoundX,
            scanFoundY: scanFoundY,
            overlay: overlay,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _MapColumn(
                game: game,
                vehicle: vehicle,
                lastScan: lastScan,
                scanFoundX: scanFoundX,
                scanFoundY: scanFoundY,
                overlay: overlay,
              ),
            ),
            const VerticalDivider(width: 1),
            const SizedBox(
              width: kBattleSidebarWidth,
              child: ActionPanel(),
            ),
          ],
        );
      },
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.game,
    required this.vehicle,
    required this.lastScan,
    required this.scanFoundX,
    required this.scanFoundY,
    required this.overlay,
  });

  final GameController game;
  final dynamic vehicle;
  final Map<String, dynamic>? lastScan;
  final int? scanFoundX;
  final int? scanFoundY;
  final ({int? cx, int? cy, int? radius, bool preview}) overlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _MapColumn(
            game: game,
            vehicle: vehicle,
            lastScan: lastScan,
            scanFoundX: scanFoundX,
            scanFoundY: scanFoundY,
            overlay: overlay,
          ),
        ),
        const SizedBox(
          height: 280,
          child: ActionPanel(),
        ),
      ],
    );
  }
}

class _MapColumn extends StatelessWidget {
  const _MapColumn({
    required this.game,
    required this.vehicle,
    required this.lastScan,
    required this.scanFoundX,
    required this.scanFoundY,
    required this.overlay,
  });

  final GameController game;
  final dynamic vehicle;
  final Map<String, dynamic>? lastScan;
  final int? scanFoundX;
  final int? scanFoundY;
  final ({int? cx, int? cy, int? radius, bool preview}) overlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBar(
            vehicle: vehicle,
            turn: game.pendingAction?.turn ?? game.matchTurn,
            awaiting: game.awaitingAction,
            fireFeedback: game.lastFireFeedback,
          ),
          if (lastScan != null) ...[
            const SizedBox(height: 6),
            ScanFeedbackBanner(
              scan: lastScan!,
              playerX: vehicle.x,
              playerY: vehicle.y,
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: BattleGrid(
              playerX: vehicle.x,
              playerY: vehicle.y,
              scanX: scanFoundX,
              scanY: scanFoundY,
              scanCenterX: overlay.cx,
              scanCenterY: overlay.cy,
              scanRadius: overlay.radius,
              highlightScan: overlay.cx != null && overlay.radius != null,
              fireX: game.selectedAction == 'FIRE' ? game.fireTargetX : null,
              fireY: game.selectedAction == 'FIRE' ? game.fireTargetY : null,
              onCellTap: game.awaitingAction
                  ? (x, y) {
                      if (game.selectedAction == 'FIRE') {
                        game.setFireTarget(x, y);
                      } else {
                        game.setScanTarget(x, y);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.vehicle,
    this.turn,
    required this.awaiting,
    this.fireFeedback,
  });

  final dynamic vehicle;
  final int? turn;
  final bool awaiting;
  final Map<String, dynamic>? fireFeedback;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: awaiting ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (awaiting)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'È il tuo turno — comandi a destra',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.lightBlueAccent,
                      ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (turn != null) Chip(label: Text('T$turn')),
                Chip(label: Text('(${vehicle.x},${vehicle.y})')),
                Chip(label: Text('HP ${vehicle.hull}/${vehicle.hullMax}')),
                Chip(label: Text('E ${vehicle.energy}')),
                Chip(label: Text('R ${vehicle.build['radar'] ?? '?'}')),
                if (fireFeedback != null)
                  Chip(
                    avatar: Icon(
                      fireFeedback!['hit'] == true
                          ? Icons.check_circle
                          : Icons.close,
                      size: 16,
                      color: fireFeedback!['hit'] == true
                          ? Colors.greenAccent
                          : Colors.white54,
                    ),
                    label: Text(
                      fireFeedback!['hit'] == true
                          ? 'Colpo!'
                          : 'Mancato d${fireFeedback!['distance']}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
