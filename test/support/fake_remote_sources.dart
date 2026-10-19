import 'package:eco/features/categories/data/remote/category_remote_source.dart';
import 'package:eco/features/recurring/data/remote/recurring_transaction_remote_source.dart';
import 'package:eco/features/transactions/data/remote/transaction_remote_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _testUser = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime.utc(2026).toIso8601String(),
);

/// Thrown by the fakes to look like a dropped connection.
Exception _unreachable() {
  return Exception('ClientException: Connection closed before full header');
}

/// In-memory stand-in for the Supabase table, so tests can take the server
/// away mid-scenario.
class FakeTransactionRemoteSource implements TransactionRemoteSource {
  final Map<String, Map<String, dynamic>> rows = {};

  bool isReachable = true;

  /// When set, writes fail the way the server rejecting a row does — reachable,
  /// but refusing. Unlike an unreachable server this burns the retry budget.
  bool rejectsWrites = false;

  /// The next insert is saved, but its reply never reaches the client.
  bool loseNextReply = false;

  /// Runs after an insert is stored and before the reply, to model a user
  /// action that lands while the request is in flight.
  Future<void> Function()? onInsert;

  int _nextId = 1;

  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  User? get currentUser => _testUser;

  @override
  bool get isAuthenticated => true;

  void _guard() {
    if (!isReachable) throw _unreachable();
  }

  void _guardWrite() {
    _guard();
    if (rejectsWrites) {
      throw StateError('new row violates row-level security policy');
    }
  }

  @override
  Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async {
    _guardWrite();

    // Like the real table: a client-supplied id is honoured, and reusing one is
    // rejected as a duplicate key.
    final id = (data['id'] as String?) ?? 'remote-${_nextId++}';
    if (rows.containsKey(id)) {
      throw const PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
    }

    final row = {...data, 'id': id};
    rows[id] = row;
    await onInsert?.call();

    if (loseNextReply) {
      loseNextReply = false;
      throw _unreachable();
    }
    return row;
  }

  @override
  Future<Map<String, dynamic>> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    _guard();

    if (!rows.containsKey(id)) {
      // What PostgREST answers when `.single()` matches no row.
      throw const PostgrestException(
        message: 'JSON object requested, multiple (or no) rows returned',
        code: 'PGRST116',
      );
    }

    final row = {...data, 'id': id};
    rows[id] = row;
    return row;
  }

  /// Counts pulls so tests can assert that redundant syncs were collapsed.
  int fetchCount = 0;

  @override
  Future<bool> hasAnyTransactions() async {
    _guard();
    return rows.isNotEmpty;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    _guard();
    fetchCount++;
    return rows.values.map((row) => {...row}).toList();
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _guard();
    rows.remove(id);
  }
}

class FakeRecurringTransactionRemoteSource
    implements RecurringTransactionRemoteSource {
  final Map<String, Map<String, dynamic>> rows = {};

  bool isReachable = true;
  int _nextId = 1;

  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  User? get currentUser => _testUser;

  @override
  bool get isAuthenticated => true;

  void _guard() {
    if (!isReachable) throw _unreachable();
  }

  @override
  Future<Map<String, dynamic>> addRecurringTransaction(
    Map<String, dynamic> data,
  ) async {
    _guard();

    final id = 'recurring-${_nextId++}';
    final row = {...data, 'id': id};
    rows[id] = row;
    return row;
  }

  @override
  Future<Map<String, dynamic>> updateRecurringTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    _guard();

    if (!rows.containsKey(id)) {
      throw StateError('No recurring transaction $id');
    }

    final row = {...data, 'id': id};
    rows[id] = row;
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRecurringTransactions() async {
    _guard();
    return rows.values.map((row) => {...row}).toList();
  }

  @override
  Future<void> deleteRecurringTransaction(String id) async {
    _guard();
    rows.remove(id);
  }
}

class FakeCategoryRemoteSource implements CategoryRemoteSource {
  final Map<String, Map<String, dynamic>> rows = {};

  bool isReachable = true;
  int _nextId = 1;

  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  User? get currentUser => _testUser;

  @override
  bool get isAuthenticated => true;

  void _guard() {
    if (!isReachable) throw _unreachable();
  }

  @override
  Future<Map<String, dynamic>> addCategory(Map<String, dynamic> data) async {
    _guard();

    final id = 'category-${_nextId++}';
    final row = {...data, 'id': id};
    rows[id] = row;
    return row;
  }

  @override
  Future<Map<String, dynamic>> updateCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    _guard();

    final row = {...data, 'id': id};
    rows[id] = row;
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    _guard();
    return rows.values.map((row) => {...row}).toList();
  }

  @override
  Future<void> deleteCategory(String id) async {
    _guard();
    rows.remove(id);
  }
}
