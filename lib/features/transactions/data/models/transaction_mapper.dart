import '../../../../core/crypto/field_cipher.dart';
import 'transaction_model.dart';

/// Column holding the category's server-side uuid.
///
/// The legacy `category_id` column holds the *device-local* Isar id, which only
/// means anything on the device that wrote it. Both are sent so a client
/// running the old code keeps working; readers prefer this one.
const transactionCategoryRemoteIdColumn = 'category_remote_id';

/// Column holding the encrypted amount.
///
/// `amount` is `double precision` and cannot hold ciphertext, so encrypted
/// amounts travel in their own text column. Rows written before encryption was
/// set up still have the numeric one; [TransactionMapper.fromJson] reads
/// whichever is present.
const transactionAmountEncryptedColumn = 'amount_enc';

extension TransactionMapper on TransactionModel {
  /// Builds the server row.
  ///
  /// With a [cipher], the fields that say what was bought and for how much go
  /// up as ciphertext. Without one — before the user has set up a key — this
  /// writes exactly what it always did, so an install that has not migrated
  /// yet keeps syncing instead of stalling.
  ///
  /// `date`, `type`, `status` and the id columns stay readable either way: the
  /// server pages transactions with `order('date')`, so encrypting that column
  /// would break sync itself.
  Map<String, dynamic> toJson(
    String userId, {
    bool includeId = false,
    String? categoryRemoteId,
    FieldCipher? cipher,
  }) {
    final json = <String, dynamic>{
      'user_id': userId,
      'title': cipher == null ? title : cipher.encrypt(title),
      'amount': cipher == null ? amount : null,
      transactionAmountEncryptedColumn: cipher?.encryptNumber(amount),
      'type': type.name,
      'category_id': categoryId,
      transactionCategoryRemoteIdColumn: categoryRemoteId,
      'status': status.name,
      'payment_method': cipher == null
          ? paymentMethod
          : cipher.encryptNullable(paymentMethod),
      'payee': cipher == null ? payee : cipher.encryptNullable(payee),
      'note': cipher == null ? note : cipher.encryptNullable(note),
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'recurring_id': recurringId,
      'recurring_template_id': recurringTemplateId,
      'is_recurring_instance': isRecurringInstance,
    };

    if (includeId && remoteId != null) {
      json['id'] = remoteId;
    }

    return json;
  }

  /// Builds the local record from a server row.
  ///
  /// [categoryId] is resolved by the caller, which is the only place that can
  /// map the server's category uuid onto a local category. It falls back to the
  /// legacy integer column, so rows written before the uuid column existed keep
  /// working exactly as they did.
  ///
  /// Encrypted and plaintext rows are both readable, which is what lets the
  /// migration run one row at a time. A row that is encrypted when no key is
  /// present throws — see [FieldCipher.readString].
  static TransactionModel fromJson(
    Map<String, dynamic> json, {
    int? categoryId,
    FieldCipher? cipher,
  }) {
    final transaction = TransactionModel();

    transaction.remoteId = json['id'];
    transaction.recurringId = json['recurring_id'];
    transaction.recurringTemplateId = (json['recurring_template_id'] as num?)
        ?.toInt();
    transaction.isRecurringInstance = json['is_recurring_instance'] as bool?;
    transaction.title = FieldCipher.readString(cipher, json['title'])!;
    transaction.amount = FieldCipher.readNumber(
      cipher,
      json[transactionAmountEncryptedColumn] ?? json['amount'],
    )!;
    transaction.date = DateTime.parse(json['date']);
    transaction.type = json['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    transaction.status = switch (json['status']) {
      'pending' => TransactionStatus.pending,
      _ => TransactionStatus.paid,
    };
    transaction.categoryId = categoryId ?? (json['category_id'] as num).toInt();
    transaction.paymentMethod = FieldCipher.readString(
      cipher,
      json['payment_method'],
    );
    transaction.payee = FieldCipher.readString(cipher, json['payee']);
    transaction.note = FieldCipher.readString(cipher, json['note']);
    transaction.createdAt = DateTime.parse(json['created_at']);
    transaction.updatedAt = json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : null;

    return transaction;
  }
}
