import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../categories/data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../models/field_type.dart';
import '../models/import_stats.dart';
import '../models/import_transaction_draft.dart';

List<Map<String, String>> parseCsvRows(List<int> bytes) {
  final content = utf8.decode(bytes, allowMalformed: true);
  final table = _parseCsvTable(content);
  if (table.isEmpty) {
    return const [];
  }

  final headers = table.first
      .map((cell) => cell.trim())
      .where((cell) => cell.isNotEmpty)
      .toList(growable: false);

  if (headers.isEmpty) {
    return const [];
  }

  final dateIndex = headers.indexWhere(
    (header) => FieldType.date.aliases.any(_normalizeHeader(header).contains),
  );

  final rows = <Map<String, String>>[];
  for (final row in table.skip(1)) {
    final normalizedRow = _normalizeRowLength(
      row: row,
      expectedLength: headers.length,
      dateIndex: dateIndex == -1 ? null : dateIndex,
    );
    final mapped = <String, String>{};
    var hasValue = false;
    for (var index = 0; index < headers.length; index++) {
      final value = index < normalizedRow.length ? normalizedRow[index].trim() : '';
      mapped[headers[index]] = value;
      hasValue = hasValue || value.isNotEmpty;
    }

    if (hasValue) {
      rows.add(mapped);
    }
  }

  return rows;
}

Map<FieldType, String> inferColumnMapping(List<String> headers) {
  final mapping = <FieldType, String>{};
  final normalized = {
    for (final header in headers) header: _normalizeHeader(header),
  };

  for (final field in FieldType.values) {
    for (final header in headers) {
      final candidate = normalized[header]!;
      if (field.aliases.any(candidate.contains)) {
        mapping[field] = header;
        break;
      }
    }
  }

  return mapping;
}

List<ImportTransactionDraft> parseRows(
  List<Map<String, String>> rawRows,
  Map<FieldType, String> columnMapping,
) {
  return [
    for (var index = 0; index < rawRows.length; index++)
      _parseRow(
        index: index,
        row: rawRows[index],
        columnMapping: columnMapping,
      ),
  ];
}

ImportTransactionDraft enrichDraftWithCategories(
  ImportTransactionDraft draft,
  Map<FieldType, String> columnMapping,
  List<CategoryModel> categories,
) {
  final categoryHeader = columnMapping[FieldType.category];
  final rawCategory = categoryHeader == null
      ? null
      : _cleanText(draft.raw[categoryHeader]);
  final resolvedCategoryId = rawCategory == null
      ? draft.categoryId
      : _matchCategoryId(
          value: rawCategory,
          categories: categories,
        );

  final category = resolvedCategoryId == null
      ? null
      : categories.where((item) => item.id == resolvedCategoryId).firstOrNull;

  return draft.copyWith(
    categoryId: resolvedCategoryId,
    type: category == null
        ? draft.type
        : (category.type == CategoryType.expense
              ? TransactionType.expense
              : TransactionType.income),
  );
}

ImportTransactionDraft validateDraft(ImportTransactionDraft draft) {
  final errors = <String>[];

  if (draft.amount == null) {
    errors.add('Amount is required and must be a valid number.');
  }

  if (draft.date == null) {
    errors.add('Date is required and must be valid, for example May 14, 2025.');
  }

  if (draft.categoryId == null) {
    errors.add('Category is required before import can finish.');
  }

  return draft.copyWith(errors: errors, isValid: errors.isEmpty);
}

ImportStats computeImportStats(List<ImportTransactionDraft> drafts) {
  var income = 0.0;
  var expense = 0.0;
  var validCount = 0;

  for (final draft in drafts) {
    if (!draft.isValid || draft.amount == null) {
      continue;
    }

    validCount += 1;
    if (draft.type == TransactionType.expense) {
      expense += draft.amount!.abs();
    } else {
      income += draft.amount!.abs();
    }
  }

  return ImportStats(
    total: drafts.length,
    validCount: validCount,
    errorCount: drafts.length - validCount,
    totalIncome: income,
    totalExpense: expense,
  );
}

TransactionType inferDraftType(double? amount) {
  return TransactionType.expense;
}

String buildImportedTransactionTitle(
  ImportTransactionDraft draft,
  Map<int, CategoryModel> categoriesById,
) {
  final payee = _cleanText(draft.payee);
  final title = _cleanText(draft.title);
  if (title != null) {
    return title;
  }

  if (payee != null) {
    return payee;
  }

  final note = _cleanText(draft.note);
  if (note != null) {
    final firstLine = note.split('\n').first.trim();
    if (firstLine.isNotEmpty) {
      return firstLine;
    }
  }

  final categoryName = draft.categoryId == null
      ? null
      : categoriesById[draft.categoryId]?.name.trim();
  if (categoryName != null && categoryName.isNotEmpty) {
    return categoryName;
  }

  return draft.type == TransactionType.expense
      ? 'Imported Expense'
      : 'Imported Income';
}

