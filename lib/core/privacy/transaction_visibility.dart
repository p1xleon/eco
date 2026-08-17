import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recurring/data/models/recurring_transaction_model.dart';
import '../../features/transactions/data/models/transaction_model.dart';

enum TransactionVisibilityMode { normal, masked, invisible }

class TransactionVisibilityState {
  final TransactionVisibilityMode mode;
  final DateTime? invisibleSince;
  final Set<String> hiddenTransactionKeys;
  final Set<String> hiddenRecurringTemplateKeys;

  const TransactionVisibilityState({
    this.mode = TransactionVisibilityMode.normal,
    this.invisibleSince,
    this.hiddenTransactionKeys = const <String>{},
    this.hiddenRecurringTemplateKeys = const <String>{},
  });

  bool get isMasked => mode == TransactionVisibilityMode.masked;
  bool get isInvisible => mode == TransactionVisibilityMode.invisible;

  bool isTransactionVisible(TransactionModel transaction) {
    if (!isInvisible) {
      return true;
    }

    return !hiddenTransactionKeys.contains(
      transactionVisibilityKey(transaction),
    );
  }

  List<TransactionModel> applyToTransactions(
    List<TransactionModel> transactions,
  ) {
    if (!isInvisible) {
      return transactions;
    }

    return transactions.where(isTransactionVisible).toList();
  }

  bool isRecurringTemplateVisible(RecurringTransactionModel template) {
    if (!isInvisible) {
      return true;
    }

    return recurringTemplateVisibilityKeys(
      template,
    ).every((key) => !hiddenRecurringTemplateKeys.contains(key));
  }

  List<RecurringTransactionModel> applyToRecurringTemplates(
    List<RecurringTransactionModel> templates,
  ) {
    if (!isInvisible) {
      return templates;
    }

    return templates.where(isRecurringTemplateVisible).toList();
  }

  String displayAmount(String actual, {String placeholder = '•••'}) {
    return isMasked ? placeholder : actual;
  }

  String displayTitle(
    TransactionModel transaction, {
    String fallback = 'Transaction',
  }) {
    final resolved = transaction.title.trim().isEmpty
        ? fallback
        : transaction.title.trim();

    if (!isMasked) {
      return resolved;
    }

    return maskText('title:${transaction.id}:${transaction.title}', words: 2);
  }

  String displayRecurringTitle(
    RecurringTransactionModel template, {
    String fallback = 'Recurring',
  }) {
    final resolved = template.title.trim().isEmpty
        ? fallback
        : template.title.trim();

    if (!isMasked) {
      return resolved;
    }

    return maskText('recurring:${template.id}:${template.title}', words: 2);
  }

  String displayText(
    String? value, {
    required String seed,
    String placeholder = '—',
    int words = 2,
  }) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return placeholder;
    }

    if (!isMasked) {
      return trimmed;
    }

    return maskText(seed, words: words);
  }

  String displayCategory(String value, {required String seed}) {
    if (!isMasked) {
      return value;
    }

    return maskText(seed, words: 1);
  }

  String maskText(String seed, {int words = 2}) {
    final count = words.clamp(1, 3);
    var state = seed.codeUnits.fold<int>(0, (hash, codeUnit) {
      return (hash * 31 + codeUnit) & 0x7fffffff;
    });

    final parts = List.generate(count, (index) {
      final syllableCount = 2 + ((state + index) % 2);
      final buffer = StringBuffer();
      for (var i = 0; i < syllableCount; i++) {
        final syllableIndex =
            (state + (index * 13) + (i * 7)) % _maskedSyllables.length;
        buffer.write(_maskedSyllables[syllableIndex]);
        state = ((state * 1103515245) + 12345) & 0x7fffffff;
      }
      return buffer.toString();
    });

    return parts.join(' ');
  }
}

class TransactionVisibilityNotifier
    extends StateNotifier<TransactionVisibilityState> {
  TransactionVisibilityNotifier([
    super.state = const TransactionVisibilityState(),
    Future<void> Function(TransactionVisibilityState state)? persist,
  ]) : _persist = persist ?? _noopPersist;

  final Future<void> Function(TransactionVisibilityState state) _persist;

  void setMode(
    TransactionVisibilityMode mode, {
    List<TransactionModel> existingTransactions = const [],
    List<RecurringTransactionModel> existingRecurringTemplates = const [],
  }) {
    if (mode == state.mode) {
      return;
    }

    final recurringKeys = mode == TransactionVisibilityMode.invisible
        ? existingRecurringTemplates
              .expand(recurringTemplateVisibilityKeys)
              .toSet()
        : const <String>{};

    state = TransactionVisibilityState(
      mode: mode,
      invisibleSince: mode == TransactionVisibilityMode.invisible
          ? DateTime.now().toUtc()
          : null,
      hiddenTransactionKeys: mode == TransactionVisibilityMode.invisible
          ? existingTransactions.map(transactionVisibilityKey).toSet()
          : const <String>{},
      hiddenRecurringTemplateKeys: recurringKeys,
    );
    _persist(state);
  }

  void registerVisibleTransaction(TransactionModel transaction) {
    if (!state.isInvisible) {
      return;
    }

    final nextHidden = Set<String>.from(state.hiddenTransactionKeys)
      ..remove(transactionVisibilityKey(transaction));
    state = TransactionVisibilityState(
      mode: state.mode,
      invisibleSince: state.invisibleSince,
      hiddenTransactionKeys: nextHidden,
      hiddenRecurringTemplateKeys: state.hiddenRecurringTemplateKeys,
    );
    _persist(state);
  }

  void registerVisibleRecurringTemplate(RecurringTransactionModel template) {
    if (!state.isInvisible) {
      return;
    }

    final nextHidden = Set<String>.from(state.hiddenRecurringTemplateKeys)
      ..removeAll(recurringTemplateVisibilityKeys(template));
    state = TransactionVisibilityState(
      mode: state.mode,
      invisibleSince: state.invisibleSince,
      hiddenTransactionKeys: state.hiddenTransactionKeys,
      hiddenRecurringTemplateKeys: nextHidden,
    );
    _persist(state);
  }

  static Future<void> _noopPersist(TransactionVisibilityState state) async {}
}

final transactionVisibilityProvider =
    StateNotifierProvider<
      TransactionVisibilityNotifier,
      TransactionVisibilityState
    >((ref) {
      return TransactionVisibilityNotifier();
    });

String transactionVisibilityKey(TransactionModel transaction) {
  final remoteId = transaction.remoteId?.trim();
  if (remoteId != null && remoteId.isNotEmpty) {
    return 'remote:$remoteId';
  }

  return 'local:${transaction.id}';
}

Set<String> recurringTemplateVisibilityKeys(
  RecurringTransactionModel template,
) {
  final keys = <String>{'local:${template.id}'};
  final remoteId = template.remoteId?.trim();
  if (remoteId != null && remoteId.isNotEmpty) {
    keys.add('remote:$remoteId');
  }
  return keys;
}

const _maskedSyllables = [
  'ba',
  'cor',
  'den',
  'fi',
  'gan',
  'lu',
  'mer',
  'no',
  'pra',
  'qui',
  'sen',
  'tor',
  'va',
  'xel',
  'yor',
  'zin',
];
