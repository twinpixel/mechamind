import 'package:flutter/material.dart';

import '../models/match_models.dart';

class MechaStatsCard extends StatelessWidget {
  const MechaStatsCard({
    super.key,
    required this.mecha,
    required this.accent,
    this.isActiveTurn = false,
  });

  final MechaState mecha;
  final Color accent;
  final bool isActiveTurn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mecha.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActiveTurn)
                  const Chip(
                    label: Text('turno'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Color(0xFF14532D),
                    labelStyle: TextStyle(color: Colors.lightGreenAccent),
                  ),
                if (mecha.destroyed)
                  const Chip(
                    label: Text('KO'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Color(0xFF7F1D1D),
                    labelStyle: TextStyle(color: Colors.redAccent),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Posizione (${mecha.x}, ${mecha.y})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _Bar(
              label: 'Scafo',
              value: mecha.hull,
              max: mecha.hullMax,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 6),
            _Bar(
              label: 'Scudi',
              value: mecha.shields,
              max: mecha.shieldsMax,
              color: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text('$value / $max',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 6,
          backgroundColor: const Color(0xFF334155),
          color: color,
        ),
      ],
    );
  }
}
