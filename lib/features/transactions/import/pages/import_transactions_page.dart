import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../recurring/data/models/recurring_transaction_model.dart';
import '../../../recurring/presentation/providers/recurring_transaction_provider.dart';
import '../../../settings/data/models/transaction_preset_model.dart';
import '../../../settings/presentation/providers/transaction_preset_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../presentation/providers/transaction_provider.dart';
import '../../presentation/widgets/transaction_form_shared.dart';
import '../models/field_type.dart';
import '../models/import_session.dart';
import '../models/import_transaction_draft.dart';
import '../providers/import_controller.dart';
import '../services/import_parser.dart';

class ImportTransactionsPage extends ConsumerStatefulWidget {
  const ImportTransactionsPage({super.key});

  @override
  ConsumerState<ImportTransactionsPage> createState() =>
      _ImportTransactionsPageState();
}

class _ImportTransactionsPageState extends ConsumerState<ImportTransactionsPage> {
  bool _skipInvalidDrafts = true;
  final ScrollController _previewScrollController = ScrollController();

  bool get _hasRequiredMapping {
    final mapping = ref.read(importControllerProvider).columnMapping;
    return mapping[FieldType.amount] != null && mapping[FieldType.date] != null;
  }

  @override
  void dispose() {
    _previewScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(importControllerProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodPresetsAsync = ref.watch(paymentMethodPresetsProvider);
    final payeePresetsAsync = ref.watch(payeePresetsProvider);
    final recurringTemplatesAsync = ref.watch(recurringTransactionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Transactions')),
      floatingActionButton: session.step == ImportStep.preview
          ? Padding(
              padding: const EdgeInsets.only(bottom: 88),
              child: FloatingActionButton.small(
                onPressed: () {
                  _previewScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: const Icon(Icons.vertical_align_top_rounded),
              ),
            )
          : null,
      body: categoriesAsync.when(
        data: (categories) {
          return paymentMethodPresetsAsync.when(
            data: (paymentMethodPresets) {
              return payeePresetsAsync.when(
                data: (payeePresets) {
                  return recurringTemplatesAsync.when(
                    data: (recurringTemplates) {
                      return SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            _StepHeader(
                              currentStep: session.step,
                              onStepTap: (step) {
                                if (_canOpenStep(step, session)) {
                                  ref
                                      .read(importControllerProvider.notifier)
                                      .setStep(step);
                                }
                              },
                            ),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Padding(
                                  key: ValueKey(session.step),
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                  child: _buildStepBody(
                                    context: context,
                                    session: session,
                                    categories: categories,
                                    paymentMethodPresets: paymentMethodPresets,
                                    payeePresets: payeePresets,
                                    recurringTemplates: recurringTemplates,
                                    scheme: scheme,
                                  ),
                                ),
                              ),
                            ),
                            _BottomActionBar(
                              session: session,
                              isBusy: session.isLoading,
                              onBack: _canGoBack(session)
                                  ? () => _goToPreviousStep(session)
                                  : null,
                              onNext: _buildPrimaryAction(
                                context: context,
                                session: session,
                                categories: categories,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text(error.toString())),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(error.toString())),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  Widget _buildStepBody({
    required BuildContext context,
    required ImportSession session,
    required List<CategoryModel> categories,
    required List<TransactionPresetModel> paymentMethodPresets,
    required List<TransactionPresetModel> payeePresets,
    required List<RecurringTransactionModel> recurringTemplates,
    required ColorScheme scheme,
  }) {
    final messageCard = session.errorMessage == null
        ? null
        : _ImportMessageCard(
            color: scheme.errorContainer,
            foreground: scheme.onErrorContainer,
            icon: Icons.error_outline_rounded,
            message: session.errorMessage!,
          );

    return switch (session.step) {
      ImportStep.upload => ListView(
        children: [
          if (messageCard != null) ...[
            messageCard,
            const SizedBox(height: 12),
          ],
          _UploadStep(
            session: session,
            onPickFile: () => _pickFile(categories),
          ),
        ],
      ),
      ImportStep.mapping => ListView(
        children: [
          if (messageCard != null) ...[
            messageCard,
            const SizedBox(height: 12),
          ],
          _MappingStep(
            session: session,
            onChanged: (fieldType, value) {
              ref.read(importControllerProvider.notifier).updateMapping(
                    fieldType: fieldType,
                    columnName: value,
                    categories: categories,
                  );
            },
          ),
        ],
      ),
      ImportStep.preview => _PreviewStep(
        messageCard: messageCard,
        session: session,
        categories: categories,
        paymentMethodPresets: paymentMethodPresets,
        payeePresets: payeePresets,
        recurringTemplates: recurringTemplates,
        scrollController: _previewScrollController,
        onUpdateDraft: (draft) {
          ref.read(importControllerProvider.notifier).updateDraft(draft);
        },
        onToggleSelection: (draftId, isSelected) {
          ref
              .read(importControllerProvider.notifier)
              .toggleDraftSelection(draftId, isSelected);
        },
        onToggleSelectAll: (isSelected) {
          ref.read(importControllerProvider.notifier).toggleSelectAll(
                isSelected,
              );
        },
        onApplyCategory: () => _applyCategoryToSelected(categories),
        onApplyType: (type) {
          ref.read(importControllerProvider.notifier).applyToSelected(type: type);
        },
        onApplyPaymentMethod: () =>
            _applyPaymentMethodToSelected(paymentMethodPresets),
        onDeleteSelected: () =>
            ref.read(importControllerProvider.notifier).deleteSelected(),
      ),
      ImportStep.confirm => ListView(
        children: [
          if (messageCard != null) ...[
            messageCard,
            const SizedBox(height: 12),
          ],
          _ConfirmStep(
            session: session,
            skipInvalidDrafts: _skipInvalidDrafts,
            onSkipInvalidChanged: (value) {
              setState(() {
                _skipInvalidDrafts = value;
              });
            },
          ),
        ],
      ),
    };
  }

  Future<void> _pickFile(List<CategoryModel> categories) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes ?? await _readFileBytes(file.path);
    if (bytes == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the selected CSV file.')),
      );
      return;
    }

    await ref.read(importControllerProvider.notifier).loadFile(
          fileName: file.name,
          bytes: bytes,
          categories: categories,
        );
  }

  Future<List<int>?> _readFileBytes(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  Future<void> _applyCategoryToSelected(List<CategoryModel> categories) async {
    final selected = ref.read(importControllerProvider).selectedDrafts;
    if (selected.isEmpty) {
      return;
    }

    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              for (final type in [CategoryType.expense, CategoryType.income]) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    type == CategoryType.expense ? 'Expense Categories' : 'Income Categories',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final category in categories.where((item) => item.type == type))
                  ListTile(
                    title: Text(category.name),
                    onTap: () => Navigator.pop(context, category.id),
                  ),
              ],
            ],
          ),
        );
      },
    );

    if (picked == null) {
      return;
    }

    final selectedCategory = categories.where((item) => item.id == picked).firstOrNull;

    ref.read(importControllerProvider.notifier).applyToSelected(
          type: selectedCategory == null
              ? null
              : (selectedCategory.type == CategoryType.expense
                    ? TransactionType.expense
                    : TransactionType.income),
          categoryId: picked,
        );
  }

  Future<void> _applyPaymentMethodToSelected(
    List<TransactionPresetModel> paymentMethodPresets,
  ) async {
    final selected = ref.read(importControllerProvider).selectedDrafts;
    if (selected.isEmpty) {
      return;
    }

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BulkPaymentMethodSheet(
        presets: paymentMethodPresets,
        initialValue: selected.first.paymentMethod ?? '',
      ),
    );

    if (value == null) {
      return;
    }

    ref.read(importControllerProvider.notifier).applyToSelected(
          paymentMethod: value.trim().isEmpty ? null : value.trim(),
          clearPaymentMethod: value.trim().isEmpty,
        );
  }

  VoidCallback? _buildPrimaryAction({
    required BuildContext context,
    required ImportSession session,
    required List<CategoryModel> categories,
  }) {
    if (session.isLoading) {
      return null;
    }

    return switch (session.step) {
      ImportStep.upload => session.rawRows.isEmpty
          ? null
          : () => ref
              .read(importControllerProvider.notifier)
              .setStep(ImportStep.mapping),
      ImportStep.mapping => _hasRequiredMapping && session.drafts.isNotEmpty
          ? () => ref
              .read(importControllerProvider.notifier)
              .setStep(ImportStep.preview)
          : null,
      ImportStep.preview => session.drafts.isEmpty
          ? null
          : () => ref
              .read(importControllerProvider.notifier)
              .setStep(ImportStep.confirm),
      ImportStep.confirm => () => _confirmImport(categories),
    };
  }

  Future<void> _confirmImport(List<CategoryModel> categories) async {
    try {
      final saved = await ref.read(importControllerProvider.notifier).commit(
            skipInvalidDrafts: _skipInvalidDrafts,
            categories: categories,
          );
      final visibilityNotifier = ref.read(
        transactionVisibilityProvider.notifier,
      );
      for (final transaction in saved) {
        visibilityNotifier.registerVisibleTransaction(transaction);
      }
      ref.invalidate(transactionsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${saved.length} transaction${saved.length == 1 ? '' : 's'}.',
          ),
        ),
      );
      Navigator.pop(context, saved.length);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  bool _canOpenStep(ImportStep step, ImportSession session) {
    return switch (step) {
      ImportStep.upload => true,
      ImportStep.mapping => session.rawRows.isNotEmpty,
      ImportStep.preview => session.rawRows.isNotEmpty && _hasRequiredMapping,
      ImportStep.confirm => session.drafts.isNotEmpty && _hasRequiredMapping,
    };
  }

  bool _canGoBack(ImportSession session) => session.step != ImportStep.upload;

  void _goToPreviousStep(ImportSession session) {
    final previous = switch (session.step) {
      ImportStep.upload => ImportStep.upload,
      ImportStep.mapping => ImportStep.upload,
      ImportStep.preview => ImportStep.mapping,
      ImportStep.confirm => ImportStep.preview,
    };
    ref.read(importControllerProvider.notifier).setStep(previous);
  }
}

class _StepHeader extends StatelessWidget {
  final ImportStep currentStep;
  final ValueChanged<ImportStep> onStepTap;

