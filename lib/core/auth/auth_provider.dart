import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_provider.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.read(supabaseClientProvider);
  return AuthRepository(client);
});

/// The signed-in user, or null.
///
/// Seeded from the persisted session so a cold start renders straight from the
/// local cache instead of waiting for the first auth event. Repeated events for
/// the same user (token refreshes, which fire on a timer) are dropped, because
/// everything watching this provider refetches when it emits.
final authStateProvider = StreamProvider<User?>((ref) async* {
  final client = ref.read(supabaseClientProvider);

  var lastUserId = client.auth.currentSession?.user.id;
  yield client.auth.currentSession?.user;

  await for (final event in client.auth.onAuthStateChange) {
    final user = event.session?.user;
    if (user?.id == lastUserId) continue;

    lastUserId = user?.id;
    yield user;
  }
});
