import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../remote/category_remote_source.dart';

final categoryRemoteSourceProvider = Provider<CategoryRemoteSource>((ref) {
  final client = ref.read(supabaseClientProvider);
  return CategoryRemoteSource(client);
});
