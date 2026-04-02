import 'field_type.dart';
import 'import_stats.dart';
import 'import_transaction_draft.dart';

enum ImportStep { upload, mapping, preview, confirm }

class ImportSession {
  final String? fileName;
  final ImportStep step;
  final List<Map<String, String>> rawRows;
  final Map<FieldType, String> columnMapping;
  final List<ImportTransactionDraft> drafts;
  final ImportStats stats;
  final bool isLoading;
  final String? errorMessage;

  const ImportSession({
    required this.fileName,
    required this.step,
    required this.rawRows,
    required this.columnMapping,
    required this.drafts,
    required this.stats,
    required this.isLoading,
    required this.errorMessage,
  });

  const ImportSession.initial()
    : fileName = null,
      step = ImportStep.upload,
      rawRows = const [],
      columnMapping = const {},
      drafts = const [],
      stats = const ImportStats.empty(),
      isLoading = false,
      errorMessage = null;

  List<ImportTransactionDraft> get validDrafts =>
      drafts.where((draft) => draft.isValid).toList(growable: false);

  List<ImportTransactionDraft> get invalidDrafts =>
      drafts.where((draft) => !draft.isValid).toList(growable: false);

  List<ImportTransactionDraft> get selectedDrafts =>
      drafts.where((draft) => draft.isSelected).toList(growable: false);

  List<String> get headers {
    if (rawRows.isEmpty) {
      return const [];
    }

    return rawRows.first.keys.toList(growable: false);
  }

  ImportSession copyWith({
    String? fileName,
    bool clearFileName = false,
    ImportStep? step,
    List<Map<String, String>>? rawRows,
    Map<FieldType, String>? columnMapping,
    List<ImportTransactionDraft>? drafts,
    ImportStats? stats,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ImportSession(
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      step: step ?? this.step,
      rawRows: rawRows ?? this.rawRows,
      columnMapping: columnMapping ?? this.columnMapping,
      drafts: drafts ?? this.drafts,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
