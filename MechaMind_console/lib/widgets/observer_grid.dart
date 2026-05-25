import 'package:flutter/material.dart';

import '../models/match_models.dart';

/// Tactical map showing both mechas (observer view).
class ObserverGrid extends StatelessWidget {
  const ObserverGrid({
    super.key,
    required this.mechas,
    this.gridSize = 100,
    this.cellSize = 10,
    this.padding = 8,
  });

  final List<MechaState> mechas;
  final int gridSize;
  final double cellSize;
  final int padding;

  @override
  Widget build(BuildContext context) {
    if (mechas.isEmpty) {
      return const Center(child: Text('Nessun mecha sulla mappa'));
    }

    final alive = mechas.where((m) => !m.destroyed).toList();
    final focus = alive.isNotEmpty ? alive : mechas;
    final centerX =
        focus.map((m) => m.x).reduce((a, b) => a + b) ~/ focus.length;
    final centerY =
        focus.map((m) => m.y).reduce((a, b) => a + b) ~/ focus.length;

    var viewRadius = 24;
    for (final m in mechas) {
      final dx = (m.x - centerX).abs();
      final dy = (m.y - centerY).abs();
      final dist = dx > dy ? dx : dy;
      if (dist + padding > viewRadius) viewRadius = dist + padding;
    }
    viewRadius = viewRadius.clamp(12, 40);

    final minX = (centerX - viewRadius).clamp(0, gridSize - 1);
    final maxX = (centerX + viewRadius).clamp(0, gridSize - 1);
    final minY = (centerY - viewRadius).clamp(0, gridSize - 1);
    final maxY = (centerY + viewRadius).clamp(0, gridSize - 1);
    final cols = maxX - minX + 1;
    final rows = maxY - minY + 1;
    final gridW = cols * cellSize;
    final gridH = rows * cellSize;

    final colors = [
      Colors.cyanAccent,
      Colors.orangeAccent,
    ];

    return Card(
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mappa ($minX,$minY)–($maxX,$maxY) · centro ($centerX,$centerY)',
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: gridW,
                    height: gridH,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisExtent: cellSize,
                      ),
                      itemCount: cols * rows,
                      itemBuilder: (context, index) {
                        final gx = minX + (index % cols);
                        final gy = minY + (index ~/ cols);
                        MechaState? occupant;
                        var colorIndex = 0;
                        for (var i = 0; i < mechas.length; i++) {
                          final m = mechas[i];
                          if (m.x == gx && m.y == gy) {
                            occupant = m;
                            colorIndex = i;
                            break;
                          }
                        }
                        return _Cell(
                          occupant: occupant,
                          color: colors[colorIndex % colors.length],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < mechas.length; i++)
                  _Legend(
                    color: colors[i % colors.length],
                    label: mechas[i].name,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.occupant, required this.color});

  final MechaState? occupant;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Color fill = const Color(0xFF1E293B);
    var alpha = 0.85;
    Color border = const Color(0xFF334155);

    if (occupant != null) {
      fill = occupant!.destroyed ? Colors.red.shade900 : color;
      alpha = occupant!.destroyed ? 0.6 : 1;
      border = Colors.white70;
    }

    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: fill.withValues(alpha: alpha),
        border: Border.all(color: border, width: occupant != null ? 1.5 : 0.5),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white24),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
