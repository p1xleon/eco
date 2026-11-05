import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_provider.dart';
import '../../../../core/crypto/crypto_providers.dart';
import '../../data/models/collection_model.dart';
import '../../data/providers/collection_remote_provider.dart';
import '../../data/repositories/collection_repository.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final remote = ref.read(collectionRemoteSourceProvider);

  // Watched, not read: setting up encryption has to rebuild the repository.
  return CollectionRepository(remote, cipher: ref.watch(fieldCipherProvider));
});

final collectionsProvider = FutureProvider<List<CollectionModel>>((ref) async {
  ref.watch(authStateProvider);
  return ref.read(collectionRepositoryProvider).getAll();
});

final collectionsByIdProvider = FutureProvider<Map<int, CollectionModel>>((
  ref,
) async {
  final collections = await ref.watch(collectionsProvider.future);
  return {for (final collection in collections) collection.id: collection};
});
