import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionRemoteSource {
  final SupabaseClient client;

  TransactionRemoteSource(this.client);

  User? get currentUser => client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async {
    return await client.from('transactions').insert(data).select().single();
  }

  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    return await client
        .from('transactions')
        .select()
        .order('date', ascending: false);
  }

  Future<void> deleteTransaction(String id) async {
    await client.from('transactions').delete().eq('id', id);
  }
}
