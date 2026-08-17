import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/remote_call.dart';
import '../models/transaction_mapper.dart';

/// Keeps writes working against a project that has not had the
/// `category_remote_id` migration applied.
///
/// The first write rejected for that column is retried without it, and the
/// answer is remembered so later writes skip the doomed attempt. The legacy
/// `category_id` column still carries the reference in that case, so the app
/// behaves exactly as it did before the column existed.
///
/// Reads need no equivalent: a column that does not exist is simply absent from
/// the response, which the mapper already treats as "use the legacy column".
class CategoryRemoteIdFallback {
  bool _serverHasColumn = true;

  /// Whether the server is believed to have the column. Starts optimistic.
  bool get serverHasColumn => _serverHasColumn;

  Future<Map<String, dynamic>> send(
    Map<String, dynamic> data,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload) send,
  ) async {
    if (!_serverHasColumn) {
      return send(_stripped(data));
    }

    try {
      return await send(data);
    } catch (error) {
      if (!isMissingColumn(error)) rethrow;

      _serverHasColumn = false;
      return send(_stripped(data));
    }
  }

  Map<String, dynamic> _stripped(Map<String, dynamic> data) {
    return {...data}..remove(transactionCategoryRemoteIdColumn);
  }

  /// Whether the error is the server saying it has no such column, rather than
  /// rejecting the row on its merits.
  static bool isMissingColumn(Object error) {
    if (error is! PostgrestException) return false;
    if (!error.toString().contains(transactionCategoryRemoteIdColumn)) {
      return false;
    }

    // PGRST204 is PostgREST's "column not found in schema cache".
    final message = error.message.toLowerCase();
    return error.code == 'PGRST204' ||
        message.contains('could not find') ||
        message.contains('does not exist') ||
        message.contains('unknown column');
  }
}

class TransactionRemoteSource {
  final SupabaseClient client;

  /// Supabase caps rows per response, so a full fetch has to page. The sync
  /// merge treats a fetch as the complete server state when deciding what was
  /// deleted elsewhere, which is only safe if every row really came back.
  static const _pageSize = 1000;

  final _categoryRemoteIdFallback = CategoryRemoteIdFallback();

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

  Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) {
    return _write(
      data,
      (payload) => remoteCall(
        () async =>
            await client.from('transactions').insert(payload).select().single(),
      ),
    );
  }

  Future<Map<String, dynamic>> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) {
    return _write(
      data,
      (payload) => remoteCall(
        () async => await client
            .from('transactions')
            .update(payload)
            .eq('id', id)
            .eq('user_id', _currentUserId)
            .select()
            .single(),
      ),
    );
  }

  Future<Map<String, dynamic>> _write(
    Map<String, dynamic> data,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload) send,
  ) {
    return _categoryRemoteIdFallback.send(data, send);
  }

  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    final userId = _currentUserId;
    final all = <Map<String, dynamic>>[];

    for (var offset = 0; ; offset += _pageSize) {
      final page = await remoteCall(
        () async => await client
            .from('transactions')
            .select()
            .eq('user_id', userId)
            .order('date', ascending: false)
            .range(offset, offset + _pageSize - 1),
      );

      all.addAll(page);
      if (page.length < _pageSize) break;
    }

    return all;
  }

  Future<void> deleteTransaction(String id) {
    return remoteCall(
      () async => await client
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', _currentUserId),
    );
  }
}
