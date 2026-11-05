import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/privacy/transaction_visibility.dart';
import '../../../../core/utils/money.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../data/models/collection_model.dart';
import '../../domain/collection_totals.dart';
import '../providers/collection_provider.dart';
import 'collection_detail_page.dart';

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsProvider);
    final transactions =
        ref.watch(visibleTransactionsProvider).valueOrNull ?? const [];
    final visibility = ref.watch(transactionVisibilityProvider);
    final totals = totalsByCollection(transactions);

    return Scaffold(
      // In the app bar: the app shell's floating button would cover a second one.
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            tooltip: 'New collection',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => showCollectionEditor(context, ref),
          ),
        ],
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Group transactions for a trip, a renovation or anything '
                  'else. They still count in your overall totals.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: collections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final collection = collections[index];
              final total =
                  totals[collection.id] ??
                  const CollectionTotals(income: 0, expense: 0);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(collection.color),
                    child: const Icon(
                      Icons.folder_outlined,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(collection.name),
                  subtitle: Text(
                    'In ${visibility.displayAmount(formatMoney(total.income))}'
                    '  ·  Out ${visibility.displayAmount(formatMoney(total.expense))}',
                  ),
                  trailing: Text(
                    visibility.displayAmount(formatMoney(total.net)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CollectionDetailPage(collectionId: collection.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

const List<int> collectionPalette = [
  0xFFEF4444,
  0xFFF97316,
  0xFFF59E0B,
  0xFF10B981,
  0xFF06B6D4,
  0xFF3B82F6,
  0xFF8B5CF6,
  0xFFEC4899,
];

Future<void> showCollectionEditor(
  BuildContext context,
  WidgetRef ref, {
  CollectionModel? collection,
}) async {
  final controller = TextEditingController(text: collection?.name ?? '');
  var selectedColor = collection?.color ?? collectionPalette.first;
  var separate = collection?.separate ?? false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              collection == null ? 'New Collection' : 'Edit Collection',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Lisbon trip, Kitchen renovation...',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in collectionPalette)
                  Semantics(
                    label: 'Colour',
                    selected: color == selectedColor,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setModalState(() => selectedColor = color),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(color),
                          borderRadius: BorderRadius.circular(16),
                          border: color == selectedColor
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 2.2,
                                )
                              : null,
                        ),
                        child: color == selectedColor
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep separate'),
              subtitle: const Text(
                'Track its transactions only here, not in the main list, dashboard or analytics.',
              ),
              value: separate,
              onChanged: (v) => setModalState(() => separate = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(collection == null ? 'Create' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  final name = controller.text.trim();
  if (saved != true || name.isEmpty) return;

  final repo = ref.read(collectionRepositoryProvider);
  final target = collection ?? CollectionModel();
  target
    ..name = name
    ..color = selectedColor
    ..separate = separate;

  if (collection == null) {
    await repo.add(target);
  } else {
    await repo.update(target);
  }

  ref.invalidate(collectionsProvider);
}
