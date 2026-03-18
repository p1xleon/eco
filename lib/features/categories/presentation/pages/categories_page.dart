import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category_model.dart';
import '../providers/category_provider.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categoriesAsync.when(
        data: (categories) {
          final expenseCategories = categories
              .where((category) => category.type == CategoryType.expense)
              .toList(growable: false);
          final incomeCategories = categories
              .where((category) => category.type == CategoryType.income)
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _CategoryIntroCard(
                totalCount: categories.length,
                onAdd: () => _showCategoryEditor(context, ref),
              ),
              const SizedBox(height: 16),
              _CategorySection(
                title: 'Expense Categories',
                subtitle:
                    'Spending buckets used for day-to-day and recurring costs.',
                emptyTitle: 'No expense categories yet',
                emptySubtitle:
                    'Create expense categories so transactions have clearer grouping.',
                categories: expenseCategories,
                onAdd: () => _showCategoryEditor(
                  context,
                  ref,
                  initialType: CategoryType.expense,
                ),
                onEdit: (category) =>
                    _showCategoryEditor(context, ref, category: category),
                onDelete: (category) => _deleteCategory(context, ref, category),
              ),
              const SizedBox(height: 16),
              _CategorySection(
                title: 'Income Categories',
                subtitle:
                    'Buckets for salary, reimbursements, transfers, and other inflows.',
                emptyTitle: 'No income categories yet',
                emptySubtitle:
                    'Create income categories to keep incoming money organized.',
                categories: incomeCategories,
                onAdd: () => _showCategoryEditor(
                  context,
                  ref,
                  initialType: CategoryType.income,
                ),
                onEdit: (category) =>
                    _showCategoryEditor(context, ref, category: category),
                onDelete: (category) => _deleteCategory(context, ref, category),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }
}

class _CategoryIntroCard extends StatelessWidget {
  final int totalCount;
  final VoidCallback onAdd;

  const _CategoryIntroCard({required this.totalCount, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.category_outlined,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Categories',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalCount saved categor${totalCount == 1 ? 'y' : 'ies'}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Refine the labels and colors that appear across transactions, analytics, and recurring entries.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptySubtitle;
  final List<CategoryModel> categories;
  final VoidCallback onAdd;
  final ValueChanged<CategoryModel> onEdit;
  final ValueChanged<CategoryModel> onDelete;

  const _CategorySection({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.categories,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            _CategoryEmptyState(title: emptyTitle, subtitle: emptySubtitle)
          else
            ...categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryCard(
                  category: category,
                  onEdit: () => onEdit(category),
                  onDelete: () => onDelete(category),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _CategoryEmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.category_outlined,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categoryColor = Color(category.color);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.circle, size: 18, color: categoryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  category.type.name[0].toUpperCase() +
                      category.type.name.substring(1),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PopupMenuButton<_CategoryAction>(
            onSelected: (action) {
              if (action == _CategoryAction.edit) {
                onEdit();
              } else {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _CategoryAction.edit,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              PopupMenuItem(
                value: _CategoryAction.delete,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showCategoryEditor(
  BuildContext context,
  WidgetRef ref, {
  CategoryModel? category,
  CategoryType? initialType,
}) async {
  final controller = TextEditingController(text: category?.name ?? '');
  CategoryType type = category?.type ?? initialType ?? CategoryType.expense;
  int selectedColor = category?.color ?? _categoryPalette.first;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;

      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
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
                  category == null ? 'Add Category' : 'Edit Category',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category == null
                      ? 'Create a category with a clear label and color for faster recognition.'
                      : 'Rename or recolor this category without changing its purpose.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'Groceries, Salary, Utilities...',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<CategoryType>(
                  segments: const [
                    ButtonSegment(
                      value: CategoryType.expense,
                      icon: Icon(Icons.north_east_rounded),
                      label: Text('Expense'),
                    ),
                    ButtonSegment(
                      value: CategoryType.income,
                      icon: Icon(Icons.south_west_rounded),
                      label: Text('Income'),
                    ),
                  ],
                  selected: {type},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setModalState(() => type = selection.first);
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'Color',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _categoryPalette
                      .map((color) {
                        final isSelected = color == selectedColor;

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              setModalState(() => selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Color(color),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? scheme.onSurface
                                    : Colors.white.withValues(alpha: 0.5),
                                width: isSelected ? 2.2 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(
                                          color,
                                        ).withValues(alpha: 0.28),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(Icons.check, color: scheme.onPrimary)
                                : null,
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(category == null ? 'Save' : 'Update'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );

  if (result != true) return;

  final name = controller.text.trim();
  if (name.isEmpty) return;

  final repo = ref.read(categoryRepositoryProvider);
  final categoryToSave = category ?? CategoryModel();
  categoryToSave
    ..name = name
    ..type = type
    ..color = selectedColor;

  if (category == null) {
    await repo.add(categoryToSave);
  } else {
    await repo.update(categoryToSave);
  }

  _invalidateCategories(ref);
}

Future<void> _deleteCategory(
  BuildContext context,
  WidgetRef ref,
  CategoryModel category,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete category?'),
      content: Text(
        'Remove "${category.name}"? Transactions already using it may lose their category label.',
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

  if (confirmed != true) return;

  final repo = ref.read(categoryRepositoryProvider);
  await repo.delete(category.id);
  _invalidateCategories(ref);
}

void _invalidateCategories(WidgetRef ref) {
  ref.invalidate(categoriesProvider);
  ref.invalidate(categoriesByIdProvider);
}

enum _CategoryAction { edit, delete }

const List<int> _categoryPalette = [
  0xFFEF4444,
  0xFFF97316,
  0xFFF59E0B,
  0xFF84CC16,
  0xFF10B981,
  0xFF14B8A6,
  0xFF06B6D4,
  0xFF3B82F6,
  0xFF6366F1,
  0xFF8B5CF6,
  0xFFEC4899,
  0xFF6B7280,
];
