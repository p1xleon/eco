import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../settings/data/models/transaction_preset_model.dart';
import '../../presentation/widgets/transaction_form_shared.dart';
import '../domain/bulk_entry.dart';
import '../domain/bulk_schedule.dart';

final bulkDateFormat = DateFormat('d MMM yyyy');

/// Edits one review row. Pops the changed [BulkEntry], or `null` for "remove".
class BulkEntryEditorSheet extends StatefulWidget {
  final BulkEntry entry;
  final List<CategoryModel> categories;
  final List<TransactionPresetModel> paymentMethodPresets;
  final List<TransactionPresetModel> payeePresets;

  const BulkEntryEditorSheet({
    super.key,
    required this.entry,
    required this.categories,
    required this.paymentMethodPresets,
    required this.payeePresets,
  });

  /// Result of [BulkEntryEditorSheet]: the edited row, or [removed].
  static Future<Object?> show(
    BuildContext context, {
    required BulkEntry entry,
    required List<CategoryModel> categories,
    required List<TransactionPresetModel> paymentMethodPresets,
    required List<TransactionPresetModel> payeePresets,
  }) {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BulkEntryEditorSheet(
        entry: entry,
        categories: categories,
        paymentMethodPresets: paymentMethodPresets,
        payeePresets: payeePresets,
      ),
    );
  }

  /// Returned when the user removes the row.
  static const removed = Object();

  @override
  State<BulkEntryEditorSheet> createState() => _BulkEntryEditorSheetState();
}

class _BulkEntryEditorSheetState extends State<BulkEntryEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late final TextEditingController _payment;
  late final TextEditingController _payee;
  late DateTime _date;
  int? _categoryId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _title = TextEditingController(text: e.title);
    _amount = TextEditingController(text: e.amount.toStringAsFixed(2));
    _note = TextEditingController(text: e.note ?? '');
    _payment = TextEditingController(text: e.paymentMethod ?? '');
    _payee = TextEditingController(text: e.payee ?? '');
    _date = e.date;
    _categoryId = widget.categories.any((c) => c.id == e.categoryId)
        ? e.categoryId
        : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    _payment.dispose();
    _payee.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: earliestBulkDate,
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    final title = _title.text.trim();

    if (title.isEmpty || amount == null || _categoryId == null) {
      setState(
        () => _error = 'Enter a title, an amount above zero and a category.',
      );
      return;
    }

    Navigator.pop(
      context,
      widget.entry.copyWith(
        date: _date,
        amount: amount,
        title: title,
        categoryId: _categoryId,
        payee: _payee.text.trim(),
        paymentMethod: _payment.text.trim(),
        note: _note.text.trim(),
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
            'Edit entry',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _pickDate,
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(bulkDateFormat.format(_date))),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
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
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(context, BulkEntryEditorSheet.removed),
                icon: Icon(Icons.delete_outline, color: scheme.error),
                label: Text('Remove', style: TextStyle(color: scheme.error)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
