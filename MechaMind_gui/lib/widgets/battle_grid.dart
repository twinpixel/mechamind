import 'package:flutter/material.dart';

/// Tactical map centered on the player — fixed cell size, scroll if needed.
class BattleGrid extends StatelessWidget {
  const BattleGrid({
    super.key,
    required this.playerX,
    required this.playerY,
    this.scanX,
    this.scanY,
    this.scanCenterX,
    this.scanCenterY,
    this.scanRadius,
    this.highlightScan = false,
    this.fireX,
    this.fireY,
    this.onCellTap,
    this.viewRadius = 20,
    this.gridSize = 100,
    this.cellSize = 12,
  });

  final int playerX;
  final int playerY;
  final int? scanX;
  final int? scanY;
  final int? scanCenterX;
  final int? scanCenterY;
  final int? scanRadius;
  final bool highlightScan;
  final int? fireX;
  final int? fireY;
  final void Function(int x, int y)? onCellTap;
  final int viewRadius;
  final int gridSize;
  final double cellSize;

  int _manhattan(int x1, int y1, int x2, int y2) =>
      (x1 - x2).abs() + (y1 - y2).abs();

  bool _onDiamondEdge(int gx, int gy, int cx, int cy, int radius) {
    if (_manhattan(gx, gy, cx, cy) > radius) return false;
    const neighbors = [
      (1, 0),
      (-1, 0),
      (0, 1),
      (0, -1),
    ];
    for (final (dx, dy) in neighbors) {
      if (_manhattan(gx + dx, gy + dy, cx, cy) > radius) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final minX = (playerX - viewRadius).clamp(0, gridSize - 1);
    final maxX = (playerX + viewRadius).clamp(0, gridSize - 1);
    final minY = (playerY - viewRadius).clamp(0, gridSize - 1);
    final maxY = (playerY + viewRadius).clamp(0, gridSize - 1);
    final cols = maxX - minX + 1;
    final rows = maxY - minY + 1;
    final gridW = cols * cellSize;
    final gridH = rows * cellSize;

    return Card(
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '($minX,$minY)–($maxX,$maxY) · tuo ($playerX,$playerY)',
                    style: Theme.of(context).textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (highlightScan && scanRadius != null)
                  Chip(
                    label: Text('r=$scanRadius'),
                    backgroundColor: const Color(0xFF0C4A6E),
                    labelStyle: const TextStyle(color: Colors.lightBlueAccent),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (onCellTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  'Tocca una cella (${cellSize.toInt()}px/cella — scroll se serve)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.lightBlueAccent,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                        return _GridCell(
                          gx: gx,
                          gy: gy,
                          isPlayer: gx == playerX && gy == playerY,
                          isScanFound: gx == scanX && gy == scanY,
                          isFire: gx == fireX && gy == fireY,
                          isScanCenter: gx == scanCenterX && gy == scanCenterY,
                          inScanArea: highlightScan &&
                              scanCenterX != null &&
                              scanCenterY != null &&
                              scanRadius != null &&
                              scanRadius! > 0 &&
                              _manhattan(gx, gy, scanCenterX!, scanCenterY!) <=
                                  scanRadius!,
                          isScanEdge: highlightScan &&
                              scanCenterX != null &&
                              scanCenterY != null &&
                              scanRadius != null &&
                              _manhattan(gx, gy, scanCenterX!, scanCenterY!) <=
                                  scanRadius! &&
                              _onDiamondEdge(
                                gx,
                                gy,
                                scanCenterX!,
                                scanCenterY!,
                                scanRadius!,
                              ),
                          onTap: onCellTap == null
                              ? null
                              : () => onCellTap!(gx, gy),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: const [
                _Legend(color: Colors.cyanAccent, label: 'Tu'),
                _Legend(color: Color(0xFF0369A1), label: 'Scan'),
                _Legend(color: Colors.lightBlueAccent, label: 'Centro'),
                _Legend(color: Colors.amberAccent, label: 'Nemico'),
                _Legend(color: Colors.redAccent, label: 'Fuoco'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.gx,
    required this.gy,
    required this.isPlayer,
    required this.isScanFound,
    required this.isFire,
    required this.isScanCenter,
    required this.inScanArea,
    required this.isScanEdge,
    this.onTap,
  });

  final int gx;
  final int gy;
  final bool isPlayer;
  final bool isScanFound;
  final bool isFire;
  final bool isScanCenter;
  final bool inScanArea;
  final bool isScanEdge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color fill = const Color(0xFF1E293B);
    double alpha = 0.85;
    Color borderColor = const Color(0xFF334155);
    double borderWidth = 0.5;

    if (inScanArea && !isPlayer && !isFire && !isScanFound) {
      fill = const Color(0xFF0284C7);
      alpha = 0.78;
    }
    if (isScanEdge) {
      borderColor = Colors.lightBlueAccent;
      borderWidth = 1.5;
    }
    if (isScanCenter && !isPlayer) {
      fill = Colors.lightBlueAccent;
      alpha = 1;
    }
    if (isPlayer) {
      fill = Colors.cyanAccent;
      alpha = 1;
      borderColor = Colors.white;
      borderWidth = 1.5;
    }
    if (isScanFound) {
      fill = Colors.amberAccent;
      alpha = 1;
      borderColor = Colors.orange;
      borderWidth = 2;
    }
    if (isFire) {
      fill = Colors.redAccent;
      alpha = 1;
      borderColor = Colors.white;
      borderWidth = 1.5;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: fill.withValues(alpha: alpha),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: isScanCenter && isPlayer
            ? Center(
                child: Icon(
                  Icons.radar,
                  size: 8,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              )
            : null,
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
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
