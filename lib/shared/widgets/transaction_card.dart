import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/categories/presentation/providers/category_provider.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../../features/transactions/presentation/pages/transaction_details_page.dart';

class TransactionCard extends ConsumerWidget {
  final TransactionModel transaction;
  final EdgeInsetsGeometry margin;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;
    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense ? scheme.error : scheme.primary;

    return categoriesAsync.when(
      data: (categories) {
        final category = categories
            .where((item) => item.id == transaction.categoryId)
            .firstOrNull;
        final categoryColor = category != null
            ? Color(category.color)
            : amountColor;
        final metaValues = <String>[
          if (category?.name != null) category!.name,
          if (transaction.payee != null && transaction.payee!.trim().isNotEmpty)
            transaction.payee!.trim(),
          if (transaction.paymentMethod != null &&
              transaction.paymentMethod!.trim().isNotEmpty)
            transaction.paymentMethod!.trim(),
        ];

        return Padding(
          padding: margin,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionDetailsPage(transaction: transaction),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: categoryColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isExpense
                            ? Icons.north_east_rounded
                            : Icons.south_west_rounded,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy',
                                      ).format(transaction.date),
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: amountColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${isExpense ? '-' : '+'} ₹${transaction.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: amountColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (metaValues.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: metaValues
                                  .map(
                                    (value) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: value == category?.name
                                            ? categoryColor.withValues(
                                                alpha: 0.12,
                                              )
                                            : scheme.surface,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: value == category?.name
                                              ? categoryColor
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (transaction.note != null &&
                              transaction.note!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              transaction.note!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: margin,
        child: const Card(child: SizedBox(height: 96)),
      ),
      error: (_, _) => Padding(
        padding: margin,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(
                  isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
                  color: amountColor,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(transaction.title)),
                Text(
                  '${isExpense ? '-' : '+'} ₹${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
