import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../data/models/transaction_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../settings/data/models/transaction_preset_model.dart';
import '../../../settings/presentation/providers/transaction_preset_provider.dart';
import '../../data/providers/transaction_repository_provider.dart';
import '../providers/transaction_provider.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final TransactionModel? initialTransaction;
  final TransactionModel? duplicateTransaction;

  const AddTransactionPage({
    super.key,
    this.initialTransaction,
    this.duplicateTransaction,
  });

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
  TransactionStatus _status = TransactionStatus.paid;
  DateTime _date = DateTime.now();
  int? _categoryId;
  bool _isSaving = false;

  bool get _isEditing => widget.initialTransaction != null;
  bool get _isDuplicating => widget.duplicateTransaction != null;

  @override
  void initState() {
    super.initState();

    final transaction =
        widget.initialTransaction ?? widget.duplicateTransaction;
    if (transaction == null) return;

    _titleController.text = transaction.title;
    _amountController.text = transaction.amount.toStringAsFixed(2);
    _paymentMethodController.text = transaction.paymentMethod ?? '';
    _payeeController.text = transaction.payee ?? '';
    _noteController.text = transaction.note ?? '';
    _type = transaction.type;
    _status = transaction.status;
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
    final transaction = _isEditing
        ? widget.initialTransaction!
        : TransactionModel();
    final now = DateTime.now().toUtc();

    transaction
      ..id = _isEditing ? widget.initialTransaction!.id : transaction.id
      ..remoteId = _isEditing ? widget.initialTransaction?.remoteId : null
      ..recurringId = _isEditing ? widget.initialTransaction?.recurringId : null
      ..title = title
      ..amount = amount
      ..date = _date
      ..type = _type
      ..status = _status
      ..categoryId = _categoryId!
      ..paymentMethod = paymentMethod.isEmpty ? null : paymentMethod
      ..payee = payee.isEmpty ? null : payee
      ..note = _noteController.text
      ..createdAt = _isEditing ? widget.initialTransaction!.createdAt : now
      ..updatedAt = _isEditing ? now : null;

    setState(() => _isSaving = true);

    try {
      final saved = _isEditing
          ? await repo.update(transaction)
          : await repo.add(transaction);
      if (!_isEditing) {
        ref
            .read(transactionVisibilityProvider.notifier)
            .registerVisibleTransaction(saved);
      }
      ref.invalidate(transactionsProvider);

      if (mounted) {
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_buildErrorMessage(e))));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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

  String _formatDate(DateTime date) {
    final month = switch (date.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };

    return '$month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodPresetsAsync = ref.watch(paymentMethodPresetsProvider);
    final payeePresetsAsync = ref.watch(payeePresetsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit Transaction'
              : _isDuplicating
              ? 'Duplicate Transaction'
              : 'Add Transaction',
        ),
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

                  return SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                            children: [
                              _FormSection(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isEditing
                                          ? 'Update the transaction details'
                                          : _isDuplicating
                                          ? 'Start from an existing transaction and adjust it'
                                          : 'Add transaction details',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    TextField(
                                      controller: _amountController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Amount',
                                        prefixText: '₹ ',
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _titleController,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: const InputDecoration(
                                        labelText: 'Title',
                                        hintText: 'Groceries, Salary, Rent...',
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    SegmentedButton<TransactionType>(
                                      segments: const [
                                        ButtonSegment(
                                          value: TransactionType.expense,
                                          icon: Icon(Icons.north_east_rounded),
                                          label: Text('Expense'),
                                        ),
                                        ButtonSegment(
                                          value: TransactionType.income,
                                          icon: Icon(Icons.south_west_rounded),
                                          label: Text('Income'),
                                        ),
                                      ],
                                      selected: {_type},
                                      showSelectedIcon: false,
                                      onSelectionChanged: (value) {
                                        setState(() {
                                          _type = value.first;
                                          _categoryId = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    SegmentedButton<TransactionStatus>(
                                      segments: const [
                                        ButtonSegment(
                                          value: TransactionStatus.paid,
                                          icon: Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          label: Text('Paid'),
                                        ),
                                        ButtonSegment(
                                          value: TransactionStatus.pending,
                                          icon: Icon(
                                            Icons.hourglass_bottom_rounded,
                                          ),
                                          label: Text('Pending'),
                                        ),
                                      ],
                                      selected: {_status},
                                      showSelectedIcon: false,
                                      onSelectionChanged: (value) {
                                        setState(() {
                                          _status = value.first;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _FormSection(
                                title: 'Details',
                                child: Column(
                                  children: [
                                    DropdownButtonFormField<int>(
                                      initialValue: _categoryId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Category',
                                      ),
                                      hint: const Text('Select category'),
                                      items: filtered
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(c.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _categoryId = v),
                                    ),
                                    const SizedBox(height: 14),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: _pickDate,
                                      child: Ink(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest
                                              .withValues(alpha: 1),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_month_outlined,
                                              color: scheme.primary,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Date',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatDate(_date),
                                                    style: TextStyle(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _FormSection(
                                title: 'Payment Info',
                                child: Column(
                                  children: [
                                    _PresetField(
                                      label: 'Payment Method',
                                      hintText: 'Cash, UPI, Card...',
                                      emptyStateText:
                                          'No payment method presets yet.',
                                      controller: _paymentMethodController,
                                      presets: paymentMethodPresets,
                                    ),
                                    const SizedBox(height: 16),
                                    _PresetField(
                                      label: 'Store / Payment To',
                                      hintText: 'Merchant, employer, person...',
                                      emptyStateText:
                                          'No store or payee presets yet.',
                                      controller: _payeeController,
                                      presets: payeePresets,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _FormSection(
                                title: 'Notes',
                                child: TextField(
                                  controller: _noteController,
                                  decoration: const InputDecoration(
                                    labelText: 'Note',
                                    hintText: 'Optional context or reminder',
                                  ),
                                  minLines: 3,
                                  maxLines: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            border: Border(
                              top: BorderSide(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 1,
                                ),
                              ),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _save,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Text(
                                  _isSaving
                                      ? (_isEditing
                                            ? 'Updating...'
                                            : 'Saving...')
                                      : (_isEditing
                                            ? 'Update Transaction'
                                            : _status ==
                                                  TransactionStatus.pending
                                            ? 'Save as Pending'
                                            : 'Save Transaction'),
                                ),
                              ),
                            ),
                          ),
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

class _FormSection extends StatelessWidget {
  final String? title;
  final Widget child;

  const _FormSection({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
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

  const _PresetField({
    required this.label,
    required this.hintText,
    required this.emptyStateText,
    required this.controller,
    required this.presets,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: hintText),
        ),
        const SizedBox(height: 10),
        if (presets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Text(
              emptyStateText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else ...[
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, text, _) {
              final value = text.text.trim().toLowerCase();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Presets',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${presets.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets
                        .map((preset) {
                          final isSelected =
                              preset.value.toLowerCase() == value;

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => controller.text = preset.value,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? scheme.primary
                                      : scheme.outlineVariant.withValues(
                                          alpha: 0.8,
                                        ),
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: 0.10,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.add_circle_outline_rounded,
                                    size: 16,
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      preset.value,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? scheme.onPrimaryContainer
                                                : scheme.onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
