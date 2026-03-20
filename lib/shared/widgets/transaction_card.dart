import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/privacy/transaction_visibility.dart';
import '../../features/categories/data/models/category_model.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../../features/transactions/data/providers/transaction_repository_provider.dart';
import '../../features/transactions/presentation/pages/add_transaction_page.dart';
import '../../features/transactions/presentation/pages/transaction_details_page.dart';
import '../../features/transactions/presentation/providers/transaction_provider.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _amountFmt = NumberFormat('#,##0.00');

class TransactionCard extends ConsumerWidget {
  final TransactionModel transaction;
  final CategoryModel? category;
  final EdgeInsetsGeometry margin;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.category,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 10),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = ref.watch(transactionVisibilityProvider);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isExpense = transaction.type == TransactionType.expense;
    final isPending = transaction.status == TransactionStatus.pending;
    final showOverflowMenu = screenWidth >= 600;
    final isWideLayout = screenWidth >= 760;

    final accentColor = _accentFor(isExpense);
    final categoryColor = category != null
        ? Color(category!.color)
        : accentColor;
    final borderColor = Color.alphaBlend(
      categoryColor.withValues(alpha: 0.22),
      scheme.outlineVariant.withValues(alpha: 0.78),
    );
    final rawCategoryName =
        category?.name ?? (isExpense ? 'Expense' : 'Income');
    final categoryName = visibility.displayCategory(
      rawCategoryName,
      seed: 'category:${transaction.categoryId}:$rawCategoryName',
    );
    final payee = transaction.payee?.trim();
    final paymentMethod = transaction.paymentMethod?.trim();
    final hasPayee = payee != null && payee.isNotEmpty;
    final hasMethod = paymentMethod != null && paymentMethod.isNotEmpty;
    final hasNote = transaction.note?.trim().isNotEmpty == true;
    final isRecurring =
        transaction.recurringId != null && transaction.recurringId!.isNotEmpty;

    final displayTitle = visibility.displayTitle(
      transaction,
      fallback: rawCategoryName,
    );
    final displayPayee = visibility.displayText(
      payee,
      seed: 'payee:${transaction.id}:${payee ?? ''}',
    );
    final displayPaymentMethod = visibility.displayText(
      paymentMethod,
      seed: 'payment:${transaction.id}:${paymentMethod ?? ''}',
    );
    final displayNote = visibility.displayText(
      transaction.note,
      seed: 'note:${transaction.id}:${transaction.note ?? ''}',
    );
    final formattedAmt = visibility.displayAmount(
      '${isExpense ? '−' : '+'} ₹${_amountFmt.format(transaction.amount)}',
    );
    final dateLabel = _dateFmt.format(transaction.date);

    PopupMenuButton<_TransactionCardAction> buildOverflowMenu() =>
        PopupMenuButton<_TransactionCardAction>(
          tooltip: 'More actions',
          onSelected: (action) => _handleAction(context, ref, action),
          padding: EdgeInsets.zero,
          iconSize: 17,
          icon: Icon(
            Icons.more_vert_rounded,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _TransactionCardAction.view,
              child: Text('View Details'),
            ),
            const PopupMenuItem(
              value: _TransactionCardAction.edit,
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: _TransactionCardAction.duplicate,
              child: Text('Duplicate'),
            ),
            PopupMenuItem(
              value: _TransactionCardAction.toggleStatus,
              child: Text(isPending ? 'Mark as Paid' : 'Mark as Pending'),
            ),
            const PopupMenuItem(
              value: _TransactionCardAction.delete,
              child: Text('Delete'),
            ),
          ],
        );

    return Padding(
      padding: margin,
      child: Dismissible(
        key: ValueKey(
          transaction.remoteId ??
              'local-${transaction.id}-${transaction.status.name}',
        ),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          if (direction != DismissDirection.startToEnd) return false;
          await _toggleStatus(context, ref);
          return false;
        },
        background: _SwipeStatusBackground(isPending: isPending),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openDetails(context),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showQuickActions(context, ref);
            },
            child: Ink(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  13,
                  showOverflowMenu ? 12 : 16,
                  13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isWideLayout)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayTitle,
                                  style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                    fontSize: 16.5,
                                    letterSpacing: -0.35,
                                    height: 1.15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _MetaTag(
                                      label: categoryName,
                                      textColor: categoryColor,
                                      backgroundColor: categoryColor.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderColor: categoryColor.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                    _MetaTag(
                                      label: dateLabel,
                                      textColor: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.82),
                                      backgroundColor: scheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.42),
                                      borderColor: scheme.outlineVariant
                                          .withValues(alpha: 0.32),
                                    ),
                                    if (hasMethod)
                                      _MetaTag(
                                        label: displayPaymentMethod,
                                        textColor: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.88),
                                        backgroundColor: scheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        borderColor: scheme.outlineVariant
                                            .withValues(alpha: 0.35),
                                      ),
                                    if (hasPayee)
                                      _MetaTag(
                                        label: displayPayee,
                                        textColor: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.88),
                                        backgroundColor: scheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.5),
                                        borderColor: scheme.outlineVariant
                                            .withValues(alpha: 0.35),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      formattedAmt,
                                      textAlign: TextAlign.right,
                                      style: tt.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: accentColor,
                                        fontSize: 21,
                                        letterSpacing: -0.55,
                                      ),
                                    ),
                                    if (showOverflowMenu) ...[
                                      const SizedBox(width: 6),
                                      buildOverflowMenu(),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: [
                                    _StatusBadge(status: transaction.status),
                                    _TypeBadge(
                                      isExpense: isExpense,
                                      accentColor: accentColor,
                                    ),
                                    if (isRecurring) const _RecurringBadge(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              displayTitle,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                                fontSize: 16.5,
                                letterSpacing: -0.35,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showOverflowMenu) buildOverflowMenu(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _MetaTag(
                                  label: categoryName,
                                  textColor: categoryColor,
                                  backgroundColor: categoryColor.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderColor: categoryColor.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                                _MetaTag(
                                  label: dateLabel,
                                  textColor: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.82,
                                  ),
                                  backgroundColor: scheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.42),
                                  borderColor: scheme.outlineVariant.withValues(
                                    alpha: 0.32,
                                  ),
                                ),
                                if (hasMethod)
                                  _MetaTag(
                                    label: displayPaymentMethod,
                                    textColor: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.88),
                                    backgroundColor: scheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderColor: scheme.outlineVariant
                                        .withValues(alpha: 0.35),
                                  ),
                                if (hasPayee)
                                  _MetaTag(
                                    label: displayPayee,
                                    textColor: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.88),
                                    backgroundColor: scheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderColor: scheme.outlineVariant
                                        .withValues(alpha: 0.35),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formattedAmt,
                            textAlign: TextAlign.right,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              fontSize: 18,
                              letterSpacing: -0.55,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          _StatusBadge(status: transaction.status),
                          _TypeBadge(
                            isExpense: isExpense,
                            accentColor: accentColor,
                          ),
                          if (isRecurring) const _RecurringBadge(),
                        ],
                      ),
                    ],

                    if (hasNote) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 11,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              displayNote,
                              style: tt.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                                fontStyle: FontStyle.italic,
                                fontSize: 11.5,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static Color _accentFor(bool isExpense) =>
      isExpense ? const Color(0xFFD94040) : const Color(0xFF1A8C5B);

  // ── Quick actions sheet ───────────────────────────────────────────────────

  Future<void> _showQuickActions(BuildContext context, WidgetRef ref) async {
    final visibility = ref.read(transactionVisibilityProvider);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isExp = transaction.type == TransactionType.expense;
    final accent = _accentFor(isExp);
    final rawCategoryName = category?.name ?? (isExp ? 'Expense' : 'Income');
    final catName = visibility.displayCategory(
      rawCategoryName,
      seed: 'category:${transaction.categoryId}:$rawCategoryName',
    );
    final quickTitle = visibility.displayTitle(
      transaction,
      fallback: rawCategoryName,
    );
    final quickPaymentMethod = visibility.displayText(
      transaction.paymentMethod,
      seed: 'payment:${transaction.id}:${transaction.paymentMethod ?? ''}',
    );
    final quickPayee = visibility.displayText(
      transaction.payee,
      seed: 'payee:${transaction.id}:${transaction.payee ?? ''}',
    );
    final quickAmount = visibility.displayAmount(
      '${isExp ? '−' : '+'} ₹${_amountFmt.format(transaction.amount)}',
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
            width: 0.75,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Container(
                  width: 32,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // ── Header card ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.12),
                      width: 0.75,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.2),
                                width: 0.75,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                isExp ? '↓' : '↑',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quickTitle,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _MetaTag(
                                      label: catName,
                                      textColor: accent,
                                      backgroundColor: accent.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderColor: accent.withValues(
                                        alpha: 0.20,
                                      ),
                                    ),
                                    _MetaTag(
                                      label: _dateFmt.format(transaction.date),
                                      textColor: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.82),
                                      backgroundColor: scheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.42),
                                      borderColor: scheme.outlineVariant
                                          .withValues(alpha: 0.32),
                                    ),
                                    if (transaction.paymentMethod
                                            ?.trim()
                                            .isNotEmpty ==
                                        true)
                                      _MetaTag(
                                        label: quickPaymentMethod,
                                        textColor: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.88),
                                        backgroundColor: scheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.45),
                                        borderColor: scheme.outlineVariant
                                            .withValues(alpha: 0.30),
                                      ),
                                    if (transaction.payee?.trim().isNotEmpty ==
                                        true)
                                      _MetaTag(
                                        label: quickPayee,
                                        textColor: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.88),
                                        backgroundColor: scheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.45),
                                        borderColor: scheme.outlineVariant
                                            .withValues(alpha: 0.30),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.12),
                            width: 0.75,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: [
                                  _StatusBadge(status: transaction.status),
                                  _TypeBadge(
                                    isExpense: isExp,
                                    accentColor: accent,
                                  ),
                                  if (transaction.recurringId?.isNotEmpty ==
                                      true)
                                    const _RecurringBadge(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              quickAmount,
                              textAlign: TextAlign.right,
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: -0.6,
                                fontSize: 18,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Divider ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: scheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: 4),

              // ── Actions ──────────────────────────────────────────
              _ActionTile(
                icon: Icons.open_in_new_rounded,
                label: 'View Details',
                iconBg: scheme.primary.withValues(alpha: 0.1),
                iconColor: scheme.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _openDetails(context);
                },
              ),
              _ActionTile(
                icon: Icons.edit_outlined,
                label: 'Edit Transaction',
                iconBg: const Color(0xFF2A6BF2).withValues(alpha: 0.1),
                iconColor: const Color(0xFF2A6BF2),
                onTap: () {
                  Navigator.pop(ctx);
                  _openEditor(context);
                },
              ),
              _ActionTile(
                icon: Icons.content_copy_outlined,
                label: 'Duplicate',
                subtitle: 'Copy into a new draft',
                iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                iconColor: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pop(ctx);
                  _openDuplicate(context);
                },
              ),
              _ActionTile(
                icon: transaction.status == TransactionStatus.pending
                    ? Icons.check_circle_outline_rounded
                    : Icons.hourglass_bottom_rounded,
                label: transaction.status == TransactionStatus.pending
                    ? 'Mark as Cleared'
                    : 'Mark as Pending',
                subtitle: transaction.status == TransactionStatus.pending
                    ? 'Settle this transaction now'
                    : 'Keep this transaction unpaid for now',
                iconBg: transaction.status == TransactionStatus.pending
                    ? const Color(0xFF1A8C5B).withValues(alpha: 0.1)
                    : const Color(0xFFCA8A04).withValues(alpha: 0.12),
                iconColor: transaction.status == TransactionStatus.pending
                    ? const Color(0xFF1A8C5B)
                    : const Color(0xFFCA8A04),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _toggleStatus(context, ref);
                },
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                iconBg: Colors.red.withValues(alpha: 0.1),
                iconColor: Colors.red.shade600,
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteTransaction(context, ref);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDetails(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TransactionDetailsPage(transaction: transaction),
    ),
  );

  void _openEditor(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddTransactionPage(initialTransaction: transaction),
    ),
  );

  void _openDuplicate(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AddTransactionPage(duplicateTransaction: transaction),
    ),
  );

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _TransactionCardAction action,
  ) async {
    switch (action) {
      case _TransactionCardAction.view:
        _openDetails(context);
      case _TransactionCardAction.edit:
        _openEditor(context);
      case _TransactionCardAction.duplicate:
        _openDuplicate(context);
      case _TransactionCardAction.toggleStatus:
        await _toggleStatus(context, ref);
      case _TransactionCardAction.delete:
        await _deleteTransaction(context, ref);
    }
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref) async {
    final updated = TransactionModel()
      ..id = transaction.id
      ..remoteId = transaction.remoteId
      ..recurringId = transaction.recurringId
      ..title = transaction.title
      ..amount = transaction.amount
      ..date = transaction.date
      ..type = transaction.type
      ..status = transaction.status == TransactionStatus.pending
          ? TransactionStatus.paid
          : TransactionStatus.pending
      ..categoryId = transaction.categoryId
      ..paymentMethod = transaction.paymentMethod
      ..payee = transaction.payee
      ..note = transaction.note
      ..createdAt = transaction.createdAt
      ..updatedAt = DateTime.now().toUtc();

    try {
      await ref.read(transactionRepositoryProvider).update(updated);
      ref.invalidate(transactionsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $error')),
      );
    }
  }

  Future<void> _deleteTransaction(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(transactionRepositoryProvider).delete(transaction.id);
      ref.invalidate(transactionsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $error'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _MetaTag extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  const _MetaTag({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: borderColor, width: 0.8),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.1,
      ),
    ),
  );
}

