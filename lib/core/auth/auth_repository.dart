import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/remote_call.dart';

class AuthRepository {
  final SupabaseClient client;

  AuthRepository(this.client);

  User? get currentUser => client.auth.currentUser;

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': displayName,
      },
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (error) {
      // The local session is cleared before the server is told, so a failure
      // here (no connection, expired token) must not leave the user stuck
      // signed in.
      final isUnreachable =
          error is AuthRetryableFetchException || isNetworkFailure(error);
      if (!isUnreachable) rethrow;
    }
  }
}
