import 'dart:convert';
import 'dart:typed_data';

import '../../features/categories/data/models/category_model.dart';
import '../../features/recurring/data/models/recurring_transaction_model.dart';
import '../../features/settings/data/models/transaction_preset_model.dart';
import '../../features/transactions/data/models/transaction_model.dart';
import '../crypto/field_cipher.dart';
import '../sync/sync_state.dart';

/// The whole local database as one encrypted file.
///
/// Unlike the mappers, which write what the *server* keeps, this is a faithful
/// snapshot of local state: local ids, sync state and all. A restore has to be
/// able to stand in for the device, and a backup that quietly dropped the
/// fields the sync engine relies on would restore into a database that looks
/// fine and syncs wrongly.
///
/// The payload is encrypted whole rather than field by field. A backup file
/// leaves the device — that is the entire point of it — so unlike a server row
/// there is nothing to gain by leaving `date` or `type` readable.
class BackupCodec {
  const BackupCodec(this._cipher);

  /// Bumped when the payload shape changes. [decode] refuses anything newer
  /// than it understands rather than guessing at unknown fields.
  static const formatVersion = 1;

  final FieldCipher _cipher;

  Uint8List encode(BackupPayload payload) {
    final json = jsonEncode({
      'format_version': formatVersion,
      'created_at': payload.createdAt.toIso8601String(),
      'transactions': payload.transactions.map(_transactionToJson).toList(),
      'categories': payload.categories.map(_categoryToJson).toList(),
      'recurring': payload.recurring.map(_recurringToJson).toList(),
      'presets': payload.presets.map(_presetToJson).toList(),
    });

    return Uint8List.fromList(utf8.encode(_cipher.encrypt(json)));
  }