class _SwipeStatusBackground extends StatelessWidget {
  final bool isPending;

  const _SwipeStatusBackground({required this.isPending});

  @override
  Widget build(BuildContext context) {
    final color = isPending ? const Color(0xFF1A8C5B) : const Color(0xFFCA8A04);
    final icon = isPending
        ? Icons.check_circle_outline_rounded
        : Icons.hourglass_bottom_rounded;
    final label = isPending ? 'Mark as Paid' : 'Mark as Pending';

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cleared / Pending status badge.
class _StatusBadge extends StatelessWidget {
  final TransactionStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCleared = status == TransactionStatus.paid;
    final bg = isCleared ? const Color(0xFF1A8C5B) : const Color(0xFFCA8A04);
    final label = isCleared ? '✓ Cleared' : '⏳ Pending';
    return _Pill(label: label, color: bg);
  }
}

/// Recurring frequency badge.
class _RecurringBadge extends StatelessWidget {
  const _RecurringBadge();

  @override
  Widget build(BuildContext context) =>
      _Pill(label: '↻ Recurring', color: const Color(0xFF3B6FD4));
}

/// EXP / INC type badge.
class _TypeBadge extends StatelessWidget {
  final bool isExpense;
  final Color accentColor;
  const _TypeBadge({required this.isExpense, required this.accentColor});

  @override
  Widget build(BuildContext context) =>
      _Pill(label: isExpense ? 'EXP' : 'INC', color: accentColor);
}

/// Shared pill used by all badge types.
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.2), width: 0.75),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.1,
        height: 1.5,
      ),
    ),
  );
}

/// Single action row in the quick-actions sheet.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDestructive;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconBg,
    required this.iconColor,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelColor = isDestructive ? Colors.red.shade600 : scheme.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 17, color: iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: labelColor,
          fontSize: 14.5,
          letterSpacing: -0.1,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            )
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

enum _TransactionCardAction { view, edit, duplicate, toggleStatus, delete }
