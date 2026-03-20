import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../categories/data/models/category_model.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../../recurring/presentation/pages/recurring_transactions_page.dart';
import '../../../../shared/widgets/transaction_list_grouped.dart';
import '../providers/transaction_filter.dart';
import '../providers/transaction_filter_provider.dart';
import '../providers/transaction_provider.dart';
import '../../data/models/transaction_model.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool get _isRecurringTab => _tabController.index == 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<void> _refreshTransactions() async {
    await refreshTransactions(ref);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      ref.read(transactionFilterProvider.notifier).setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(transactionFilterProvider);
    final visibility = ref.watch(transactionVisibilityProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final allTransactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions:
            _isRecurringTab || visibility.isMasked || visibility.isInvisible
            ? null
            : [
                IconButton(
                  icon: Badge(
                    isLabelVisible: filter.activeCount > 0,
                    label: Text(filter.activeCount.toString()),
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: () => _openFilterSheet(
                    categories: categoriesAsync.valueOrNull ?? const [],
                    transactions: allTransactionsAsync.valueOrNull ?? const [],
                  ),
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
            Tab(text: 'Recurring'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_isRecurringTab)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search transactions...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: filter.search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(transactionFilterProvider.notifier)
                                    .setSearch('');
                                setState(() {});
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  if (filter.activeCount > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${filter.activeCount} filter${filter.activeCount == 1 ? '' : 's'} active',
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(transactionFilterProvider.notifier)
                                .clearAdvanced();
                            setState(() {});
                          },
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(
                  transactionsAsync: transactionsAsync,
                  filter: (transactions) => transactions,
                  visibility: visibility,
                ),
                _buildTransactionsTab(
                  transactionsAsync: transactionsAsync,
                  filter: (transactions) => transactions
                      .where((tx) => tx.type == TransactionType.expense)
                      .toList(),
                  visibility: visibility,
                ),
                _buildTransactionsTab(
                  transactionsAsync: transactionsAsync,
                  filter: (transactions) => transactions
                      .where((tx) => tx.type == TransactionType.income)
                      .toList(),
                  visibility: visibility,
                ),
                const RecurringTransactionsView(showInlineAddButton: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet({
    required List<CategoryModel> categories,
    required List<TransactionModel> transactions,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TransactionFilterSheet(
        initialFilter: ref.read(transactionFilterProvider),
        categories: categories,
        transactions: transactions,
      ),
    );
  }

  Widget _buildTransactionsTab({
    required AsyncValue<List<TransactionModel>> transactionsAsync,
    required List<TransactionModel> Function(List<TransactionModel>) filter,
    required TransactionVisibilityState visibility,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshTransactions,
      child: transactionsAsync.when(
        data: (transactions) =>
            _buildTransactionList(filter(transactions), visibility),
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 240),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 240),
            Center(child: Text(e.toString())),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(
    List<TransactionModel> transactions,
    TransactionVisibilityState visibility,
  ) {
    if (transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 220),
          Center(
            child: Text(
              visibility.isInvisible
                  ? 'Invisible mode is on. Existing transactions are hidden until you add new ones.'
                  : 'No transactions found',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return TransactionListGrouped(transactions: transactions);
  }
}

class _TransactionFilterSheet extends ConsumerStatefulWidget {
  final TransactionFilter initialFilter;
  final List<CategoryModel> categories;
  final List<TransactionModel> transactions;

  const _TransactionFilterSheet({
    required this.initialFilter,
    required this.categories,
    required this.transactions,
  });

  @override
  ConsumerState<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<_TransactionFilterSheet> {
  late TransactionType? _type;
  late int? _categoryId;
  late String? _paymentMethod;
  late String? _payee;
  late RecurringFilter _recurring;
  late SyncStatusFilter _syncStatus;
  late NotesFilter _notes;
  late DateTime? _startDate;
  late DateTime? _endDate;
  late final TextEditingController _minAmountController;
  late final TextEditingController _maxAmountController;

  @override
  void initState() {
    super.initState();
    final filter = widget.initialFilter;
    _type = filter.type;
    _categoryId = filter.categoryId;
    _paymentMethod = filter.paymentMethod;
    _payee = filter.payee;
    _recurring = filter.recurring;
    _syncStatus = filter.syncStatus;
    _notes = filter.notes;
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _minAmountController = TextEditingController(
      text: filter.minAmount?.toStringAsFixed(2) ?? '',
    );
    _maxAmountController = TextEditingController(
      text: filter.maxAmount?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paymentMethods =
        widget.transactions
            .map((tx) => tx.paymentMethod?.trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final payees =
        widget.transactions
            .map((tx) => tx.payee?.trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Filter Transactions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _clearAll, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: 16),
              _FilterSection(
                title: 'Basics',
                child: Column(
                  children: [
                    DropdownButtonFormField<TransactionType?>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All types'),
                        ),
                        ...TransactionType.values.map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _type = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All categories'),
                        ),
                        ...widget.categories.map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FilterSection(
                title: 'Amount',
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Min'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Max'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FilterSection(
                title: 'Payment Details',
                child: Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _paymentMethod,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All payment methods'),
                        ),
                        ...paymentMethods.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _paymentMethod = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _payee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Store / Payment To',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All payees'),
                        ),
                        ...payees.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _payee = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FilterSection(
                title: 'Advanced',
                child: Column(
                  children: [
                    DropdownButtonFormField<RecurringFilter>(
                      initialValue: _recurring,
                      decoration: const InputDecoration(labelText: 'Recurring'),
                      items: const [
                        DropdownMenuItem(
                          value: RecurringFilter.all,
                          child: Text('All transactions'),
                        ),
                        DropdownMenuItem(
                          value: RecurringFilter.recurringOnly,
                          child: Text('Recurring only'),
                        ),
                        DropdownMenuItem(
                          value: RecurringFilter.nonRecurringOnly,
                          child: Text('Non-recurring only'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _recurring = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SyncStatusFilter>(
                      initialValue: _syncStatus,
                      decoration: const InputDecoration(
                        labelText: 'Sync Status',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: SyncStatusFilter.all,
                          child: Text('All sync states'),
                        ),
                        DropdownMenuItem(
                          value: SyncStatusFilter.syncedOnly,
                          child: Text('Synced only'),
                        ),
                        DropdownMenuItem(
                          value: SyncStatusFilter.localOnly,
                          child: Text('Local only'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _syncStatus = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<NotesFilter>(
                      initialValue: _notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      items: const [
                        DropdownMenuItem(
                          value: NotesFilter.all,
                          child: Text('With and without notes'),
                        ),
                        DropdownMenuItem(
                          value: NotesFilter.withNotes,
                          child: Text('With notes only'),
                        ),
                        DropdownMenuItem(
                          value: NotesFilter.withoutNotes,
                          child: Text('Without notes only'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _notes = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FilterSection(
                title: 'Date Range',
                child: Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'From',
                        value: _startDate,
                        onTap: () async {
                          final picked = await _pickDate(context, _startDate);
                          if (picked != null || _startDate != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'To',
                        value: _endDate,
                        onTap: () async {
                          final picked = await _pickDate(context, _endDate);
                          if (picked != null || _endDate != null) {
                            setState(() => _endDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _applyFilters,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
  }

  void _clearAll() {
    setState(() {
      _type = null;
      _categoryId = null;
      _paymentMethod = null;
      _payee = null;
      _recurring = RecurringFilter.all;
      _syncStatus = SyncStatusFilter.all;
      _notes = NotesFilter.all;
      _startDate = null;
      _endDate = null;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  void _applyFilters() {
    final minAmount = double.tryParse(_minAmountController.text.trim());
    final maxAmount = double.tryParse(_maxAmountController.text.trim());

    ref
        .read(transactionFilterProvider.notifier)
        .setFilter(
          widget.initialFilter.copyWith(
            type: _type,
            categoryId: _categoryId,
            paymentMethod: _paymentMethod,
            payee: _payee,
            minAmount: minAmount,
            maxAmount: maxAmount,
            recurring: _recurring,
            syncStatus: _syncStatus,
            notes: _notes,
            startDate: _startDate,
            endDate: _endDate,
          ),
        );

    Navigator.pop(context);
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = value == null
        ? label
        : '${value!.day}/${value!.month}/${value!.year}';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
