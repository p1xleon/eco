import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/utils/money.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../settings/data/models/transaction_preset_model.dart';
import '../../../settings/presentation/providers/transaction_preset_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/providers/transaction_repository_provider.dart';
import '../../presentation/providers/transaction_provider.dart';
import '../../presentation/widgets/transaction_form_shared.dart';
import '../domain/bulk_entry.dart';
import 'bulk_entry_editor_sheet.dart';

/// Step 2 of bulk add: every generated row can be ticked, edited, removed or
/// added to before anything is saved. Pops with the number of rows saved.
class BulkReviewPage extends ConsumerStatefulWidget {
  final TransactionType type;
  final List<BulkEntry> entries;

  /// Fingerprints of what is already stored, for flagging duplicates.
  final Set<String> existing;

  /// Categories of [type] only.
  final List<CategoryModel> categories;

  const BulkReviewPage({
    super.key,
    required this.type,
    required this.entries,
    required this.existing,
    required this.categories,
  });

  @override
  ConsumerState<BulkReviewPage> createState() => _BulkReviewPageState();
}

class _BulkReviewPageState extends ConsumerState<BulkReviewPage> {
  late List<BulkEntry> _entries;
  late int _nextKey;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entries = [...widget.entries];
    _nextKey = _entries.fold<int>(0, (max, e) => e.key > max ? e.key : max) + 1;
  }

  List<BulkEntry> get _selected =>
      _entries.where((e) => e.selected).toList(growable: false);

  CategoryModel? _category(int id) =>
      widget.categories.where((c) => c.id == id).firstOrNull;

  void _replace(BulkEntry updated) {
    setState(() {
      _entries = [
        for (final e in _entries)
          if (e.key == updated.key) updated else e,
      ]..sort(_byDate);
    });
  }

  static int _byDate(BulkEntry a, BulkEntry b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.key.compareTo(b.key);
  }

  List<TransactionPresetModel> _presets(
    AsyncValue<List<TransactionPresetModel>> value,
  ) => value.valueOrNull ?? const [];

  Future<void> _edit(BulkEntry entry) async {
    final result = await BulkEntryEditorSheet.show(
      context,
      entry: entry,
      categories: widget.categories,
      paymentMethodPresets: _presets(ref.read(paymentMethodPresetsProvider)),
      payeePresets: _presets(ref.read(payeePresetsProvider)),
    );
    if (!mounted || result == null) return;

    if (result == BulkEntryEditorSheet.removed) {
      setState(
        () => _entries = _entries.where((e) => e.key != entry.key).toList(),
      );
    } else if (result is BulkEntry) {
      _replace(recheckDuplicate(result, widget.existing));
    }
  }

  void _addRow() {
    final last = _entries.isEmpty ? null : _entries.last;
    final category = last != null && _category(last.categoryId) != null
        ? last.categoryId
        : widget.categories.firstOrNull?.id;
    if (category == null) return;

    final row = recheckDuplicate(
      BulkEntry(
        key: _nextKey++,
        date: last?.date ?? DateTime.now(),
        amount: last?.amount ?? 0,
        title: last?.title ?? '',
        categoryId: category,
        payee: last?.payee,
        paymentMethod: last?.paymentMethod,
      ),
      widget.existing,
    );
    setState(() => _entries = [..._entries, row]..sort(_byDate));
    _edit(row);
  }

  void _setAllTicked(bool value) {
    setState(() {
      _entries = [
        for (final e in _entries) e.copyWith(selected: value && !e.duplicate),
      ];
    });
  }

  Future<void> _setForSelected() async {
    final patch = await showModalBottomSheet<_Patch>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SetForSelectedSheet(
        categories: widget.categories,
        paymentMethodPresets: _presets(ref.read(paymentMethodPresetsProvider)),
        payeePresets: _presets(ref.read(payeePresetsProvider)),
      ),
    );
    if (!mounted || patch == null) return;

    setState(() {
      _entries = [
        for (final e in _entries)
          if (e.selected)
            recheckDuplicate(
              e.copyWith(
                categoryId: patch.categoryId,
                amount: patch.amount,
                payee: patch.payee,
                paymentMethod: patch.paymentMethod,
              ),
              widget.existing,
            )
          else
            e,
      ];
    });
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected.isEmpty) {
      _snack('Tick at least one entry.');
      return;
    }

    final broken = selected.where((e) => e.error() != null).length;
    if (broken > 0) {
      _snack(
        '$broken entr${broken == 1 ? 'y needs' : 'ies need'} fixing first.',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final saved = await ref.read(transactionRepositoryProvider).addAll([
        for (final e in selected) bulkEntryToTransaction(e, type: widget.type),
      ]);

      final visibility = ref.read(transactionVisibilityProvider.notifier);
      for (final tx in saved) {
        visibility.registerVisibleTransaction(tx);
      }
      ref.invalidate(transactionsProvider);

      if (!mounted) return;
      Navigator.pop(context, saved.length);
    } catch (error) {
      if (!mounted) return;
      _snack('Could not save: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected;
    final total = selected.fold<double>(0, (sum, e) => sum + e.amount);
    final duplicates = _entries.where((e) => e.duplicate).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review entries'),
        actions: [
          IconButton(
            tooltip: 'Set for ticked entries',
            icon: const Icon(Icons.tune),
            onPressed: selected.isEmpty ? null : _setForSelected,
          ),
          IconButton(
            tooltip: selected.length == _entries.length
                ? 'Untick all'
                : 'Tick all',
            icon: Icon(
              selected.length == _entries.length
                  ? Icons.deselect
                  : Icons.select_all,
            ),
            onPressed: _entries.isEmpty
                ? null
                : () => _setAllTicked(selected.length != _entries.length),
          ),
          IconButton(
            tooltip: 'Add a row',
            icon: const Icon(Icons.add),
            onPressed: _addRow,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected.length} of ${_entries.length} ticked · '
                  '${formatMoney(total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (duplicates > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$duplicates already in your list and unticked.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _entries.isEmpty
                ? const Center(child: Text('No entries. Tap + to add a row.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) => _EntryTile(
                      entry: _entries[index],
                      categoryName: _category(_entries[index].categoryId)?.name,
                      onToggle: (value) =>
                          _replace(_entries[index].copyWith(selected: value)),
                      onTap: () => _edit(_entries[index]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _isSaving || selected.isEmpty ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Add ${selected.length} transaction'
                    '${selected.length == 1 ? '' : 's'}',
                  ),
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final BulkEntry entry;
  final String? categoryName;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.entry,
    required this.categoryName,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = entry.error();
    final details = [
      ?categoryName,
      if (entry.payee?.trim().isNotEmpty ?? false) entry.payee!.trim(),
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      leading: Checkbox(
        value: entry.selected,
        onChanged: (value) => onToggle(value ?? false),
      ),
      title: Text(
        entry.title.trim().isEmpty ? 'No title' : entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              bulkDateFormat.format(entry.date),
              if (details.isNotEmpty) details,
            ].join(' · '),
          ),
          if (entry.duplicate)
            Text(
              'Already added',
              style: TextStyle(
                color: scheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (error != null) Text(error, style: TextStyle(color: scheme.error)),
        ],
      ),
      trailing: Text(
        formatMoney(entry.amount),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Values to apply to every ticked row. A null field leaves rows as they are.
class _Patch {
  final int? categoryId;
  final double? amount;
  final String? payee;
  final String? paymentMethod;

  const _Patch({this.categoryId, this.amount, this.payee, this.paymentMethod});
}

class _SetForSelectedSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final List<TransactionPresetModel> paymentMethodPresets;
  final List<TransactionPresetModel> payeePresets;

  const _SetForSelectedSheet({
    required this.categories,
    required this.paymentMethodPresets,
    required this.payeePresets,
  });

  @override
  State<_SetForSelectedSheet> createState() => _SetForSelectedSheetState();
}

class _SetForSelectedSheetState extends State<_SetForSelectedSheet> {
  final _amount = TextEditingController();
  final _payment = TextEditingController();
  final _payee = TextEditingController();
  int? _categoryId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _payment.dispose();
    _payee.dispose();
    super.dispose();
  }

  void _apply() {
    final amountText = _amount.text.trim();
    final amount = amountText.isEmpty ? null : parseAmount(amountText);
    if (amountText.isNotEmpty && amount == null) {
      setState(() => _error = 'Enter an amount above zero, or leave it empty.');
      return;
    }

    Navigator.pop(
      context,
      _Patch(
        categoryId: _categoryId,
        amount: amount,
        payee: _payee.text.trim().isEmpty ? null : _payee.text.trim(),
        paymentMethod: _payment.text.trim().isEmpty
            ? null
            : _payment.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          Text(
            'Set for ticked entries',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Only the fields you fill in are changed.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in widget.categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          TransactionPresetField(
            label: 'Payment Method',
            hintText: 'Cash, UPI, Card...',
            emptyStateText: 'No payment method presets yet.',
            controller: _payment,
            presets: widget.paymentMethodPresets,
          ),
          const SizedBox(height: 12),
          TransactionPresetField(
            label: 'Store / Payment To',
            hintText: 'Merchant, employer, person...',
            emptyStateText: 'No store or payee presets yet.',
            controller: _payee,
            presets: widget.payeePresets,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _apply, child: const Text('Apply')),
            ],
          ),
        ],
      ),
    );
  }
}
