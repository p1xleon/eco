import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/category_provider.dart';
import '../../data/models/category_model.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Categories")),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text("No categories"));
          }

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];

              return _CategoryTile(category: category);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategory(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final CategoryModel category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(categoryRepositoryProvider);

    return Dismissible(
      key: ValueKey(category.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await repo.delete(category.id);
        ref.invalidate(categoriesProvider);
      },
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Color(category.color)),
        title: Text(category.name),
        subtitle: Text(category.type.name),
      ),
    );
  }
}

Future<void> _showAddCategory(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  CategoryType type = CategoryType.expense;

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Add Category"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: "Category Name"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CategoryType>(
              initialValue: type,
              items: CategoryType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) => type = v!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(categoryRepositoryProvider);

              final category = CategoryModel()
                ..name = controller.text.trim()
                ..type = type
                ..color = 0xFF2196F3;

              await repo.add(category);

              ref.invalidate(categoriesProvider);

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      );
    },
  );
}
