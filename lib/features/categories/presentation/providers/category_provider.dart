import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/crypto/crypto_providers.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/providers/category_remote_provider.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final remote = ref.read(categoryRemoteSourceProvider);

  // Watched, not read: setting up encryption has to rebuild the repository, or
  // it would keep syncing with the cipher it was born without.
  return CategoryRepository(remote, cipher: ref.watch(fieldCipherProvider));
});

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.read(categoryRepositoryProvider);
  return repo.getAll();
});

final categoriesByIdProvider = FutureProvider<Map<int, CategoryModel>>((
  ref,
) async {
  final categories = await ref.watch(categoriesProvider.future);
  return {for (final category in categories) category.id: category};
});
