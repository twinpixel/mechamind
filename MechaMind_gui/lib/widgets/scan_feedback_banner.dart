import 'package:flutter/material.dart';

/// Prominent banner for the latest scan result or pending scan.
class ScanFeedbackBanner extends StatelessWidget {
  const ScanFeedbackBanner({
    super.key,
    required this.scan,
    this.playerX,
    this.playerY,
  });

  final Map<String, dynamic> scan;
  final int? playerX;
  final int? playerY;

  /// Cells inside a Manhattan (diamond) radius.
  static int _diamondCellCount(int radius) =>
      radius <= 0 ? 1 : 2 * radius * (radius + 1) + 1;

  String? _tacticalLine(int radius) {
    final sx = (scan['scan_x'] as num?)?.toInt();
    final sy = (scan['scan_y'] as num?)?.toInt();
    if (sx == null || sy == null || radius <= 0) return null;

    final cells = _diamondCellCount(radius);
    final onSelf = playerX == sx && playerY == sy;
    final onMapNote = onSelf
        ? 'Rombo blu centrato su di te — copre ~$cells celle (r=$radius)'
        : 'Rombo blu su $sx,$sy — ~$cells celle (r=$radius)';

    if (scan['found'] == true || scan['pending'] == true) {
      return onMapNote;
    }

    if (onSelf) {
      return '$onMapNote. Nemico non in quell\'area: '
          'servono scan più lontani o raggio maggiore (max radar).';
    }
    return '$onMapNote. Nessun contatto in quell\'area.';
  }

  @override
  Widget build(BuildContext context) {
    final pending = scan['pending'] == true;
    final found = scan['found'] == true;
    final turn = scan['turn'];
    final center = '(${scan['scan_x']}, ${scan['scan_y']})';
    final radius = (scan['radius'] as num?)?.toInt() ?? 0;
    final tactical = _tacticalLine(radius);

    late Color bg;
    late Color border;
    late IconData icon;
    late String title;
    late String subtitle;

    if (pending) {
      bg = const Color(0xFF1E3A5F);
      border = Colors.lightBlueAccent;
      icon = Icons.radar;
      title = 'Scan inviato — in attesa conferma';
      subtitle = 'Area $center · raggio $radius · turno $turn';
    } else if (found) {
      bg = const Color(0xFF14532D);
      border = Colors.amberAccent;
      icon = Icons.gps_fixed;
      title = 'NEMICO TROVATO';
      subtitle =
          'Posizione (${scan['x']}, ${scan['y']}) · scan da $center raggio $radius · turno $turn';
    } else {
      bg = const Color(0xFF422006);
      border = Colors.orangeAccent;
      icon = Icons.radar_outlined;
      title = 'Nessun contatto nel raggio';
      subtitle =
          'Area scansionata $center · raggio $radius · turno $turn — prova un\'altra zona';
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: bg,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 2),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: border, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: border,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  if (tactical != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      tactical,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
