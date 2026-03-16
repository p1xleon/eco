import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionRemoteSource {
  final SupabaseClient client;

  TransactionRemoteSource(this.client);

  User? get currentUser => client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String get _currentUserId {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }

    return user.id;
  }

  Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async {
    return await client.from('transactions').insert(data).select().single();
  }

  Future<Map<String, dynamic>> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await client
        .from('transactions')
        .update(data)
        .eq('id', id)
        .eq('user_id', _currentUserId)
        .select()
        .single();
  }

  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    return await client
        .from('transactions')
        .select()
        .eq('user_id', _currentUserId)
        .order('date', ascending: false);
  }

  Future<void> deleteTransaction(String id) async {
    await client
        .from('transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', _currentUserId);
  }
}
