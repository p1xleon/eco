import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../providers/recurring_transaction_provider.dart';

class RecurringTransactionsPage extends ConsumerStatefulWidget {
  const RecurringTransactionsPage({super.key});

  @override
  ConsumerState<RecurringTransactionsPage> createState() =>
      _RecurringTransactionsPageState();
}

class _RecurringTransactionsPageState
    extends ConsumerState<RecurringTransactionsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      body: const RecurringTransactionsView(showInlineAddButton: true),
    );
  }
}

class RecurringTransactionsView extends ConsumerStatefulWidget {
  final bool showInlineAddButton;

  const RecurringTransactionsView({
    super.key,
    this.showInlineAddButton = false,
  });

  @override
  ConsumerState<RecurringTransactionsView> createState() =>
      _RecurringTransactionsViewState();
}

class _RecurringTransactionsViewState
    extends ConsumerState<RecurringTransactionsView> {
  @override
  Widget build(BuildContext context) {
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final dueAsync = ref.watch(dueRecurringTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final service = ref.read(recurringTransactionServiceProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.showInlineAddButton) ...[
            categoriesAsync.when(
              data: (categories) => Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _openEditor(categories: categories),
                  icon: const Icon(Icons.add),
                  label: const Text('Add recurring transaction'),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
          ],
          dueAsync.when(
            data: (dueItems) {
              if (dueItems.isEmpty) {
                return const _EmptyDueState();
              }

              final overdueCount = dueItems
                  .where((item) => service.isOverdue(item))
                  .length;

              return _DueSectionHeader(
                dueCount: dueItems.length,
                overdueCount: overdueCount,
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(e.toString()),
          ),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (categories) {
              final categoryMap = {
                for (final item in categories) item.id: item,
              };

              return dueAsync.when(
                data: (dueItems) {
                  if (dueItems.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: dueItems
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RecurringTemplateCard(
                              template: item,
                              category: categoryMap[item.categoryId],
                              isDue: true,
                              isOverdue: service.isOverdue(item),
                              onConfirm: () => _confirmTemplate(item),
                              onSkip: () => _skipTemplate(item),
                              onEdit: () => _openEditor(
                                categories: categories,
                                initial: item,
                              ),
                              onDelete: () => _deleteTemplate(item),
                              onToggleActive: (value) =>
                                  _toggleTemplate(item, value),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text(e.toString()),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(e.toString()),
          ),
          const SizedBox(height: 12),
          Text(
            'All Templates',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) {
              final categoryMap = {
                for (final item in categories) item.id: item,
              };

              return recurringAsync.when(
                data: (templates) {
                  if (templates.isEmpty) {
                    return const _EmptyTemplatesState();
                  }

                  return Column(
                    children: templates
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RecurringTemplateCard(
                              template: item,
                              category: categoryMap[item.categoryId],
                              isDue: service.isDue(item),
                              isOverdue: service.isOverdue(item),
                              onConfirm: service.isDue(item)
                                  ? () => _confirmTemplate(item)
                                  : null,
                              onSkip: service.isDue(item)
                                  ? () => _skipTemplate(item)
                                  : null,
                              onEdit: () => _openEditor(
                                categories: categories,
                                initial: item,
                              ),
                              onDelete: () => _deleteTemplate(item),
                              onToggleActive: (value) =>
                                  _toggleTemplate(item, value),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(e.toString()),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(e.toString()),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(recurringTransactionsProvider);
    ref.invalidate(dueRecurringTransactionsProvider);
    ref.invalidate(transactionsProvider);
    await ref.read(recurringTransactionsProvider.future);
  }

  Future<void> _openEditor({
    required List<CategoryModel> categories,
    RecurringTransactionModel? initial,
  }) async {
    try {
      final service = ref.read(recurringTransactionServiceProvider);
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _RecurringTemplateEditorSheet(
          categories: categories,
          initial: initial,
          onSave: (template) async {
            await service.saveTemplate(template);
            return true;
          },
        ),
      );

      if (saved == true) {
        await _refresh();
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _confirmTemplate(RecurringTransactionModel template) async {
    final service = ref.read(recurringTransactionServiceProvider);
    double? amount;

    if (template.amountType == RecurringAmountType.variable) {
      amount = await _promptForAmount(template.defaultAmount);
      if (amount == null) return;
    }

    try {
      await service.confirmRecurringTransaction(template, amount: amount);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _skipTemplate(RecurringTransactionModel template) async {
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Occurrence'),
        content: Text('Skip the due occurrence for "${template.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (shouldSkip != true) return;

    try {
      final service = ref.read(recurringTransactionServiceProvider);
      await service.skipRecurringTransaction(template);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleTemplate(
    RecurringTransactionModel template,
    bool isActive,
  ) async {
    try {
      final service = ref.read(recurringTransactionServiceProvider);
      template.isActive = isActive;
      await service.saveTemplate(template);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteTemplate(RecurringTransactionModel template) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Template'),
        content: Text(
          'Delete "${template.title}"? Past transactions stay as-is.',
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

    if (shouldDelete != true) return;

    try {
      final service = ref.read(recurringTransactionServiceProvider);
      await service.deleteTemplate(template.id);
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<double?> _promptForAmount(double? initialAmount) async {
    final controller = TextEditingController(
      text: initialAmount?.toStringAsFixed(2) ?? '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Amount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null || amount <= 0) {
                return;
              }

              Navigator.pop(context, amount);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_buildErrorMessage(error))));
  }

  String _buildErrorMessage(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'Failed to update recurring transaction.';
    }

    return message;
  }
}

class _DueSectionHeader extends StatelessWidget {
  final int dueCount;
  final int overdueCount;

  const _DueSectionHeader({required this.dueCount, required this.overdueCount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(Icons.event_repeat_rounded, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dueCount recurring item${dueCount == 1 ? '' : 's'} due',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  overdueCount == 0
                      ? 'Everything due today is ready for confirmation.'
                      : '$overdueCount overdue and needs attention.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringTemplateCard extends StatelessWidget {
  final RecurringTransactionModel template;
  final CategoryModel? category;
  final bool isDue;
  final bool isOverdue;
  final VoidCallback? onConfirm;
  final VoidCallback? onSkip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  const _RecurringTemplateCard({
    required this.template,
    required this.category,
    required this.isDue,
    required this.isOverdue,
    required this.onConfirm,
    required this.onSkip,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = template.type == TransactionType.expense
        ? scheme.error
        : scheme.primary;
    final categoryColor = category != null ? Color(category!.color) : accent;
    final dateFormat = DateFormat('dd MMM yyyy');
    final chips = <Widget>[
      _MetaChip(label: _intervalLabel(template), color: scheme.secondary),
      if (category != null)
        _MetaChip(label: category!.name, color: categoryColor),
      _MetaChip(
        label: template.amountType == RecurringAmountType.fixed
            ? 'Fixed ${template.defaultAmount != null ? '₹${template.defaultAmount!.toStringAsFixed(2)}' : ''}'
                  .trim()
            : 'Variable amount',
        color: accent,
      ),
      if (!template.isActive) _MetaChip(label: 'Paused', color: scheme.outline),
      if (isOverdue) _MetaChip(label: 'Overdue', color: scheme.error),
      if (!isOverdue && isDue && template.isActive)
        _MetaChip(label: 'Due today', color: scheme.primary),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Next due ${dateFormat.format(template.nextDueDate)}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(value: template.isActive, onChanged: onToggleActive),
              ],
            ),
            if (template.note != null && template.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                template.note!.trim(),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onConfirm != null)
                  FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirm'),
                  ),
                if (onSkip != null)
                  OutlinedButton.icon(
                    onPressed: onSkip,
                    icon: const Icon(Icons.skip_next_outlined),
                    label: const Text('Skip'),
                  ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _intervalLabel(RecurringTransactionModel template) {
    final unit = switch (template.intervalType) {
      RecurringIntervalType.daily => 'day',
      RecurringIntervalType.weekly => 'week',
      RecurringIntervalType.monthly => 'month',
      RecurringIntervalType.yearly => 'year',
    };

    if (template.intervalCount == 1) {
      return 'Every $unit';
    }

    return 'Every ${template.intervalCount} ${unit}s';
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RecurringTemplateEditorSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final RecurringTransactionModel? initial;
  final Future<bool> Function(RecurringTransactionModel template) onSave;

  const _RecurringTemplateEditorSheet({
    required this.categories,
    required this.initial,
    required this.onSave,
  });

  @override
  State<_RecurringTemplateEditorSheet> createState() =>
      _RecurringTemplateEditorSheetState();
}

class _RecurringTemplateEditorSheetState
    extends State<_RecurringTemplateEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _accountIdController;
  late final TextEditingController _intervalCountController;
  late final TextEditingController _noteController;

  late TransactionType _type;
  late RecurringAmountType _amountType;
  late RecurringIntervalType _intervalType;
  late DateTime _nextDueDate;
  late bool _isActive;
  int? _categoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _amountController = TextEditingController(
      text: initial?.defaultAmount?.toStringAsFixed(2) ?? '',
    );
    _accountIdController = TextEditingController(
      text: initial?.accountId ?? '',
    );
    _intervalCountController = TextEditingController(
      text: (initial?.intervalCount ?? 1).toString(),
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    _type = initial?.type ?? TransactionType.expense;
    _amountType = initial?.amountType ?? RecurringAmountType.fixed;
    _intervalType = initial?.intervalType ?? RecurringIntervalType.monthly;
    _nextDueDate = initial?.nextDueDate ?? DateTime.now();
    _isActive = initial?.isActive ?? true;
    _categoryId =
        initial?.categoryId ??
        widget.categories
            .where((item) => item.type.name == _type.name)
            .firstOrNull
            ?.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _accountIdController.dispose();
    _intervalCountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final filteredCategories = widget.categories
        .where((item) => item.type.name == _type.name)
        .toList();
    final validCategoryIds = filteredCategories.map((item) => item.id).toSet();

    if (_categoryId != null && !validCategoryIds.contains(_categoryId)) {
      _categoryId = filteredCategories.firstOrNull?.id;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null
                    ? 'New recurring template'
                    : 'Edit recurring template',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
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
                  });
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<RecurringAmountType>(
                segments: const [
                  ButtonSegment(
                    value: RecurringAmountType.fixed,
                    label: Text('Fixed'),
                  ),
                  ButtonSegment(
                    value: RecurringAmountType.variable,
                    label: Text('Variable'),
                  ),
                ],
                selected: {_amountType},
                onSelectionChanged: (value) {
                  setState(() {
                    _amountType = value.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _amountType == RecurringAmountType.fixed
                      ? 'Default amount'
                      : 'Default amount (optional hint)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: filteredCategories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountIdController,
                decoration: const InputDecoration(
                  labelText: 'Account ID (optional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurringIntervalType>(
                initialValue: _intervalType,
                decoration: const InputDecoration(labelText: 'Repeat interval'),
                items: RecurringIntervalType.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _intervalType = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _intervalCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText:
                      'Interval count(eg: 2 for every 2 months, or 3 for every 3 weeks)',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next due date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_nextDueDate)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDueDate,
              ),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveTemplate,
                  child: Text(_isSaving ? 'Saving...' : 'Save template'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _nextDueDate = picked;
    });
  }

  Future<void> _saveTemplate() async {
    final title = _titleController.text.trim();
    final intervalCount = int.tryParse(_intervalCountController.text.trim());
    final defaultAmountText = _amountController.text.trim();
    final defaultAmount = defaultAmountText.isEmpty
        ? null
        : double.tryParse(defaultAmountText);

    if (title.isEmpty ||
        _categoryId == null ||
        intervalCount == null ||
        intervalCount <= 0) {
      return;
    }

    if (defaultAmountText.isNotEmpty && defaultAmount == null) {
      return;
    }

    if (_amountType == RecurringAmountType.fixed &&
        (defaultAmount == null || defaultAmount <= 0)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final template = widget.initial ?? RecurringTransactionModel();
    final createdAt = widget.initial?.createdAt ?? DateTime.now();

    template
      ..title = title
      ..type = _type
      ..defaultAmount = defaultAmount
      ..amountType = _amountType
      ..categoryId = _categoryId!
      ..accountId = _accountIdController.text.trim().isEmpty
          ? null
          : _accountIdController.text.trim()
      ..intervalType = _intervalType
      ..intervalCount = intervalCount
      ..nextDueDate = _nextDueDate
      ..isActive = _isActive
      ..note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim()
      ..createdAt = createdAt;

    final saved = await widget.onSave(template);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (saved) {
      Navigator.pop(context, true);
    }
  }
}

class _EmptyDueState extends StatelessWidget {
  const _EmptyDueState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text('No recurring items are due right now.'),
    );
  }
}

class _EmptyTemplatesState extends StatelessWidget {
  const _EmptyTemplatesState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Create a recurring template for bills, subscriptions, or salary.',
        ),
      ),
    );
  }
}
