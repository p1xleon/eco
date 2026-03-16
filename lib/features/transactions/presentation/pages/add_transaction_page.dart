import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/transaction_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../settings/data/models/transaction_preset_model.dart';
import '../../../settings/presentation/providers/transaction_preset_provider.dart';
import '../../data/providers/transaction_repository_provider.dart';
import '../providers/transaction_provider.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final TransactionModel? initialTransaction;

  const AddTransactionPage({super.key, this.initialTransaction});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _payeeController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  int? _categoryId;

  bool get _isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.initialTransaction;
    if (transaction == null) return;

    _titleController.text = transaction.title;
    _amountController.text = transaction.amount.toStringAsFixed(2);
    _paymentMethodController.text = transaction.paymentMethod ?? '';
    _payeeController.text = transaction.payee ?? '';
    _noteController.text = transaction.note ?? '';
    _type = transaction.type;
    _date = transaction.date;
    _categoryId = transaction.categoryId;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text);
    final paymentMethod = _paymentMethodController.text.trim();
    final payee = _payeeController.text.trim();

    if (title.isEmpty || amount == null || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter title, amount, and category.')),
      );
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    final transaction = widget.initialTransaction ?? TransactionModel();
    final now = DateTime.now().toUtc();

    transaction
      ..id = widget.initialTransaction?.id ?? transaction.id
      ..remoteId = widget.initialTransaction?.remoteId
      ..title = title
      ..amount = amount
      ..date = _date
      ..type = _type
      ..categoryId = _categoryId!
      ..paymentMethod = paymentMethod.isEmpty ? null : paymentMethod
      ..payee = payee.isEmpty ? null : payee
      ..note = _noteController.text
      ..createdAt = widget.initialTransaction?.createdAt ?? now
      ..updatedAt = _isEditing ? now : null;

    try {
      final saved = _isEditing
          ? await repo.update(transaction)
          : await repo.add(transaction);
      ref.invalidate(transactionsProvider);

      if (mounted) {
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_buildErrorMessage(e)),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() => _date = result);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _paymentMethodController.dispose();
    _payeeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _buildErrorMessage(Object error) {
    final message = error.toString();

    if (message.isEmpty) {
      return _isEditing
          ? 'Failed to update transaction.'
          : 'Failed to save transaction.';
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodPresetsAsync = ref.watch(paymentMethodPresetsProvider);
    final payeePresetsAsync = ref.watch(payeePresetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          return paymentMethodPresetsAsync.when(
            data: (paymentMethodPresets) {
              return payeePresetsAsync.when(
                data: (payeePresets) {
                  final filtered = categories
                      .where((c) => c.type.name == _type.name)
                      .toList();

                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Amount'),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),

                        const SizedBox(height: 16),

                        SegmentedButton<TransactionType>(
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
                          onSelectionChanged: (value) {
                            setState(() {
                              _type = value.first;
                              _categoryId = null;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        DropdownButtonFormField<int>(
                          initialValue: _categoryId,
                          hint: const Text("Select Category"),
                          items: filtered
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),

                        const SizedBox(height: 16),

                        _PresetField(
                          label: 'Payment Method',
                          hintText: 'Type or tap a preset',
                          emptyStateText: 'No payment method presets yet.',
                          controller: _paymentMethodController,
                          presets: paymentMethodPresets,
                          onPresetSelected: (value) {
                            _paymentMethodController.text = value;
                            setState(() {});
                          },
                        ),

                        const SizedBox(height: 16),

                        _PresetField(
                          label: 'Store / Payment To',
                          hintText: 'Type or tap a preset',
                          emptyStateText: 'No store or payee presets yet.',
                          controller: _payeeController,
                          presets: payeePresets,
                          onPresetSelected: (value) {
                            _payeeController.text = value;
                            setState(() {});
                          },
                        ),

                        const SizedBox(height: 16),

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "${_date.year}-${_date.month}-${_date.day}",
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: _pickDate,
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: "Note (optional)",
                          ),
                          maxLines: 3,
                        ),

                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _save,
                          child: Text(_isEditing ? 'Update' : 'Save'),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}

class _PresetField extends StatelessWidget {
  final String label;
  final String hintText;
  final String emptyStateText;
  final TextEditingController controller;
  final List<TransactionPresetModel> presets;
  final ValueChanged<String> onPresetSelected;

  const _PresetField({
    required this.label,
    required this.hintText,
    required this.emptyStateText,
    required this.controller,
    required this.presets,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: hintText),
        ),
        const SizedBox(height: 8),
        Text('Presets', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        if (presets.isEmpty)
          Text(
            emptyStateText,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map(
                  (preset) => ActionChip(
                    label: Text(preset.value),
                    onPressed: () => onPresetSelected(preset.value),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
