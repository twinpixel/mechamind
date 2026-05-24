import 'package:flutter/material.dart';

import '../models/mecha_build.dart';

class BuildEditor extends StatelessWidget {
  const BuildEditor({
    super.key,
    required this.mechaBuild,
    required this.onChanged,
  });

  final MechaBuild mechaBuild;
  final ValueChanged<MechaBuild> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valid = mechaBuild.isValid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mecha Build', style: theme.textTheme.titleMedium),
                Text(
                  '${mechaBuild.sum} / ${MechaBuild.totalPoints} pts',
                  style: TextStyle(
                    color: valid ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _slider('Generatore', mechaBuild.generator, (v) {
              onChanged(mechaBuild.copyWith(generator: v.round()));
            }),
            _slider('Corazza', mechaBuild.hull, (v) {
              onChanged(mechaBuild.copyWith(hull: v.round()));
            }),
            _slider('Scudi', mechaBuild.shields, (v) {
              onChanged(mechaBuild.copyWith(shields: v.round()));
            }),
            _slider('Cannone', mechaBuild.cannon, (v) {
              onChanged(mechaBuild.copyWith(cannon: v.round()));
            }),
            _slider('Propulsione', mechaBuild.propulsion, (v) {
              onChanged(mechaBuild.copyWith(propulsion: v.round()));
            }),
            _slider('Radar', mechaBuild.radar, (v) {
              onChanged(mechaBuild.copyWith(radar: v.round()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, int value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value'),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: MechaBuild.minStat.toDouble(),
          max: MechaBuild.maxStat.toDouble(),
          divisions: MechaBuild.maxStat - MechaBuild.minStat,
          label: '$value',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
