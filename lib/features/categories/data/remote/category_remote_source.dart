import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryRemoteSource {
  final SupabaseClient client;

  CategoryRemoteSource(this.client);

  User? get currentUser => client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String get _currentUserId {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }

    return user.id;
  }

  Future<Map<String, dynamic>> addCategory(Map<String, dynamic> data) async {
    return await client.from('categories').insert(data).select().single();
  }

  Future<Map<String, dynamic>> updateCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await client
        .from('categories')
        .update(data)
        .eq('id', id)
        .eq('user_id', _currentUserId)
        .select()
        .single();
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    return await client
        .from('categories')
        .select()
        .eq('user_id', _currentUserId)
        .order('name', ascending: true);
  }

  Future<void> deleteCategory(String id) async {
    await client
        .from('categories')
        .delete()
        .eq('id', id)
        .eq('user_id', _currentUserId);
  }
}
