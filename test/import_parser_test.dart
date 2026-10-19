import 'package:eco/features/transactions/import/models/field_type.dart';
import 'package:eco/features/transactions/import/services/import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _mapping = {
  FieldType.amount: 'Amount',
  FieldType.date: 'Date',
  FieldType.title: 'Title',
};

double? amountOf(String raw) => parseRows([
  {'Amount': raw, 'Date': '01/02/2026', 'Title': 't'},
], _mapping).single.amount;

DateTime? dateOf(String raw) => parseRows([
  {'Amount': '10', 'Date': raw, 'Title': 't'},
], _mapping).single.date;

void main() {
  group('amounts', () {
    test('reads dot-decimal and Indian grouping', () {
      expect(amountOf('1,234.56'), 1234.56);
      expect(amountOf('1,00,000'), 100000);
      expect(amountOf('1,234'), 1234);
      expect(amountOf('₹ 2,500'), 2500);
    });

    test('reads comma-decimal instead of silently scaling it', () {
      expect(amountOf('1.234,56'), 1234.56);
      expect(amountOf('1,5'), 1.5);
      expect(amountOf('12,50'), 12.5);
    });

    test('keeps the sign for negatives and brackets', () {
      expect(amountOf('-200'), -200);
      expect(amountOf('(50.00)'), -50);
    });

    test('rejects zero, NaN, infinity and text', () {
      for (final raw in ['0', '0.00', 'NaN', 'Infinity', 'Rs. 100', 'abc']) {
        expect(amountOf(raw), isNull, reason: raw);
      }
    });
  });

  group('dates', () {
    test('two-digit years land in the right century', () {
      expect(dateOf('14/05/25'), DateTime(2025, 5, 14));
      expect(dateOf('01/01/99'), DateTime(1999, 1, 1));
    });

    test('day comes first, so 03/04/2025 is 3 April', () {
      expect(dateOf('03/04/2025'), DateTime(2025, 4, 3));
    });

    test('a year outside the sane range is flagged before import', () {
      final draft = validateDraft(
        parseRows([
          {'Amount': '10', 'Date': '01/01/1970', 'Title': 't'},
        ], _mapping).single,
      );

      expect(draft.errors.any((e) => e.contains('Date looks wrong')), isTrue);
    });
  });
}
