import 'package:flutter/material.dart' hide Durations;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/services/debug_log_buffer.dart';
import 'package:earth_nova/core/state/debug_log_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Expandable card displaying in-app debug logs from [DebugLogBuffer].
///
/// Collapsed by default — shows line count badge. Expanded reveals a
/// scrollable monospace log view with copy and clear actions.
class DebugLogCard extends ConsumerStatefulWidget {
  const DebugLogCard({super.key});

  @override
  ConsumerState<DebugLogCard> createState() => _DebugLogCardState();
}

class _DebugLogCardState extends ConsumerState<DebugLogCard> {
  bool _expanded = false;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyToClipboard(BuildContext context, List<String> lines) {
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _clear() {
    DebugLogBuffer.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(debugLogProvider);
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: Radii.borderXxl,
        boxShadow: Shadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (always visible) ────────────────────────────────────────
          InkWell(
            borderRadius: _expanded
                ? BorderRadius.only(
                    topLeft: Radius.circular(Radii.xxl),
                    topRight: Radius.circular(Radii.xxl),
                  )
                : Radii.borderXxl,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: Spacing.paddingCard,
              child: Row(
                children: [
                  Icon(
                    Icons.bug_report_outlined,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  Spacing.gapHSm,
                  Text(
                    'Debug Log',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                  Spacing.gapHSm,
                  // Line count badge
                  Container(
                    padding: Spacing.paddingBadgeCompact,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.08),
                      borderRadius: Radii.borderPill,
                    ),
                    child: Text(
                      '${lines.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: Durations.normal,
                    curve: AppCurves.standard,
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded content ───────────────────────────────────────────────
          AnimatedSize(
            duration: Durations.normal,
            curve: AppCurves.standard,
            child: _expanded
                ? _LogBody(
                    lines: lines,
                    scrollController: _scrollController,
                    onCopy: () => _copyToClipboard(context, lines),
                    onClear: _clear,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Log body (log text + actions) ────────────────────────────────────────────

class _LogBody extends StatelessWidget {
  const _LogBody({
    required this.lines,
    required this.scrollController,
    required this.onCopy,
    required this.onClear,
  });

  final List<String> lines;
  final ScrollController scrollController;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Divider
        Divider(
          height: 1,
          thickness: 1,
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),

        // Log text area
        Container(
          height: 300,
          margin: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: Radii.borderMd,
          ),
          child: lines.isEmpty
              ? Center(
                  child: Text(
                    'No log entries yet.',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : Scrollbar(
                  controller: scrollController,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      lines.join('\n'),
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
        ),

        // Action buttons row
        Padding(
          padding: const EdgeInsets.only(
            left: Spacing.lg,
            right: Spacing.lg,
            bottom: Spacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Clear button
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              Spacing.gapHSm,
              // Copy button
              TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