ImportTransactionDraft _parseRow({
  required int index,
  required Map<String, String> row,
  required Map<FieldType, String> columnMapping,
}) {
  final amountCell = _readMappedValue(row, columnMapping, FieldType.amount);
  final dateCell = _readMappedValue(row, columnMapping, FieldType.date);

  return ImportTransactionDraft(
    id: 'draft-$index',
    raw: Map.unmodifiable(row),
    title: _readMappedValue(row, columnMapping, FieldType.title),
    amount: _parseAmount(amountCell),
    date: _parseDate(dateCell),
    type: TransactionType.expense,
    categoryId: null,
    payee: _readMappedValue(row, columnMapping, FieldType.payee),
    note: _readMappedValue(row, columnMapping, FieldType.note),
    paymentMethod: _readMappedValue(row, columnMapping, FieldType.paymentMethod),
    recurringTemplateId: null,
    errors: const [],
    isValid: true,
    isSelected: false,
  );
}

String? _readMappedValue(
  Map<String, String> row,
  Map<FieldType, String> columnMapping,
  FieldType fieldType,
) {
  final header = columnMapping[fieldType];
  if (header == null) {
    return null;
  }

  return _cleanText(row[header]);
}

double? _parseAmount(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }

  final trimmed = raw.trim();
  final isNegative =
      trimmed.startsWith('-') ||
      (trimmed.startsWith('(') && trimmed.endsWith(')'));
  final cleaned = trimmed
      .replaceAll(RegExp(r'[\s,]'), '')
      .replaceAll('₹', '')
      .replaceAll('\$', '')
      .replaceAll('€', '')
      .replaceAll('£', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll('+', '');
  final value = double.tryParse(cleaned);
  if (value == null) {
    return null;
  }

  return isNegative ? -value.abs() : value.abs();
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }

  final value = raw.trim();
  final direct = DateTime.tryParse(value);
  if (direct != null) {
    return direct;
  }

  const patterns = [
    'MMMM d, yyyy',
    'MMMM dd, yyyy',
    'MMM d, yyyy',
    'MMM dd, yyyy',
    'dd/MM/yyyy',
    'd/M/yyyy',
    'MM/dd/yyyy',
    'M/d/yyyy',
    'dd-MM-yyyy',
    'd-M-yyyy',
    'MM-dd-yyyy',
    'M-d-yyyy',
    'yyyy/MM/dd',
    'yyyy-MM-dd',
    'dd MMM yyyy',
    'd MMM yyyy',
    'MMM dd yyyy',
    'MMM d yyyy',
  ];

  for (final pattern in patterns) {
    try {
      return DateFormat(pattern).parseStrict(value);
    } catch (_) {}
  }

  return null;
}

int? _matchCategoryId({
  required String value,
  required List<CategoryModel> categories,
}) {
  final normalizedValue = _normalizeHeader(value);
  for (final category in categories) {
    if (_normalizeHeader(category.name) == normalizedValue) {
      return category.id;
    }
  }

  return null;
}

String? _cleanText(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _normalizeHeader(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

List<String> _normalizeRowLength({
  required List<String> row,
  required int expectedLength,
  required int? dateIndex,
}) {
  if (row.length <= expectedLength || dateIndex == null || dateIndex >= row.length) {
    return row;
  }

  final extraCells = row.length - expectedLength;
  final mergeEnd = dateIndex + extraCells + 1;
  if (mergeEnd > row.length) {
    return row;
  }

  return [
    ...row.take(dateIndex),
    row.sublist(dateIndex, mergeEnd).join(', ').trim(),
    ...row.skip(mergeEnd),
  ];
}

List<List<String>> _parseCsvTable(String input) {
  final rows = <List<String>>[];
  final row = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < input.length; index++) {
    final char = input[index];
    final next = index + 1 < input.length ? input[index + 1] : null;

    if (char == '"') {
      if (inQuotes && next == '"') {
        buffer.write('"');
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (!inQuotes && char == ',') {
      row.add(buffer.toString());
      buffer.clear();
      continue;
    }

    if (!inQuotes && (char == '\n' || char == '\r')) {
      if (char == '\r' && next == '\n') {
        index += 1;
      }
      row.add(buffer.toString());
      buffer.clear();
      rows.add(List<String>.from(row));
      row.clear();
      continue;
    }

    buffer.write(char);
  }

  final hasTrailingData = buffer.isNotEmpty || row.isNotEmpty;
  if (hasTrailingData) {
    row.add(buffer.toString());
    rows.add(List<String>.from(row));
  }

  return rows;
}
