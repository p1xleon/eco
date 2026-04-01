import 'package:supabase_flutter/supabase_flutter.dart';

class RecurringTransactionRemoteSource {
  final SupabaseClient client;

  RecurringTransactionRemoteSource(this.client);

  User? get currentUser => client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String get _currentUserId {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }

    return user.id;
  }

  Future<Map<String, dynamic>> addRecurringTransaction(
    Map<String, dynamic> data,
  ) async {
    return await client
        .from('recurring_transactions')
        .insert(data)
        .select()
        .single();
  }

  Future<Map<String, dynamic>> updateRecurringTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await client
        .from('recurring_transactions')
        .update(data)
        .eq('id', id)
        .eq('user_id', _currentUserId)
        .select()
        .single();
  }

  Future<List<Map<String, dynamic>>> fetchRecurringTransactions() async {
    return await client
        .from('recurring_transactions')
        .select()
        .eq('user_id', _currentUserId)
        .order('next_due_date', ascending: true);
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await client
        .from('recurring_transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', _currentUserId);
  }
}
