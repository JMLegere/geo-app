import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:earth_nova/models/cell_properties.dart';

/// Bottom sheet showing details for a tapped cell.
class CellInfoSheet extends StatelessWidget {
  final String cellId;
  final CellProperties? properties;
  final int visitCount;
  final DateTime? lastVisited;
  final String? districtName;

  const CellInfoSheet({
    super.key,
    required this.cellId,
    this.properties,
    this.visitCount = 0,
    this.lastVisited,
    this.districtName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final props = properties;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cell ID
          Text(
            'Cell ${_shortId(cellId)}',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Location hierarchy
          if (districtName != null)
            _InfoRow(
              icon: Icons.location_on,
              label: districtName!,
            ),

          // Habitats
          if (props != null) ...[
            _InfoRow(
              icon: Icons.landscape,
              label: props.habitats.map((h) => _capitalize(h.name)).join(', '),
            ),

            // Climate
            _InfoRow(
              icon: Icons.thermostat,
              label: _capitalize(props.climate.name),
            ),
          ],

          // Visit count
          _InfoRow(
            icon: Icons.hiking,
            label: visitCount == 0
                ? 'Not yet visited'
                : '$visitCount ${visitCount == 1 ? 'visit' : 'visits'}',
          ),

          // Last visited
          if (lastVisited != null)
            _InfoRow(
              icon: Icons.access_time,
              label: 'Last visited ${_formatDate(lastVisited!)}',
            ),

          if (props == null && visitCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Cell not yet explored',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
              ),
            ),
        ],
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}…';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the [CellInfoSheet] as a modal bottom sheet.
void showCellInfoSheet(
  BuildContext context, {
  required String cellId,
  CellProperties? properties,
  int visitCount = 0,
  DateTime? lastVisited,
  String? districtName,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => CellInfoSheet(
      cellId: cellId,
      properties: properties,
      visitCount: visitCount,
      lastVisited: lastVisited,
      districtName: districtName,
    ),
  );
}