  BackupPayload decode(List<int> bytes) {
    final decrypted = _cipher.decrypt(utf8.decode(bytes));
    final json = jsonDecode(decrypted) as Map<String, dynamic>;

    final version = json['format_version'] as int? ?? 0;
    if (version > formatVersion) {
      throw FormatException(
        'This backup was written by a newer version of the app '
        '(format $version, this build reads $formatVersion)',
      );
    }

    return BackupPayload(
      createdAt: DateTime.parse(json['created_at'] as String),
      transactions: [
        for (final item in json['transactions'] as List<dynamic>)
          _transactionFromJson(item as Map<String, dynamic>),
      ],
      categories: [
        for (final item in json['categories'] as List<dynamic>)
          _categoryFromJson(item as Map<String, dynamic>),
      ],
      recurring: [
        for (final item in json['recurring'] as List<dynamic>)
          _recurringFromJson(item as Map<String, dynamic>),
      ],
      presets: [
        for (final item in json['presets'] as List<dynamic>)
          _presetFromJson(item as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> _transactionToJson(TransactionModel item) => {
        'id': item.id,
        'remote_id': item.remoteId,
        'title': item.title,
        'amount': item.amount,
        'date': item.date.toIso8601String(),
        'type': item.type.name,
        'status': item.status.name,
        'category_id': item.categoryId,
        'payment_method': item.paymentMethod,
        'payee': item.payee,
        'note': item.note,
        'created_at': item.createdAt.toIso8601String(),
        'updated_at': item.updatedAt?.toIso8601String(),
        'recurring_id': item.recurringId,
        'recurring_template_id': item.recurringTemplateId,
        'is_recurring_instance': item.isRecurringInstance,
        'sync_state': item.syncState.name,
        'local_updated_at': item.localUpdatedAt?.toIso8601String(),
      };

  TransactionModel _transactionFromJson(Map<String, dynamic> json) {
    return TransactionModel()
      ..id = json['id'] as int
      ..remoteId = json['remote_id'] as String?
      ..title = json['title'] as String
      ..amount = (json['amount'] as num).toDouble()
      ..date = DateTime.parse(json['date'] as String)
      ..type = _enumByName(TransactionType.values, json['type'])
      ..status = _enumByName(TransactionStatus.values, json['status'])
      ..categoryId = (json['category_id'] as num).toInt()
      ..paymentMethod = json['payment_method'] as String?
      ..payee = json['payee'] as String?
      ..note = json['note'] as String?
      ..createdAt = DateTime.parse(json['created_at'] as String)
      ..updatedAt = _dateOrNull(json['updated_at'])
      ..recurringId = json['recurring_id'] as String?
      ..recurringTemplateId = (json['recurring_template_id'] as num?)?.toInt()
      ..isRecurringInstance = json['is_recurring_instance'] as bool?
      ..syncState = _enumByName(SyncState.values, json['sync_state'])
      ..localUpdatedAt = _dateOrNull(json['local_updated_at']);
  }

  Map<String, dynamic> _categoryToJson(CategoryModel item) => {
        'id': item.id,
        'remote_id': item.remoteId,
        'name': item.name,
        'type': item.type.name,
        'color': item.color,
        'icon': item.icon,
        'sync_state': item.syncState.name,
        'local_updated_at': item.localUpdatedAt?.toIso8601String(),
      };

  CategoryModel _categoryFromJson(Map<String, dynamic> json) {
    return CategoryModel()
      ..id = json['id'] as int
      ..remoteId = json['remote_id'] as String?
      ..name = json['name'] as String
      ..type = _enumByName(CategoryType.values, json['type'])
      ..color = (json['color'] as num).toInt()
      ..icon = json['icon'] as String?
      ..syncState = _enumByName(SyncState.values, json['sync_state'])
      ..localUpdatedAt = _dateOrNull(json['local_updated_at']);
  }

  Map<String, dynamic> _recurringToJson(RecurringTransactionModel item) => {
        'id': item.id,
        'remote_id': item.remoteId,
        'title': item.title,
        'type': item.type.name,
        'default_amount': item.defaultAmount,
        'amount_type': item.amountType.name,
        'category_id': item.categoryId,
        'account_id': item.accountId,
        'interval_type': item.intervalType.name,
        'interval_count': item.intervalCount,
        'next_due_date': item.nextDueDate.toIso8601String(),
        'end_date': item.endDate?.toIso8601String(),
        'is_active': item.isActive,
        'note': item.note,
        'created_at': item.createdAt.toIso8601String(),
        'updated_at': item.updatedAt?.toIso8601String(),
        'sync_state': item.syncState.name,
        'local_updated_at': item.localUpdatedAt?.toIso8601String(),
      };

  RecurringTransactionModel _recurringFromJson(Map<String, dynamic> json) {
    return RecurringTransactionModel()
      ..id = json['id'] as int
      ..remoteId = json['remote_id'] as String?
      ..title = json['title'] as String
      ..type = _enumByName(TransactionType.values, json['type'])
      ..defaultAmount = (json['default_amount'] as num?)?.toDouble()
      ..amountType = _enumByName(RecurringAmountType.values, json['amount_type'])
      ..categoryId = (json['category_id'] as num).toInt()
      ..accountId = json['account_id'] as String?
      ..intervalType =
          _enumByName(RecurringIntervalType.values, json['interval_type'])
      ..intervalCount = (json['interval_count'] as num).toInt()
      ..nextDueDate = DateTime.parse(json['next_due_date'] as String)
      ..endDate = _dateOrNull(json['end_date'])
      ..isActive = json['is_active'] as bool
      ..note = json['note'] as String?
      ..createdAt = DateTime.parse(json['created_at'] as String)
      ..updatedAt = _dateOrNull(json['updated_at'])
      ..syncState = _enumByName(SyncState.values, json['sync_state'])
      ..localUpdatedAt = _dateOrNull(json['local_updated_at']);
  }

  Map<String, dynamic> _presetToJson(TransactionPresetModel item) => {
        'id': item.id,
        'type': item.type.name,
        'value': item.value,
      };

  TransactionPresetModel _presetFromJson(Map<String, dynamic> json) {
    return TransactionPresetModel()
      ..id = json['id'] as int
      ..type = _enumByName(TransactionPresetType.values, json['type'])
      ..value = json['value'] as String;
  }

  static DateTime? _dateOrNull(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  /// Resolves by name rather than index so reordering an enum cannot silently
  /// turn every income into an expense on restore.
  static T _enumByName<T extends Enum>(List<T> values, Object? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => throw FormatException('Unknown value for ${T.toString()}: $name'),
    );
  }
}

/// Everything a restore needs to rebuild the local database.
class BackupPayload {
  const BackupPayload({
    required this.createdAt,
    required this.transactions,
    required this.categories,
    required this.recurring,
    required this.presets,
  });

  final DateTime createdAt;
  final List<TransactionModel> transactions;
  final List<CategoryModel> categories;
  final List<RecurringTransactionModel> recurring;
  final List<TransactionPresetModel> presets;

  int get recordCount =>
      transactions.length + categories.length + recurring.length + presets.length;
}
