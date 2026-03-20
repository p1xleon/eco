import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/transaction_preset_model.dart';
import '../providers/transaction_preset_provider.dart';

class TransactionPresetsPage extends ConsumerWidget {
  const TransactionPresetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transaction Presets'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Payment Methods'),
              Tab(text: 'Stores / Payees'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PresetList(type: TransactionPresetType.paymentMethod),
            _PresetList(type: TransactionPresetType.payee),
          ],
        ),
      ),
    );
  }
}

class _PresetList extends ConsumerWidget {
  final TransactionPresetType type;

  const _PresetList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = switch (type) {
      TransactionPresetType.paymentMethod => ref.watch(
        paymentMethodPresetsProvider,
      ),
      TransactionPresetType.payee => ref.watch(payeePresetsProvider),
    };

    return presetsAsync.when(
      data: (presets) {
        final scheme = Theme.of(context).colorScheme;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _icon(type),
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(type),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _summary(type, presets.length),
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _helper(type),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showEditorSheet(context, ref, type: type),
                    icon: const Icon(Icons.add),
                    label: Text(_buttonLabel(type)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (presets.isEmpty)
              _PresetEmptyState(type: type)
            else
              ...presets.map(
                (preset) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PresetCard(
                    preset: preset,
                    icon: _icon(type),
                    typeLabel: _title(type),
                    onEdit: () => _showEditorSheet(
                      context,
                      ref,
                      type: type,
                      preset: preset,
                    ),
                    onDelete: () => _deletePreset(context, ref, type, preset),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  Future<void> _showEditorSheet(
    BuildContext context,
    WidgetRef ref, {
    required TransactionPresetType type,
    TransactionPresetModel? preset,
  }) async {
    final controller = TextEditingController(text: preset?.value ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preset == null ? _buttonLabel(type) : 'Edit ${_title(type)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                preset == null ? _editorAddCopy(type) : _editorEditCopy(type),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _title(type),
                  hintText: _hint(type),
                ),
                onSubmitted: (value) => Navigator.pop(context, value.trim()),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: Text(preset == null ? 'Save' : 'Update'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == null || result.isEmpty) return;

    final repo = ref.read(transactionPresetRepositoryProvider);
    if (preset == null) {
      await repo.add(type, result);
    } else {
      await repo.update(preset.id, type, result);
    }
    _invalidate(ref, type);
  }

  Future<void> _deletePreset(
    BuildContext context,
    WidgetRef ref,
    TransactionPresetType type,
    TransactionPresetModel preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text(
          'Remove "${preset.value}" from saved presets? Existing transactions will stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final repo = ref.read(transactionPresetRepositoryProvider);
    await repo.delete(preset.id);
    _invalidate(ref, type);
  }

  void _invalidate(WidgetRef ref, TransactionPresetType type) {
    switch (type) {
      case TransactionPresetType.paymentMethod:
        ref.invalidate(paymentMethodPresetsProvider);
        return;
      case TransactionPresetType.payee:
        ref.invalidate(payeePresetsProvider);
        return;
    }
  }

  String _title(TransactionPresetType type) {
    return switch (type) {
      TransactionPresetType.paymentMethod => 'Payment Method',
      TransactionPresetType.payee => 'Store / Payee',
    };
  }

  String _buttonLabel(TransactionPresetType type) {
    return switch (type) {
      TransactionPresetType.paymentMethod => 'Add Payment Method',
      TransactionPresetType.payee => 'Add Store / Payee',
    };
  }

  IconData _icon(TransactionPresetType type) {
    return switch (type) {
      TransactionPresetType.paymentMethod => Icons.wallet_outlined,
      TransactionPresetType.payee => Icons.storefront_outlined,
    };
  }

  String _summary(TransactionPresetType type, int count) {
    final noun = switch (type) {
      TransactionPresetType.paymentMethod => 'method',
      TransactionPresetType.payee => 'preset',
    };

    return '$count saved $noun${count == 1 ? '' : 's'}';
  }

  String _helper(TransactionPresetType type) {
    return switch (type) {
      TransactionPresetType.paymentMethod =>
        'Keep your common payment options ready so transaction entry takes one tap.',
      TransactionPresetType.payee =>
        'Save the merchants, people, or accounts you use often for faster entry.',
    };
  }

  String _editorAddCopy(TransactionPresetType type) {
    return switch (type) {
      TransactionPresetType.paymentMethod =>
        'Add a payment method you use regularly in transactions.',
      TransactionPresetType.payee =>
        'Add a merchant, person, or destination you use regularly.',
    };
  }

  String _editorEditCopy(TransactionPresetType type) {
    return switch (type) {
      TransactionPresetType.paymentMethod =>
        'Rename this payment method preset so it stays clear and consistent.',
      TransactionPresetType.payee =>
        'Refine this store or payee preset without affecting past transactions.',
    };
  }

  String _hint(TransactionPresetType type) {
    return switch (type) {
      TransactionPresetType.paymentMethod => 'UPI, Card, PhonePe',
      TransactionPresetType.payee => 'Amazon, Local Store',
    };
  }
}

class _PresetEmptyState extends StatelessWidget {
  final TransactionPresetType type;

  const _PresetEmptyState({required this.type});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (type) {
      TransactionPresetType.paymentMethod => Icons.wallet_outlined,
      TransactionPresetType.payee => Icons.store_mall_directory_outlined,
    };
    final title = switch (type) {
      TransactionPresetType.paymentMethod => 'No payment methods yet',
      TransactionPresetType.payee => 'No stores or payees yet',
    };
    final subtitle = switch (type) {
      TransactionPresetType.paymentMethod =>
        'Create your first preset to turn common payment types into quick picks.',
      TransactionPresetType.payee =>
        'Create your first preset to make repeat merchants and contacts easier to reuse.',
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final TransactionPresetModel preset;
  final IconData icon;
  final String typeLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PresetCard({
    required this.preset,
    required this.icon,
    required this.typeLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  typeLabel,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PopupMenuButton<_PresetAction>(
            onSelected: (action) {
              if (action == _PresetAction.edit) {
                onEdit();
              } else {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _PresetAction.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              PopupMenuItem(
                value: _PresetAction.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PresetAction { edit, delete }