  const _StepHeader({required this.currentStep, required this.onStepTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const steps = [
      (ImportStep.upload, 'Upload'),
      (ImportStep.mapping, 'Mapping'),
      (ImportStep.preview, 'Preview'),
      (ImportStep.confirm, 'Confirm'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (final (step, label) in steps) ...[
            ChoiceChip(
              label: Text(label),
              selected: currentStep == step,
              onSelected: (_) => onStepTap(step),
            ),
            if (step != ImportStep.confirm)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _UploadStep extends StatelessWidget {
  final ImportSession session;
  final VoidCallback onPickFile;

  const _UploadStep({required this.session, required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TransactionFormSection(
          title: 'CSV Upload',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a CSV file. Nothing is saved yet, we only load the raw rows into a temporary import session.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(session.fileName == null ? 'Choose CSV File' : 'Replace File'),
              ),
              if (session.fileName != null) ...[
                const SizedBox(height: 16),
                _StatPillRow(
                  items: [
                    ('File', session.fileName!),
                    ('Rows', '${session.rawRows.length}'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MappingStep extends StatelessWidget {
  final ImportSession session;
  final void Function(FieldType fieldType, String? value) onChanged;

  const _MappingStep({required this.session, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final headers = session.headers;

    return Column(
      children: [
        TransactionFormSection(
          title: 'Column Mapping',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Match your CSV columns to transaction fields. Amount and date are required. Every mapping change rebuilds the import drafts from raw rows.',
              ),
              const SizedBox(height: 16),
              for (final fieldType in FieldType.values) ...[
                DropdownButtonFormField<String>(
                  initialValue: session.columnMapping[fieldType],
                  decoration: InputDecoration(
                    labelText: fieldType.label,
                    helperText:
                        fieldType == FieldType.amount || fieldType == FieldType.date
                        ? 'Required'
                        : 'Optional',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Not mapped'),
                    ),
                    ...headers.map(
                      (header) => DropdownMenuItem<String>(
                        value: header,
                        child: Text(header),
                      ),
                    ),
                  ],
                  onChanged: (value) => onChanged(
                    fieldType,
                    value == null || value.isEmpty ? null : value,
                  ),
                ),
                if (fieldType != FieldType.paymentMethod)
                  const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewStep extends StatelessWidget {
  final Widget? messageCard;
  final ImportSession session;
  final List<CategoryModel> categories;
  final List<TransactionPresetModel> paymentMethodPresets;
  final List<TransactionPresetModel> payeePresets;
  final List<RecurringTransactionModel> recurringTemplates;
  final ScrollController scrollController;
  final ValueChanged<bool> onToggleSelectAll;
  final void Function(String draftId, bool isSelected) onToggleSelection;
  final ValueChanged<ImportTransactionDraft> onUpdateDraft;
  final VoidCallback onApplyCategory;
  final ValueChanged<TransactionType> onApplyType;
  final VoidCallback onApplyPaymentMethod;
  final VoidCallback onDeleteSelected;

  const _PreviewStep({
    required this.messageCard,
    required this.session,
    required this.categories,
    required this.paymentMethodPresets,
    required this.payeePresets,
    required this.recurringTemplates,
    required this.scrollController,
    required this.onToggleSelectAll,
    required this.onToggleSelection,
    required this.onUpdateDraft,
    required this.onApplyCategory,
    required this.onApplyType,
    required this.onApplyPaymentMethod,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = session.selectedDrafts.length;
    final allSelected =
        session.drafts.isNotEmpty && selectedCount == session.drafts.length;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        if (messageCard != null) ...[
          messageCard!,
          const SizedBox(height: 12),
        ],
        _StatsSection(session: session),
        const SizedBox(height: 12),
        TransactionFormSection(
          title: 'Bulk Actions',
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: (value) => onToggleSelectAll(value ?? false),
                  ),
                  Text('Select all ${session.drafts.length} rows'),
                  const Spacer(),
                  Text('$selectedCount selected'),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: selectedCount == 0 ? null : onApplyCategory,
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('Apply category'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: selectedCount == 0
                        ? null
                        : () => onApplyType(TransactionType.expense),
                    icon: const Icon(Icons.arrow_upward_rounded),
                    label: const Text('Mark expense'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: selectedCount == 0
                        ? null
                        : () => onApplyType(TransactionType.income),
                    icon: const Icon(Icons.arrow_downward_rounded),
                    label: const Text('Mark income'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed:
                        selectedCount == 0 ? null : onApplyPaymentMethod,
                    icon: const Icon(Icons.wallet_outlined),
                    label: const Text('Apply payment method'),
                  ),
                  OutlinedButton.icon(
                    onPressed: selectedCount == 0 ? null : onDeleteSelected,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete rows'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < session.drafts.length; index++) ...[
          _DraftEditableCard(
            key: ValueKey(session.drafts[index].id),
            index: index,
            draft: session.drafts[index],
            categories: categories,
            paymentMethodPresets: paymentMethodPresets,
            payeePresets: payeePresets,
            recurringTemplates: recurringTemplates,
            onToggleSelection: onToggleSelection,
            onChanged: onUpdateDraft,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final ImportSession session;
  final bool skipInvalidDrafts;
  final ValueChanged<bool> onSkipInvalidChanged;

  const _ConfirmStep({
    required this.session,
    required this.skipInvalidDrafts,
    required this.onSkipInvalidChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatsSection(session: session),
        const SizedBox(height: 12),
        TransactionFormSection(
          title: 'Ready To Import',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Valid rows will be converted into the same saved transactions used everywhere else in the app. Raw CSV data is not persisted.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Skip invalid drafts'),
                subtitle: Text(
                  skipInvalidDrafts
                      ? 'Only valid rows will be imported.'
                      : 'Import is blocked until every row is valid.',
                ),
                value: skipInvalidDrafts,
                onChanged: onSkipInvalidChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final ImportSession session;

  const _StatsSection({required this.session});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹ ');

    return TransactionFormSection(
      title: 'Import Summary',
      child: _StatPillRow(
        items: [
          ('Total', '${session.stats.total}'),
          ('Valid', '${session.stats.validCount}'),
          ('Errors', '${session.stats.errorCount}'),
          ('Income', currency.format(session.stats.totalIncome)),
          ('Expense', currency.format(session.stats.totalExpense)),
        ],
      ),
    );
  }
}

class _DraftEditableCard extends StatefulWidget {
  final int index;
  final ImportTransactionDraft draft;
  final List<CategoryModel> categories;
  final List<TransactionPresetModel> paymentMethodPresets;
  final List<TransactionPresetModel> payeePresets;
  final List<RecurringTransactionModel> recurringTemplates;
  final void Function(String draftId, bool isSelected) onToggleSelection;
  final ValueChanged<ImportTransactionDraft> onChanged;

  const _DraftEditableCard({
    super.key,
    required this.index,
    required this.draft,
    required this.categories,
    required this.paymentMethodPresets,
    required this.payeePresets,
    required this.recurringTemplates,
    required this.onToggleSelection,
    required this.onChanged,
  });

  @override
  State<_DraftEditableCard> createState() => _DraftEditableCardState();
}

class _DraftEditableCardState extends State<_DraftEditableCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _payeeController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title ?? '');
    _amountController = TextEditingController(
      text: widget.draft.amount?.toStringAsFixed(2) ?? '',
    );
    _payeeController = TextEditingController(text: widget.draft.payee ?? '');
    _paymentMethodController = TextEditingController(
      text: widget.draft.paymentMethod ?? '',
    );
    _noteController = TextEditingController(text: widget.draft.note ?? '');
  }

  @override
  void didUpdateWidget(covariant _DraftEditableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_titleController, widget.draft.title ?? '');
    _syncController(
      _amountController,
      widget.draft.amount?.toStringAsFixed(2) ?? '',
    );
    _syncController(_payeeController, widget.draft.payee ?? '');
    _syncController(
      _paymentMethodController,
      widget.draft.paymentMethod ?? '',
    );
    _syncController(_noteController, widget.draft.note ?? '');
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _payeeController.dispose();
    _paymentMethodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draft = widget.draft;
    final typeCategories = widget.categories
        .where(
          (category) =>
              category.type ==
              (draft.type == TransactionType.expense
                  ? CategoryType.expense
                  : CategoryType.income),
        )
        .toList(growable: false);
    final categoryName = draft.categoryId == null
        ? 'No category'
        : widget.categories
              .where((category) => category.id == draft.categoryId)
              .firstOrNull
              ?.name ??
          'Unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: draft.isValid
            ? scheme.surface
            : scheme.errorContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: draft.isValid ? scheme.outlineVariant : scheme.error,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: draft.isSelected,
                onChanged: (value) =>
                    widget.onToggleSelection(draft.id, value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Row ${widget.index + 1}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      buildImportedTransactionTitle(
                        draft,
                        {
                          for (final category in widget.categories)
                            category.id: category,
                        },
                      ),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: draft.isValid
                      ? scheme.primaryContainer
                      : scheme.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  draft.isValid ? 'Ready' : 'Needs fixes',
                  style: TextStyle(
                    color: draft.isValid
                        ? scheme.onPrimaryContainer
                        : scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Item, description, or transaction title',
            ),
            onChanged: (value) => _emitUpdate(
              draft.copyWith(title: value, clearTitle: value.trim().isEmpty),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment<TransactionType>(
                value: TransactionType.expense,
                label: Text('Expense'),
                icon: Icon(Icons.arrow_upward_rounded),
              ),
              ButtonSegment<TransactionType>(
                value: TransactionType.income,
                label: Text('Income'),
                icon: Icon(Icons.arrow_downward_rounded),
              ),
            ],
            selected: {draft.type},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final nextType = selection.first;
              final selectedCategory = widget.categories
                  .where((category) => category.id == draft.categoryId)
                  .firstOrNull;
              final shouldClearCategory =
                  selectedCategory != null &&
                  selectedCategory.type !=
                      (nextType == TransactionType.expense
                          ? CategoryType.expense
                          : CategoryType.income);
              _emitUpdate(
                draft.copyWith(
                  type: nextType,
                  clearCategoryId: shouldClearCategory,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '-120.00 or 120.00',
                  ),
                  onSubmitted: (_) => _applyAmount(),
                  onEditingComplete: _applyAmount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('category-${draft.id}-${draft.categoryId}'),
                  initialValue: draft.categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: typeCategories
                      .map(
                        (category) => DropdownMenuItem<int>(
                          value: category.id,
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  isExpanded: true,
                  onChanged: (value) {
                    final selectedCategory = typeCategories
                        .where((category) => category.id == value)
                        .firstOrNull;
                    _emitUpdate(
                      draft.copyWith(
                        type: selectedCategory == null
                            ? draft.type
                            : (selectedCategory.type == CategoryType.expense
                                  ? TransactionType.expense
                                  : TransactionType.income),
                        categoryId: value,
                        clearCategoryId: value == null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _pickDate,
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          draft.date == null
                              ? 'Pick a valid date'
                              : DateFormat('MMMM d, yyyy').format(draft.date!),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _payeeController,
                  decoration: const InputDecoration(
                    labelText: 'Payee / Store',
                    hintText: 'Store, merchant, employer...',
                  ),
                  onChanged: (value) => _emitUpdate(
                    draft.copyWith(
                      payee: value,
                      clearPayee: value.trim().isEmpty,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _paymentMethodController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    hintText: 'Cash, UPI, Card...',
                  ),
                  onChanged: (value) => _emitUpdate(
                    draft.copyWith(
                      paymentMethod: value,
                      clearPaymentMethod: value.trim().isEmpty,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.payeePresets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.payeePresets.map((preset) {
                return ActionChip(
                  label: Text(preset.value),
                  onPressed: () {
                    _payeeController.text = preset.value;
                    _emitUpdate(widget.draft.copyWith(payee: preset.value));
                  },
                );
              }).toList(growable: false),
            ),
          ],
          if (widget.paymentMethodPresets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.paymentMethodPresets.map((preset) {
                return ActionChip(
                  label: Text(preset.value),
                  onPressed: () {
                    _paymentMethodController.text = preset.value;
                    _emitUpdate(draft.copyWith(paymentMethod: preset.value));
                  },
                );
              }).toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('recurring-${draft.id}-${draft.recurringTemplateId}'),
            initialValue: draft.recurringTemplateId ?? -1,
            decoration: const InputDecoration(labelText: 'Recurring Template'),
            items: [
              const DropdownMenuItem<int>(value: -1, child: Text('None')),
              ...widget.recurringTemplates.map(
                (template) => DropdownMenuItem<int>(
                  value: template.id,
                  child: Text(template.title),
                ),
              ),
            ],
            onChanged: (value) {
              final selectedTemplate = value == null || value == -1
                  ? null
                  : widget.recurringTemplates
                        .where((template) => template.id == value)
                        .firstOrNull;
              if (selectedTemplate != null) {
                _titleController.text = selectedTemplate.title;
              }
              _emitUpdate(
                draft.copyWith(
                  recurringTemplateId: value == null || value == -1 ? null : value,
                  clearRecurringTemplateId: value == null || value == -1,
                  title: selectedTemplate?.title ?? draft.title,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Optional context or reminder',
            ),
            onChanged: (value) => _emitUpdate(
              draft.copyWith(
                note: value,
                clearNote: value.trim().isEmpty,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$categoryName${draft.paymentMethod?.trim().isNotEmpty == true ? ' • ${draft.paymentMethod!.trim()}' : ''}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (draft.errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final error in draft.errors)
                  Chip(
                    backgroundColor: scheme.errorContainer,
                    label: Text(error),
                    labelStyle: TextStyle(color: scheme.onErrorContainer),
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: widget.draft.date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (result == null) {
      return;
    }

    _emitUpdate(widget.draft.copyWith(date: result));
  }

  void _emitUpdate(ImportTransactionDraft draft) {
    widget.onChanged(draft);
  }

  void _applyAmount() {
    final value = _amountController.text.trim();
    final parsed = double.tryParse(value);
    _emitUpdate(
      widget.draft.copyWith(
        amount: parsed,
        clearAmount: parsed == null,
      ),
    );
  }
}

class _BulkPaymentMethodSheet extends StatefulWidget {
  final List<TransactionPresetModel> presets;
  final String initialValue;

  const _BulkPaymentMethodSheet({
    required this.presets,
    required this.initialValue,
  });

  @override
  State<_BulkPaymentMethodSheet> createState() => _BulkPaymentMethodSheetState();
}

class _BulkPaymentMethodSheetState extends State<_BulkPaymentMethodSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TransactionFormSection(
              title: 'Apply Payment Method',
              child: TransactionPresetField(
                label: 'Payment Method',
                hintText: 'Cash, UPI, Card...',
                emptyStateText: 'No payment method presets yet.',
                controller: _controller,
                presets: widget.presets,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _controller.text),
                child: const Text('Apply To Selected'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final ImportSession session;
  final bool isBusy;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  const _BottomActionBar({
    required this.session,
    required this.isBusy,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 1),
          ),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: isBusy ? null : onBack,
            child: const Text('Back'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: isBusy ? null : onNext,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Text(
                isBusy
                    ? 'Working...'
                    : switch (session.step) {
                        ImportStep.upload => 'Continue',
                        ImportStep.mapping => 'Preview Drafts',
                        ImportStep.preview => 'Review Summary',
                        ImportStep.confirm => 'Confirm Import',
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportMessageCard extends StatelessWidget {
  final Color color;
  final Color foreground;
  final IconData icon;
  final String message;

  const _ImportMessageCard({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPillRow extends StatelessWidget {
  final List<(String, String)> items;

  const _StatPillRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, value) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
