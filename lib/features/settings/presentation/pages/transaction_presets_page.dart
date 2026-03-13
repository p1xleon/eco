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
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () => _showAddDialog(context, ref, type),
              icon: const Icon(Icons.add),
              label: Text(_buttonLabel(type)),
            ),
            const SizedBox(height: 16),
            if (presets.isEmpty)
              Text('No presets yet for ${_title(type).toLowerCase()}.')
            else
              ...presets.map(
                (preset) => Card(
                  child: ListTile(
                    title: Text(preset.value),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final repo = ref.read(
                          transactionPresetRepositoryProvider,
                        );
                        await repo.delete(preset.id);
                        _invalidate(ref);
                      },
                    ),
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

  Future<void> _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    TransactionPresetType type,
  ) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_buttonLabel(type)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _title(type),
              hintText: _hint(type),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;

    final repo = ref.read(transactionPresetRepositoryProvider);
    await repo.add(type, result);
    _invalidate(ref);
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(paymentMethodPresetsProvider);
    ref.invalidate(payeePresetsProvider);
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

  String _hint(TransactionPresetType type) {
    return switch (type) {
      TransactionPresetType.paymentMethod => 'UPI, Card, PhonePe',
      TransactionPresetType.payee => 'Amazon, Local Store',
    };
  }
}
