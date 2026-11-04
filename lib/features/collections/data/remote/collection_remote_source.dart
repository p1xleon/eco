import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/remote_call.dart';

class CollectionRemoteSource {
  final SupabaseClient client;

  /// See [TransactionRemoteSource]: a full fetch has to page so the sync merge
  /// can trust it as the complete server state.
  static const _pageSize = 1000;

  CollectionRemoteSource(this.client);

  User? get currentUser => client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String get _currentUserId {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }

    return user.id;
  }

  Future<Map<String, dynamic>> addCollection(Map<String, dynamic> data) {
    return remoteCall(
      () async =>
          await client.from('collections').insert(data).select().single(),
    );
  }

  Future<Map<String, dynamic>> updateCollection(
    String id,
    Map<String, dynamic> data,
  ) {
    return remoteCall(
      () async => await client
          .from('collections')
          .update(data)
          .eq('id', id)
          .eq('user_id', _currentUserId)
          .select()
          .single(),
    );
  }

  Future<List<Map<String, dynamic>>> fetchCollections() async {
    final userId = _currentUserId;
    final all = <Map<String, dynamic>>[];

    for (var offset = 0; ; offset += _pageSize) {
      final page = await remoteCall(
        () async => await client
            .from('collections')
            .select()
            .eq('user_id', userId)
            // Names are ciphertext, so sorting by them is meaningless; id is
            // stable, which is all paging needs.
            .order('id', ascending: true)
            .range(offset, offset + _pageSize - 1),
      );

      all.addAll(page);
      if (page.length < _pageSize) break;
    }

    return all;
  }

  Future<void> deleteCollection(String id) {
    return remoteCall(
      () async => await client
          .from('collections')
          .delete()
          .eq('id', id)
          .eq('user_id', _currentUserId),
    );
  }
}
