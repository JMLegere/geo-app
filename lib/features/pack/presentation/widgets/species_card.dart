import 'package:flutter/material.dart';

import 'package:earth_nova/core/domain/entities/game_region.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/entities/iucn_status.dart';
import 'package:earth_nova/core/domain/entities/taxonomic_group.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/product/product_action_surface.dart';

/// Opens neutral species details without changing the Item's knowledge state.
void showSpeciesCard(
  BuildContext context,
  Item item, {
  void Function(Item item)? onOpenIdentificationService,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close species card',
    useSafeArea: true,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    requestFocus: true,
    builder: (_) => SpeciesCard(
      item: item,
      onOpenIdentificationService: onOpenIdentificationService,
    ),
  );
}

/// Responsive species details shown standalone or in [showSpeciesCard].
class SpeciesCard extends StatefulWidget {
  const SpeciesCard({
    super.key,
    required this.item,
    this.onOpenIdentificationService,
  });

  final Item item;
  final void Function(Item item)? onOpenIdentificationService;

  @override
  State<SpeciesCard> createState() => _SpeciesCardState();
}

class _SpeciesCardState extends State<SpeciesCard> {
  static const _dismissDistance = 80.0;

  double _downwardOverscroll = 0;

  void _dismiss() {
    Navigator.of(context).maybePop();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _downwardOverscroll = 0;
    } else if (notification is OverscrollNotification &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent &&
        notification.overscroll < 0) {
      _downwardOverscroll -= notification.overscroll;
      if (_downwardOverscroll >= _dismissDistance) {
        _downwardOverscroll = 0;
        _dismiss();
      }
    } else if (notification is ScrollEndNotification) {
      _downwardOverscroll = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final content = item.isExamined
        ? _ExaminedSpeciesContent(
            item: item,
            onOpenIdentificationService: widget.onOpenIdentificationService,
            onDismiss: _dismiss,
          )
        : _UnexaminedSpeciesContent(item: item, onDismiss: _dismiss);

    return SafeArea(
      child: Center(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: item.isExamined
                    ? 'Species details for ${item.visibleDisplayName}'
                    : 'Unexamined ${item.category.label.toLowerCase()} Item',
                child: KeyedSubtree(
                  key: ValueKey('species-card-${item.id}'),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnexaminedSpeciesContent extends StatelessWidget {
  const _UnexaminedSpeciesContent({
    required this.item,
    required this.onDismiss,
  });

  final Item item;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final label = 'Unexamined ${item.category.label.toLowerCase()} Item';
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            // eac-clickable-ignore: Species-card dismissal closes local detail chrome without creating product state.
            child: IconButton(
              key: const Key('species-card-close'),
              autofocus: true,
              tooltip: 'Close species card',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ),
          AppNotice(
            title: label,
            message:
                'Identity and field details are unavailable until this Item has been examined.',
          ),
        ],
      ),
    );
  }
}

class _ExaminedSpeciesContent extends StatelessWidget {
  const _ExaminedSpeciesContent({
    required this.item,
    required this.onOpenIdentificationService,
    required this.onDismiss,
  });

  final Item item;
  final void Function(Item item)? onOpenIdentificationService;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final media = _SpeciesMedia(item: item);
    final details = _SpeciesDetails(
      item: item,
      onOpenIdentificationService: onOpenIdentificationService,
    );

    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.visibleDisplayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (item.visibleScientificName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.visibleScientificName!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // eac-clickable-ignore: Species-card dismissal closes local detail chrome without creating product state.
              IconButton(
                key: const Key('species-card-close'),
                autofocus: true,
                tooltip: 'Close species card',
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (mobile)
            Column(
              key: const Key('species-card-mobile-layout'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [media, const SizedBox(height: 16), details],
            )
          else
            Row(
              key: const Key('species-card-desktop-layout'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: media),
                const SizedBox(width: 24),
                Expanded(child: details),
              ],
            ),
        ],
      ),
    );
  }
}

class _SpeciesMedia extends StatelessWidget {
  const _SpeciesMedia({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 16 / 10, child: _primaryMedia(context));
  }

  Widget _primaryMedia(BuildContext context) {
    final artUrl = item.artUrl;
    if (artUrl != null && artUrl.isNotEmpty) {
      return Image.network(
        artUrl,
        key: ValueKey('species-art-${item.id}'),
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _iconOrCategoryFallback(context),
        errorBuilder: (_, __, ___) => _iconOrCategoryFallback(context),
      );
    }
    return _iconOrCategoryFallback(context);
  }

  Widget _iconOrCategoryFallback(BuildContext context) {
    final iconUrl = item.iconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Image.network(
            iconUrl,
            key: ValueKey('species-icon-${item.id}'),
            width: 112,
            height: 112,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : _categoryFallback(context),
            errorBuilder: (_, __, ___) => _categoryFallback(context),
          ),
        ),
      );
    }
    return _categoryFallback(context);
  }

  Widget _categoryFallback(BuildContext context) {
    final label = '${item.category.label} media unavailable';
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Semantics(
          key: ValueKey('species-media-fallback-${item.id}'),
          image: true,
          label: label,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_not_supported_outlined, size: 56),
                const SizedBox(height: 8),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeciesDetails extends StatelessWidget {
  const _SpeciesDetails({
    required this.item,
    required this.onOpenIdentificationService,
  });

  final Item item;
  final void Function(Item item)? onOpenIdentificationService;

  @override
  Widget build(BuildContext context) {
    final status = IucnStatus.fromString(item.rarity);
    final group = item.taxonomicGroup;
    final habitats = item.habitats
        .map(Habitat.fromString)
        .whereType<Habitat>()
        .map((habitat) => habitat.label)
        .toList();
    final regions = item.continents
        .map(GameRegion.fromString)
        .whereType<GameRegion>()
        .where((region) => region != GameRegion.unknown)
        .map((region) => region.label)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppBadge(
              label: item.category.label,
              variant: AppBadgeVariant.outline,
            ),
            AppBadge(label: item.isUnidentified ? 'Examined' : 'Identified'),
            if (status != null)
              AppBadge(
                label: '${status.code} · ${status.displayName}',
                variant: AppBadgeVariant.outline,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (item.isUnidentified)
          const Text(
            'Examination revealed these field details. Identification remains pending.',
          ),
        if (item.taxonomicClass != null && group != TaxonomicGroup.other)
          AppFieldRow(label: 'Taxonomic group', value: group.label),
        if (habitats.isNotEmpty)
          AppFieldRow(label: 'Habitats', value: habitats.join(', ')),
        if (regions.isNotEmpty)
          AppFieldRow(label: 'Regions', value: regions.join(', ')),
        AppFieldRow(label: 'Acquired', value: _formatDate(item.acquiredAt)),
        if (item.acquiredInCellId != null)
          const AppFieldRow(label: 'Provenance', value: 'Map exploration'),
        if (item.isUnidentified && onOpenIdentificationService != null) ...[
          const SizedBox(height: 12),
          ProductActionSurface(
            actionId: PlayerActions.openIdentificationService,
            child: AppButton(
              key: const Key('open-identification-service'),
              label: 'Open identification service',
              expand: true,
              onPressed: () => onOpenIdentificationService!(item),
            ),
          ),
        ],
      ],
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
