import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../remote/collection_remote_source.dart';

final collectionRemoteSourceProvider = Provider<CollectionRemoteSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return CollectionRemoteSource(client);
});
