import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/utils/money.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../settings/presentation/providers/transaction_preset_provider.dart';
import '../../data/models/transaction_fingerprint.dart';
import '../../data/models/transaction_model.dart';
import '../../data/providers/transaction_repository_provider.dart';
import '../../presentation/widgets/transaction_form_shared.dart';
import '../domain/bulk_entry.dart';
import '../domain/bulk_schedule.dart';
import 'bulk_entry_editor_sheet.dart';
import 'bulk_review_page.dart';

/// Step 1 of bulk add: describe a repeating transaction that already happened
/// but was never entered, then review and edit every generated row.
class BulkAddPage extends ConsumerStatefulWidget {
  const BulkAddPage({super.key});

  @override
  ConsumerState<BulkAddPage> createState() => _BulkAddPageState();
}

class _BulkAddPageState extends ConsumerState<BulkAddPage> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _payment = TextEditingController();
  final _payee = TextEditingController();
  final _customEvery = TextEditingController(text: '1');

  TransactionType _type = TransactionType.expense;
  int? _categoryId;
  BulkFrequency _frequency = BulkFrequency.monthly;
  BulkUnit _customUnit = BulkUnit.months;
  late DateTime _from;
  late DateTime _to;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = DateTime(_to.year - 1, _to.month, _to.day);
    _customEvery.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    _payment.dispose();
    _payee.dispose();
    _customEvery.dispose();
    super.dispose();
  }

  BulkSchedule get _schedule => BulkSchedule(
    frequency: _frequency,
    customEvery: int.tryParse(_customEvery.text.trim()) ?? 0,
    customUnit: _customUnit,
    from: _from,
    to: _to,
  );

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: earliestBulkDate,
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;

    setState(() => isFrom ? _from = picked : _to = picked);
  }

  Future<void> _review(List<CategoryModel> categoriesOfType) async {
    final amount = parseAmount(_amount.text);
    final title = _title.text.trim();

    // The category must be one the box is showing: a category picked before
    // switching Income/Expense is still held but belongs to the other type.
    final categoryId = categoriesOfType.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;
    if (title.isEmpty || amount == null || categoryId == null) {
      _snack('Enter a title, an amount above zero, and a category.');
      return;
    }

    final problem = _schedule.validate();
    if (problem != null) {
      _snack(problem);
      return;
    }

    final dates = _schedule.generate();
    if (dates.dates.isEmpty) {
      _snack('No dates fall in that range.');
      return;
    }

    setState(() => _isBusy = true);
    try {
      // Only what the current privacy mode shows: a hidden transaction must not
      // announce itself as "Already added".
      final stored = ref
          .read(transactionVisibilityProvider)
          .applyToTransactions(
            await ref.read(transactionRepositoryProvider).getLocalAll(),
          );
      final existing = fingerprintsOf(stored);

      final entries = buildBulkEntries(
        dates: dates.dates,
        amount: amount,
        title: title,
        categoryId: categoryId,
        existing: existing,
        payee: _payee.text.trim(),
        paymentMethod: _payment.text.trim(),
        note: _note.text.trim(),
      );

      if (!mounted) return;
      final added = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => BulkReviewPage(
            type: _type,
            entries: entries,
            existing: existing,
            categories: categoriesOfType,
          ),
        ),
      );

      if (added != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $added transaction${added == 1 ? '' : 's'}.'),
          ),
        );
        Navigator.pop(context, added);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
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
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final paymentPresets =
        ref.watch(paymentMethodPresetsProvider).valueOrNull ?? const [];
    final payeePresets =
        ref.watch(payeePresetsProvider).valueOrNull ?? const [];

    final ofType = categories
        .where((c) => c.type.name == _type.name)
        .toList(growable: false);
    final categoryId = ofType.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;

    final schedule = _schedule;
    final problem = schedule.validate();
    final generated = schedule.generate();

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk add')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'For things that already happened but were never entered, like a '
            'monthly salary or rent. You can edit every entry on the next step.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TransactionFormSection(
            title: 'What',
            child: Column(
              children: [
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) => setState(() {
                    _type = value.first;
                    _categoryId = null;
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Salary, Rent, Insurance...',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  key: ValueKey(_type),
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  hint: const Text('Select category'),
                  items: [
                    for (final c in ofType)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TransactionFormSection(
            title: 'Payment info',
            child: Column(
              children: [
                TransactionPresetField(
                  label: 'Payment Method',
                  hintText: 'Cash, UPI, Card...',
                  emptyStateText: 'No payment method presets yet.',
                  controller: _payment,
                  presets: paymentPresets,
                ),
                const SizedBox(height: 16),
                TransactionPresetField(
                  label: 'Store / Payment To',
                  hintText: 'Merchant, employer, person...',
                  emptyStateText: 'No store or payee presets yet.',
                  controller: _payee,
                  presets: payeePresets,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TransactionFormSection(
            title: 'How often',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in BulkFrequency.values)
                      ChoiceChip(
                        label: Text(f.label),
                        selected: f == _frequency,
                        onSelected: (_) => setState(() => _frequency = f),
                      ),
                  ],
                ),
                if (_frequency == BulkFrequency.custom) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Every'),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _customEvery,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<BulkUnit>(
                          initialValue: _customUnit,
                          items: [
                            for (final u in BulkUnit.values)
                              DropdownMenuItem(value: u, child: Text(u.name)),
                          ],
                          onChanged: (value) => setState(
                            () => _customUnit = value ?? _customUnit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DateTile(
                        label: 'From',
                        date: _from,
                        onTap: () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateTile(
                        label: 'To',
                        date: _to,
                        onTap: () => _pickDate(isFrom: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  problem ??
                      '${generated.dates.length} entr'
                          '${generated.dates.length == 1 ? 'y' : 'ies'}'
                          '${generated.truncated ? ' (stopped at the $maxBulkRows-row limit)' : ''}',
                  style: TextStyle(
                    color: problem != null ? scheme.error : scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _isBusy || problem != null
                ? null
                : () => _review(ofType),
            child: _isBusy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Review ${generated.dates.length} '
                    'entr${generated.dates.length == 1 ? 'y' : 'ies'}',
                  ),
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              bulkDateFormat.format(date),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
