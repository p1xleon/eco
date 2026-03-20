import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../categories/presentation/providers/category_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/providers/transaction_repository_provider.dart';
import '../providers/transaction_provider.dart';
import 'add_transaction_page.dart';

class TransactionDetailsPage extends ConsumerStatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailsPage({super.key, required this.transaction});

  @override
  ConsumerState<TransactionDetailsPage> createState() =>
      _TransactionDetailsPageState();
}

class _TransactionDetailsPageState
    extends ConsumerState<TransactionDetailsPage> {
  late TransactionModel _transaction;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
  }

  @override
  Widget build(BuildContext context) {
    final visibility = ref.watch(transactionVisibilityProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final isExpense = _transaction.type == TransactionType.expense;
    final amountColor = isExpense ? Colors.red : Colors.green;
    final isPending = _transaction.status == TransactionStatus.pending;

    if (visibility.isInvisible &&
        !visibility.isTransactionVisible(_transaction)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Details')),
        body: const _TransactionDetailsEmptyState(
          message: 'This transaction is hidden while invisible mode is active.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: Icon(
              isPending
                  ? Icons.check_circle_outline_rounded
                  : Icons.hourglass_bottom_rounded,
            ),
            onPressed: _toggleStatus,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editTransaction,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.redAccent,
            onPressed: _deleteTransaction,
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final category = categories
              .where((item) => item.id == _transaction.categoryId)
              .firstOrNull;
          final categoryName = visibility.displayCategory(
            category?.name ?? 'Unknown',
            seed:
                'category:${_transaction.categoryId}:${category?.name ?? 'Unknown'}',
          );
          final title = visibility.displayTitle(_transaction);
          final amount = visibility.displayAmount(
            '${isExpense ? '-' : '+'} ₹${_transaction.amount.toStringAsFixed(2)}',
          );
          final paymentMethod = visibility.displayText(
            _transaction.paymentMethod,
            seed:
                'payment:${_transaction.id}:${_transaction.paymentMethod ?? ''}',
          );
          final payee = visibility.displayText(
            _transaction.payee,
            seed: 'payee:${_transaction.id}:${_transaction.payee ?? ''}',
          );
          final note = visibility.displayText(
            _transaction.note,
            seed: 'note:${_transaction.id}:${_transaction.note ?? ''}',
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              amount,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: amountColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: amountColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _transaction.type.name[0].toUpperCase() +
                                  _transaction.type.name.substring(1),
                              style: TextStyle(
                                color: amountColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Pending',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Details',
                children: [
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: 'Category',
                    value: categoryName,
                  ),
                  _DetailRow(
                    icon: Icons.flag_outlined,
                    label: 'Status',
                    value: isPending ? 'Pending' : 'Paid',
                  ),
                  _DetailRow(
                    icon: Icons.payment_outlined,
                    label: 'Payment Method',
                    value: paymentMethod,
                  ),
                  _DetailRow(
                    icon: Icons.store_outlined,
                    label: 'Store / Payment To',
                    value: payee,
                  ),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Transaction Date',
                    value: DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(_transaction.date),
                  ),
                  _DetailRow(
                    icon: Icons.access_time_outlined,
                    label: 'Created At',
                    value: DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(_transaction.createdAt.toLocal()),
                  ),
                  if (_showUpdatedAt(_transaction))
                    _DetailRow(
                      icon: Icons.update_outlined,
                      label: 'Updated At',
                      value: DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(_transaction.updatedAt!.toLocal()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Notes',
                children: [
                  _DetailRow(
                    icon: Icons.notes_outlined,
                    label: 'Note',
                    value: note,
                    multiline: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Identifiers',
                children: [
                  _DetailRow(
                    icon: Icons.fingerprint_outlined,
                    label: 'Local ID',
                    value: _transaction.id.toString(),
                  ),
                  _DetailRow(
                    icon: Icons.cloud_outlined,
                    label: 'Remote ID',
                    value: _fallback(_transaction.remoteId),
                  ),
                  _DetailRow(
                    icon: Icons.event_repeat_outlined,
                    label: 'Recurring ID',
                    value: _fallback(_transaction.recurringId),
                  ),
                  _DetailRow(
                    icon: Icons.sync_outlined,
                    label: 'Sync Status',
                    value: _transaction.remoteId == null
                        ? 'Local only'
                        : 'Synced',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Recorded ${DateFormatter.fullDate(_transaction.date)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.delete(_transaction.id);
      ref.invalidate(transactionsProvider);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete transaction: $e')),
      );
    }
  }

  Future<void> _toggleStatus() async {
    final repo = ref.read(transactionRepositoryProvider);
    _transaction
      ..status = _transaction.status == TransactionStatus.pending
          ? TransactionStatus.paid
          : TransactionStatus.pending
      ..updatedAt = DateTime.now().toUtc();

    try {
      final updated = await repo.update(_transaction);
      ref.invalidate(transactionsProvider);

      if (!mounted) return;
      setState(() {
        _transaction = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update transaction status: $e')),
      );
    }
  }

  Future<void> _editTransaction() async {
    final updated = await Navigator.push<TransactionModel>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(initialTransaction: _transaction),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() {
      _transaction = updated;
    });
  }

  String _fallback(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not provided';
    }

    return value;
  }

  bool _showUpdatedAt(TransactionModel transaction) {
    final updatedAt = transaction.updatedAt;
    if (updatedAt == null) return false;

    final delta = updatedAt.toUtc().difference(transaction.createdAt.toUtc());
    return delta.inSeconds.abs() >= 1;
  }
}

class _TransactionDetailsEmptyState extends StatelessWidget {
  final String message;

  const _TransactionDetailsEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final bool multiline;

  const _DetailRow({
    this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: icon != null ? 120 : 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
