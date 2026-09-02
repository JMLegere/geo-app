import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/product/product_action_surface.dart';
import 'package:earth_nova/shared/product/player_actions.dart';

typedef PrepareIdentification =
    Future<IdentificationPreparation> Function(Item item);
typedef CommitIdentification =
    Future<ItemIdentificationResult> Function(ItemIdentificationPlan plan);

/// A distinct Villager Service flow for one examined, unidentified Item.
class IdentificationServiceScreen extends ConsumerStatefulWidget {
  const IdentificationServiceScreen({
    super.key,
    required this.item,
    this.prepare,
    this.commit,
  }) : assert(
         (prepare == null) == (commit == null),
         'prepare and commit must be supplied together',
       );

  final Item item;
  final PrepareIdentification? prepare;
  final CommitIdentification? commit;

  @override
  ConsumerState<IdentificationServiceScreen> createState() =>
      _IdentificationServiceScreenState();
}

class _IdentificationServiceScreenState
    extends ConsumerState<IdentificationServiceScreen> {
  IdentificationPreparation? _preparation;
  ItemIdentificationResult? _result;
  String? _error;
  bool _started = false;
  bool _committing = false;

  bool get _usesInjectedBoundary => widget.prepare != null;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareOnce());
  }

  Future<void> _prepareOnce() async {
    try {
      final preparation = await _prepare(widget.item);
      if (preparation.item.id.value != widget.item.id) {
        throw StateError('Preparation returned a different Item.');
      }
      if (!mounted) return;
      setState(() => _preparation = preparation);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Couldn't prepare Identification.");
    }
  }

  Future<IdentificationPreparation> _prepare(Item item) {
    final injected = widget.prepare;
    if (injected != null) return injected(item);

    final repository = ref.read(identificationRepositoryProvider);
    if (repository == null) {
      throw StateError('Identification repository is unavailable.');
    }
    return repository.prepare(ItemKnowledgeItemId(item.id));
  }

  void _start() {
    if (_preparation == null || _started) return;
    _logProductionAction(
      actionType: 'identify_unidentified_find',
      widgetName: 'start_identification_button',
      playerActionId: PlayerActions.identifyUnidentifiedFind,
    );
    setState(() => _started = true);
  }

  Future<void> _reveal() async {
    final preparation = _preparation;
    if (preparation == null || !_started || _committing || _result != null) {
      return;
    }

    _logProductionAction(
      actionType: 'reveal_identification',
      widgetName: 'hold_to_reveal_button',
      playerActionId: PlayerActions.revealIdentification,
    );
    setState(() {
      _committing = true;
      _error = null;
    });

    try {
      final planner = ref.read(planItemIdentificationProvider);
      final plan = await planner.call(preparation);
      if (plan.item.id.value != widget.item.id) {
        throw StateError('Identification plan belongs to a different Item.');
      }

      final result = await _commit(plan);
      if (result.committedItem.id != widget.item.id) {
        throw StateError('Identification returned a different Item.');
      }
      if (!_usesInjectedBoundary) {
        ref
            .read(itemsProvider.notifier)
            .registerOwnedDiscovery(result.committedItem);
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _committing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _committing = false;
        _error = "Couldn't reveal Identification. Try again.";
      });
    }
  }

  Future<ItemIdentificationResult> _commit(ItemIdentificationPlan plan) {
    final injected = widget.commit;
    if (injected != null) return injected(plan);

    final repository = ref.read(identificationRepositoryProvider);
    if (repository == null) {
      throw StateError('Identification repository is unavailable.');
    }
    return repository.commit(plan);
  }

  void _logProductionAction({
    required String actionType,
    required String widgetName,
    required PlayerActionId playerActionId,
  }) {
    if (_usesInjectedBoundary) return;
    final observability = ref.read(appObservabilityProvider);
    ObservableInteraction.log(
      logger: ({required event, required category, data}) =>
          observability.log(event, category, data: data),
      screenName: 'identification_service_screen',
      widgetName: widgetName,
      actionType: actionType,
      playerActionId: playerActionId,
      payload: {'item_id': widget.item.id},
    );
  }

  void _cancel() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final observability = ref.watch(appObservabilityProvider);
    return ObservableScreen(
      screenName: 'identification_service_screen',
      observability: observability,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Identify find')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(
                  width: double.infinity,
                  child: result != null
                      ? _IdentifiedResult(item: result.committedItem)
                      : _preparation == null && _error == null
                      ? const _PreparingIdentification()
                      : _preparation == null
                      ? _PreparationError(message: _error!, onCancel: _cancel)
                      : _PreparedService(
                          preparation: _preparation!,
                          started: _started,
                          committing: _committing,
                          error: _error,
                          onStart: _start,
                          onReveal: _reveal,
                          onCancel: _cancel,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreparingIdentification extends StatelessWidget {
  const _PreparingIdentification();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Preparing identification',
      child: const ExcludeSemantics(
        child: AppCard(
          title: 'Preparing identification',
          description: 'Getting this examined find ready.',
          child: Center(child: LoadingDots()),
        ),
      ),
    );
  }
}

