import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../recurring/data/models/recurring_transaction_model.dart';
import '../../../recurring/presentation/providers/recurring_transaction_provider.dart';
import '../../../settings/presentation/providers/transaction_preset_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/providers/transaction_repository_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_form_shared.dart';

enum _RecurringLinkMode { existing, create }

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
  final _recurringNameController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  TransactionStatus _status = TransactionStatus.paid;
  DateTime _date = DateTime.now();
  int? _categoryId;
  bool _isSaving = false;

  bool _isRecurringEnabled = false;
  _RecurringLinkMode _recurringLinkMode = _RecurringLinkMode.existing;
  int? _selectedRecurringTemplateId;
  DateTime _newRecurringStartDate = DateTime.now();
  DateTime? _newRecurringEndDate;
  bool _hasEditedRecurringStartDate = false;
  RecurringIntervalType _newRecurringFrequency = RecurringIntervalType.monthly;

  bool get _isEditing => widget.initialTransaction != null;
  bool get _isDuplicating => widget.duplicateTransaction != null;

  @override
  void initState() {
    super.initState();

    final transaction =
        widget.initialTransaction ?? widget.duplicateTransaction;
    if (transaction == null) {
      _newRecurringStartDate = _date;
      return;
    }

    _titleController.text = transaction.title;
    _amountController.text = transaction.amount.toStringAsFixed(2);
    _paymentMethodController.text = transaction.paymentMethod ?? '';
    _payeeController.text = transaction.payee ?? '';
    _noteController.text = transaction.note ?? '';
    _type = transaction.type;
    _status = transaction.status;
    _date = transaction.date;
    _categoryId = transaction.categoryId;
    _isRecurringEnabled = transaction.recurringTemplateId != null;
    _selectedRecurringTemplateId = transaction.recurringTemplateId;
    _newRecurringStartDate = transaction.date;
  }

  Future<void> _save(List<CategoryModel> categories) async {
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

    if (_isRecurringEnabled) {
      if (_recurringLinkMode == _RecurringLinkMode.existing &&
          _selectedRecurringTemplateId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a recurring template.')),
        );
        return;
      }

      if (_recurringLinkMode == _RecurringLinkMode.create &&
          _newRecurringEndDate != null &&
          _newRecurringEndDate!.isBefore(_newRecurringStartDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring end date must be on or after start date.'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final recurringTemplateId = await _resolveRecurringTemplateId(
        categories: categories,
        amount: amount,
      );

      final repo = ref.read(transactionRepositoryProvider);
      final initial = widget.initialTransaction;
      final transaction = _isEditing ? initial! : TransactionModel();
      final now = DateTime.now().toUtc();
      final recurringEnabled = _isRecurringEnabled;

      transaction
        ..id = _isEditing ? initial!.id : transaction.id
        ..remoteId = _isEditing ? initial!.remoteId : null
        ..recurringId = _isEditing ? initial!.recurringId : null
        ..recurringTemplateId = recurringEnabled ? recurringTemplateId : null
        ..isRecurringInstance = recurringEnabled
            ? (_isEditing ? initial!.isRecurringInstance : false)
            : false
        ..title = title
        ..amount = amount
        ..date = _date
        ..type = _type
        ..status = _status
        ..categoryId = _categoryId!
        ..paymentMethod = paymentMethod.isEmpty ? null : paymentMethod
        ..payee = payee.isEmpty ? null : payee
        ..note = _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim()
        ..createdAt = _isEditing ? initial!.createdAt : now
        ..updatedAt = _isEditing ? now : null;

      final saved = _isEditing
          ? await repo.update(transaction)
          : await repo.add(transaction);
      if (!_isEditing) {
        ref
            .read(transactionVisibilityProvider.notifier)
            .registerVisibleTransaction(saved);
      }
      ref.invalidate(transactionsProvider);
      ref.invalidate(recurringTransactionsProvider);

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

  Future<int?> _resolveRecurringTemplateId({
    required List<CategoryModel> categories,
    required double amount,
  }) async {
    if (!_isRecurringEnabled) {
      return null;
    }

    if (_recurringLinkMode == _RecurringLinkMode.existing) {
      return _selectedRecurringTemplateId;
    }

    final service = ref.read(recurringTransactionServiceProvider);
    final categoryName = categories
        .where((item) => item.id == _categoryId)
        .firstOrNull
        ?.name;
    final amountLabel = amount.toStringAsFixed(2);
    final templateName = _recurringNameController.text.trim().isEmpty
        ? '${categoryName ?? 'Transaction'} - ₹$amountLabel'
        : _recurringNameController.text.trim();
    final note = _noteController.text.trim();
    final template = RecurringTransactionModel()
      ..title = templateName
      ..type = _type
      ..defaultAmount = amount
      ..amountType = RecurringAmountType.fixed
      ..categoryId = _categoryId!
      ..intervalType = _newRecurringFrequency
      ..intervalCount = 1
      ..nextDueDate = _newRecurringStartDate
      ..endDate = _newRecurringEndDate
      ..isActive = true
      ..note = note.isEmpty ? null : note
      ..createdAt = DateTime.now().toUtc();

    final savedTemplate = await service.saveTemplate(template);
    _selectedRecurringTemplateId = savedTemplate.id;
    return savedTemplate.id;
  }

  Future<void> _pickDate() async {
    final previousDate = _date;
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() {
        _date = result;
        if (!_hasEditedRecurringStartDate) {
          final oldStart = _newRecurringStartDate;
          final wasFollowingTransactionDate =
              _isSameDate(oldStart, previousDate) || !_isRecurringEnabled;
          if (wasFollowingTransactionDate ||
              _recurringLinkMode == _RecurringLinkMode.create) {
            _newRecurringStartDate = result;
          }
        }
      });
    }
  }

  Future<void> _pickRecurringStartDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _newRecurringStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) return;

    setState(() {
      _newRecurringStartDate = result;
      _hasEditedRecurringStartDate = true;
      if (_newRecurringEndDate != null &&
          _newRecurringEndDate!.isBefore(_newRecurringStartDate)) {
        _newRecurringEndDate = _newRecurringStartDate;
      }
    });
  }

  Future<void> _pickRecurringEndDate() async {
    final initialDate = _newRecurringEndDate ?? _newRecurringStartDate;
    final result = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _newRecurringStartDate,
      lastDate: DateTime(2100),
    );

    if (result == null) return;

    setState(() {
      _newRecurringEndDate = result;
    });
  }

  Future<void> _pickExistingTemplate(
    List<RecurringTransactionModel> templates,
    List<CategoryModel> categories,
  ) async {
    if (templates.isEmpty) return;

    final selected = await showModalBottomSheet<RecurringTransactionModel>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final categoryNames = {
          for (final category in categories) category.id: category.name,
        };

        return SafeArea(
          top: false,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: templates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final template = templates[index];
              final categoryName =
                  categoryNames[template.categoryId] ?? 'Unknown';
              return ListTile(
                title: Text(template.title),
                subtitle: Text(
                  '${_intervalLabel(template.intervalType)} • $categoryName'
                  '${template.defaultAmount != null ? ' • ₹${template.defaultAmount!.toStringAsFixed(2)}' : ''}',
                ),
                trailing: _selectedRecurringTemplateId == template.id
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
                onTap: () => Navigator.pop(context, template),
              );
            },
          ),
        );
      },
    );

    if (selected == null) return;

    _applyTemplateSelection(selected);
  }

  void _applyTemplateSelection(RecurringTransactionModel template) {
    setState(() {
      _selectedRecurringTemplateId = template.id;
      _type = template.type;
      _amountController.text = template.defaultAmount?.toStringAsFixed(2) ?? '';
      _categoryId = template.categoryId;
      if (template.note?.trim().isNotEmpty == true) {
        _noteController.text = template.note!.trim();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _paymentMethodController.dispose();
    _payeeController.dispose();
    _noteController.dispose();
    _recurringNameController.dispose();
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

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _intervalLabel(RecurringIntervalType intervalType) {
    return switch (intervalType) {
      RecurringIntervalType.daily => 'Daily',
      RecurringIntervalType.weekly => 'Weekly',
      RecurringIntervalType.monthly => 'Monthly',
      RecurringIntervalType.yearly => 'Yearly',
    };
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodPresetsAsync = ref.watch(paymentMethodPresetsProvider);
    final payeePresetsAsync = ref.watch(payeePresetsProvider);
    final recurringTemplatesAsync = ref.watch(recurringTransactionsProvider);
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
                  return recurringTemplatesAsync.when(
                    data: (recurringTemplates) {
                      final filtered = categories
                          .where((c) => c.type.name == _type.name)
                          .toList();
                      final effectiveCategoryId =
                          filtered.any((item) => item.id == _categoryId)
                          ? _categoryId
                          : null;
                      final effectiveRecurringLinkMode =
                          _recurringLinkMode == _RecurringLinkMode.existing &&
                              recurringTemplates.isEmpty &&
                              _selectedRecurringTemplateId == null
                          ? _RecurringLinkMode.create
                          : _recurringLinkMode;
                      final selectedTemplate = recurringTemplates
                          .where(
                            (template) =>
                                template.id == _selectedRecurringTemplateId,
                          )
                          .firstOrNull;

                      return SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  120,
                                ),
                                children: [
                                  TransactionFormSection(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            hintText:
                                                'Groceries, Salary, Rent...',
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        SegmentedButton<TransactionType>(
                                          segments: const [
                                            ButtonSegment(
                                              value: TransactionType.expense,
                                              icon: Icon(
                                                Icons.north_east_rounded,
                                              ),
                                              label: Text('Expense'),
                                            ),
                                            ButtonSegment(
                                              value: TransactionType.income,
                                              icon: Icon(
                                                Icons.south_west_rounded,
                                              ),
                                              label: Text('Income'),
                                            ),
                                          ],
                                          selected: {_type},
                                          showSelectedIcon: false,
                                          onSelectionChanged: (value) {
                                            setState(() {
                                              _type = value.first;
                                              _categoryId = null;
                                              if (selectedTemplate != null &&
                                                  selectedTemplate.type !=
                                                      _type) {
                                                _selectedRecurringTemplateId =
                                                    null;
                                              }
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
                                  TransactionFormSection(
                                    title: 'Details',
                                    child: Column(
                                      children: [
                                        DropdownButtonFormField<int>(
                                          initialValue: effectiveCategoryId,
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
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          onTap: _pickDate,
                                          child: Ink(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: scheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 1),
                                              borderRadius:
                                                  BorderRadius.circular(18),
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
                                                        CrossAxisAlignment
                                                            .start,
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
                                  TransactionFormSection(
                                    title: 'Recurring',
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Recurring'),
                                          subtitle: Text(
                                            _isRecurringEnabled
                                                ? 'Link this transaction to a template.'
                                                : 'Keep this as a one-off transaction.',
                                          ),
                                          value: _isRecurringEnabled,
                                          onChanged: (value) {
                                            setState(() {
                                              _isRecurringEnabled = value;
                                              if (!value) {
                                                _selectedRecurringTemplateId =
                                                    null;
                                              } else if (recurringTemplates
                                                  .isEmpty) {
                                                _recurringLinkMode =
                                                    _RecurringLinkMode.create;
                                                _newRecurringStartDate = _date;
                                              }
                                            });
                                          },
                                        ),
                                        if (_isRecurringEnabled) ...[
                                          const SizedBox(height: 8),
                                          SegmentedButton<_RecurringLinkMode>(
                                            segments: const [
                                              ButtonSegment(
                                                value:
                                                    _RecurringLinkMode.existing,
                                                icon: Icon(Icons.link_rounded),
                                                label: Text('Select Existing'),
                                              ),
                                              ButtonSegment(
                                                value:
                                                    _RecurringLinkMode.create,
                                                icon: Icon(
                                                  Icons
                                                      .add_circle_outline_rounded,
                                                ),
                                                label: Text('Create New'),
                                              ),
                                            ],
                                            selected: {
                                              effectiveRecurringLinkMode,
                                            },
                                            showSelectedIcon: false,
                                            onSelectionChanged: (value) {
                                              setState(() {
                                                _recurringLinkMode =
                                                    value.first;
                                                if (_recurringLinkMode ==
                                                    _RecurringLinkMode.create) {
                                                  _newRecurringStartDate =
                                                      _date;
                                                }
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 14),
                                          if (effectiveRecurringLinkMode ==
                                              _RecurringLinkMode.existing)
                                            _ExistingRecurringTemplateSelector(
                                              template: selectedTemplate,
                                              onTap: recurringTemplates.isEmpty
                                                  ? null
                                                  : () => _pickExistingTemplate(
                                                      recurringTemplates,
                                                      categories,
                                                    ),
                                              emptyStateText:
                                                  recurringTemplates.isEmpty
                                                  ? 'No recurring templates yet. Create one inline instead.'
                                                  : 'Choose a recurring template',
                                              frequencyLabel:
                                                  selectedTemplate == null
                                                  ? null
                                                  : _intervalLabel(
                                                      selectedTemplate
                                                          .intervalType,
                                                    ),
                                            )
                                          else
                                            _InlineRecurringTemplateFields(
                                              nameController:
                                                  _recurringNameController,
                                              frequency: _newRecurringFrequency,
                                              startDate: _newRecurringStartDate,
                                              endDate: _newRecurringEndDate,
                                              onFrequencyChanged: (value) {
                                                setState(() {
                                                  _newRecurringFrequency =
                                                      value;
                                                });
                                              },
                                              onStartDateTap:
                                                  _pickRecurringStartDate,
                                              onEndDateTap:
                                                  _pickRecurringEndDate,
                                              onClearEndDate: () {
                                                setState(() {
                                                  _newRecurringEndDate = null;
                                                });
                                              },
                                              formatDate: _formatDate,
                                            ),
                                          if (selectedTemplate != null) ...[
                                            const SizedBox(height: 12),
                                            _RecurringLinkHint(
                                              label:
                                                  'Linked to ${selectedTemplate.title}',
                                              hint: _intervalLabel(
                                                selectedTemplate.intervalType,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TransactionFormSection(
                                    title: 'Payment Info',
                                    child: Column(
                                      children: [
                                        TransactionPresetField(
                                          label: 'Payment Method',
                                          hintText: 'Cash, UPI, Card...',
                                          emptyStateText:
                                              'No payment method presets yet.',
                                          controller: _paymentMethodController,
                                          presets: paymentMethodPresets,
                                        ),
                                        const SizedBox(height: 16),
                                        TransactionPresetField(
                                          label: 'Store / Payment To',
                                          hintText:
                                              'Merchant, employer, person...',
                                          emptyStateText:
                                              'No store or payee presets yet.',
                                          controller: _payeeController,
                                          presets: payeePresets,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TransactionFormSection(
                                    title: 'Notes',
                                    child: TextField(
                                      controller: _noteController,
                                      decoration: const InputDecoration(
                                        labelText: 'Note',
                                        hintText:
                                            'Optional context or reminder',
                                      ),
                                      minLines: 3,
                                      maxLines: 5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
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
                                  onPressed: _isSaving
                                      ? null
                                      : () => _save(categories),
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text(e.toString())),
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

class _ExistingRecurringTemplateSelector extends StatelessWidget {
  final RecurringTransactionModel? template;
  final VoidCallback? onTap;
  final String emptyStateText;
  final String? frequencyLabel;

  const _ExistingRecurringTemplateSelector({
    required this.template,
    required this.onTap,
    required this.emptyStateText,
    required this.frequencyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.event_repeat_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template?.title ?? emptyStateText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (frequencyLabel != null)
                    Text(
                      frequencyLabel!,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Icon(
              onTap == null
                  ? Icons.info_outline_rounded
                  : Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineRecurringTemplateFields extends StatelessWidget {
  final TextEditingController nameController;
  final RecurringIntervalType frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final ValueChanged<RecurringIntervalType> onFrequencyChanged;
  final VoidCallback onStartDateTap;
  final VoidCallback onEndDateTap;
  final VoidCallback onClearEndDate;
  final String Function(DateTime date) formatDate;

  const _InlineRecurringTemplateFields({
    required this.nameController,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.onFrequencyChanged,
    required this.onStartDateTap,
    required this.onEndDateTap,
    required this.onClearEndDate,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<RecurringIntervalType>(
          initialValue: frequency,
          decoration: const InputDecoration(labelText: 'Frequency'),
          items: RecurringIntervalType.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(switch (value) {
                    RecurringIntervalType.daily => 'Daily',
                    RecurringIntervalType.weekly => 'Weekly',
                    RecurringIntervalType.monthly => 'Monthly',
                    RecurringIntervalType.yearly => 'Yearly',
                  }),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onFrequencyChanged(value);
            }
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Template name (optional)',
            hintText: 'Defaults to category + amount',
          ),
        ),
        const SizedBox(height: 14),
        _DateSettingTile(
          title: 'Start date',
          value: formatDate(startDate),
          onTap: onStartDateTap,
        ),
        const SizedBox(height: 10),
        _DateSettingTile(
          title: 'End date',
          value: endDate == null ? 'No end date' : formatDate(endDate!),
          onTap: onEndDateTap,
          trailing: endDate == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear end date',
                  onPressed: onClearEndDate,
                ),
        ),
      ],
    );
  }
}

class _DateSettingTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DateSettingTile({
    required this.title,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(value, style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _RecurringLinkHint extends StatelessWidget {
  final String label;
  final String hint;

  const _RecurringLinkHint({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label • $hint',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
