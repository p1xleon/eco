import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../categories/data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/providers/transaction_repository_provider.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/field_type.dart';
import '../models/import_session.dart';
import '../models/import_transaction_draft.dart';
import '../services/import_parser.dart';

final importControllerProvider =
    StateNotifierProvider.autoDispose<ImportController, ImportSession>((ref) {
      final repository = ref.read(transactionRepositoryProvider);
      return ImportController(repository);
    });

class ImportController extends StateNotifier<ImportSession> {
  final TransactionRepository _repository;

  ImportController(this._repository) : super(const ImportSession.initial());

  Future<void> loadFile({
    required String fileName,
    required List<int> bytes,
    required List<CategoryModel> categories,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      step: ImportStep.upload,
    );

    try {
      final rawRows = parseCsvRows(bytes);
      final mapping = inferColumnMapping(
        rawRows.isEmpty ? const [] : rawRows.first.keys.toList(growable: false),
      );
      final drafts = _rebuildDrafts(
        rawRows: rawRows,
        columnMapping: mapping,
        categories: categories,
      );

      state = state.copyWith(
        fileName: fileName,
        rawRows: rawRows,
        columnMapping: mapping,
        drafts: drafts,
        stats: computeImportStats(drafts),
        step: rawRows.isEmpty ? ImportStep.upload : ImportStep.mapping,
        isLoading: false,
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not read that CSV file. ${error.toString()}',
      );
    }
  }

  void setStep(ImportStep step) {
    state = state.copyWith(step: step);
  }

  void reset() {
    state = const ImportSession.initial();
  }

  void updateMapping({
    required FieldType fieldType,
    required String? columnName,
    required List<CategoryModel> categories,
  }) {
    final mapping = Map<FieldType, String>.from(state.columnMapping);
    if (columnName == null || columnName.isEmpty) {
      mapping.remove(fieldType);
    } else {
      mapping[fieldType] = columnName;
    }

    final drafts = _rebuildDrafts(
      rawRows: state.rawRows,
      columnMapping: mapping,
      categories: categories,
    );

    state = state.copyWith(
      columnMapping: mapping,
      drafts: drafts,
      stats: computeImportStats(drafts),
    );
  }

  void updateDraft(ImportTransactionDraft draft) {
    final drafts = [
      for (final current in state.drafts)
        if (current.id == draft.id) validateDraft(draft) else current,
    ];
    state = state.copyWith(drafts: drafts, stats: computeImportStats(drafts));
  }

  void toggleDraftSelection(String draftId, bool isSelected) {
    final drafts = [
      for (final draft in state.drafts)
        if (draft.id == draftId)
          draft.copyWith(isSelected: isSelected)
        else
          draft,
    ];
    state = state.copyWith(drafts: drafts, stats: computeImportStats(drafts));
  }

  void toggleSelectAll(bool isSelected) {
    final drafts = [
      for (final draft in state.drafts) draft.copyWith(isSelected: isSelected),
    ];
    state = state.copyWith(drafts: drafts, stats: computeImportStats(drafts));
  }

  void applyToSelected({
    TransactionType? type,
    int? categoryId,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    int? recurringTemplateId,
    bool clearRecurringTemplateId = false,
  }) {
    final drafts = [
      for (final draft in state.drafts)
        if (draft.isSelected)
          validateDraft(
            draft.copyWith(
              type: type,
              categoryId: categoryId,
              paymentMethod: paymentMethod,
              clearPaymentMethod: clearPaymentMethod,
              recurringTemplateId: recurringTemplateId,
              clearRecurringTemplateId: clearRecurringTemplateId,
            ),
          )
        else
          draft,
    ];

    state = state.copyWith(drafts: drafts, stats: computeImportStats(drafts));
  }

  void deleteSelected() {
    final drafts = state.drafts
        .where((draft) => !draft.isSelected)
        .toList(growable: false);
    state = state.copyWith(drafts: drafts, stats: computeImportStats(drafts));
  }

  Future<List<TransactionModel>> commit({
    required bool skipInvalidDrafts,
    required List<CategoryModel> categories,
  }) async {
    final draftsToCommit = skipInvalidDrafts
        ? state.validDrafts
        : state.drafts.where((draft) => draft.isValid).toList(growable: false);

    if (!skipInvalidDrafts && state.invalidDrafts.isNotEmpty) {
      throw StateError('Fix or skip invalid rows before confirming the import.');
    }

    if (draftsToCommit.isEmpty) {
      throw StateError('No valid rows are ready to import.');
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final categoriesById = {for (final category in categories) category.id: category};
      final transactions = draftsToCommit
          .map((draft) => _toTransactionModel(draft, categoriesById))
          .toList(growable: false);
      final saved = await _repository.addAll(transactions);
      state = state.copyWith(isLoading: false);
      return saved;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Import failed. ${error.toString()}',
      );
      rethrow;
    }
  }

  List<ImportTransactionDraft> _rebuildDrafts({
    required List<Map<String, String>> rawRows,
    required Map<FieldType, String> columnMapping,
    required List<CategoryModel> categories,
  }) {
    final parsedDrafts = parseRows(rawRows, columnMapping);
    return parsedDrafts
        .map(
          (draft) => validateDraft(
            enrichDraftWithCategories(draft, columnMapping, categories),
          ),
        )
        .toList(growable: false);
  }

  TransactionModel _toTransactionModel(
    ImportTransactionDraft draft,
    Map<int, CategoryModel> categoriesById,
  ) {
    final now = DateTime.now().toUtc();
    final transaction = TransactionModel()
      ..title = buildImportedTransactionTitle(draft, categoriesById)
      ..amount = draft.amount!.abs()
      ..date = draft.date!
      ..type = draft.type
      ..status = TransactionStatus.paid
      ..categoryId = draft.categoryId!
      ..paymentMethod = _clean(draft.paymentMethod)
      ..payee = _clean(draft.payee)
      ..note = _clean(draft.note)
      ..recurringTemplateId = draft.recurringTemplateId
      ..isRecurringInstance = draft.recurringTemplateId != null
      ..createdAt = now
      ..updatedAt = null;

    return transaction;
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
