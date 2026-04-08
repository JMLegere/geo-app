import 'package:flutter/material.dart';

/// Brief notification shown just below the status bar when the player
/// enters a new cell for the first time.
///
/// Floats over the map. Caller is responsible for showing/hiding it
/// (e.g. via AnimatedOpacity or conditional inclusion in the Stack).
class DiscoveryNotification extends StatelessWidget {
  const DiscoveryNotification({
    super.key,
    required this.cellName,
  });

  final String cellName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEB0D1B2A),
        border: Border.all(
          color: const Color(0x4D83C5BE),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🌿',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NEW DISCOVERY',
                    style: TextStyle(
                      color: Color(0xFF83C5BE),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cellName.isEmpty ? 'Unknown Cell' : cellName,
                    style: const TextStyle(
                      color: Color(0xFFE0E1DD),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
