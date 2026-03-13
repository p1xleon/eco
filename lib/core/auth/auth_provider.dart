import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_provider.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.read(supabaseClientProvider);
  return AuthRepository(client);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.read(supabaseClientProvider);

  return client.auth.onAuthStateChange.map((event) {
    return event.session?.user;
  });
});