class _PreparedService extends StatelessWidget {
  const _PreparedService({
    required this.preparation,
    required this.started,
    required this.committing,
    required this.error,
    required this.onStart,
    required this.onReveal,
    required this.onCancel,
  });

  final IdentificationPreparation preparation;
  final bool started;
  final bool committing;
  final String? error;
  final VoidCallback onStart;
  final Future<void> Function() onReveal;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final service = preparation.serviceAccess;
    return AppCard(
      title: service.serviceDisplayName,
      description: service.villagerDisplayName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            started
                ? 'The prepared result is ready. Hold to reveal it.'
                : 'This Villager can identify the examined find.',
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            AppNotice(
              title: 'Identification was not revealed',
              message: error!,
              tone: AppNoticeTone.error,
            ),
          ],
          const SizedBox(height: 20),
          if (!started)
            ProductActionSurface(
              actionId: PlayerActions.identifyUnidentifiedFind,
              child: AppButton(
                label: 'Start identification',
                leading: const Icon(Icons.play_arrow_outlined),
                expand: true,
                onPressed: onStart,
              ),
            )
          else
            ProductActionSurface(
              actionId: PlayerActions.revealIdentification,
              child: _HoldToRevealButton(busy: committing, onReveal: onReveal),
            ),
          const SizedBox(height: 8),
          // eac-clickable-ignore: Cancel dismisses this local flow without committing a result.
          ProductActionSurface(
            actionId: null,
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.ghost,
              expand: true,
              onPressed: committing ? null : onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldToRevealButton extends StatelessWidget {
  const _HoldToRevealButton({required this.busy, required this.onReveal});

  final bool busy;
  final Future<void> Function() onReveal;

  @override
  Widget build(BuildContext context) {
    void reveal() => unawaited(onReveal());

    return Semantics(
      key: const Key('hold-to-reveal'),
      container: true,
      liveRegion: busy,
      label: busy ? 'Revealing identification' : 'Hold to reveal',
      hint: busy ? null : 'Press and hold to reveal the identification',
      button: true,
      enabled: !busy,
      excludeSemantics: true,
      onLongPress: busy ? null : reveal,
      // eac-clickable-owner-logs: onReveal invokes _reveal, which logs PlayerActions.revealIdentification before committing.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: busy ? null : reveal,
        // Pointer taps stay inert while the AppButton retains keyboard focus.
        child: IgnorePointer(
          child: AppButton(
            label: busy ? 'Revealing…' : 'Hold to reveal',
            leading: busy
                ? const LoadingDots()
                : const Icon(Icons.visibility_outlined),
            expand: true,
            onPressed: busy ? null : reveal,
          ),
        ),
      ),
    );
  }
}

class _IdentifiedResult extends StatelessWidget {
  const _IdentifiedResult({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: ValueKey('identified-item-${item.id}'),
      title: item.displayName,
      child: AppNotice(
        title: 'Identification revealed',
        message: item.scientificName ?? 'Scientific name unavailable',
        tone: AppNoticeTone.success,
      ),
    );
  }
}

class _PreparationError extends StatelessWidget {
  const _PreparationError({required this.message, required this.onCancel});

  final String message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ProductActionSurface(
      actionId: null,
      child: AppErrorState(
        title: 'Identification unavailable',
        message: message,
        retryLabel: 'Cancel',
        onRetry: onCancel,
      ),
    );
  }
}
