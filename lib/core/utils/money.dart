import 'package:intl/intl.dart';

/// Parses an amount typed into a form. Null unless it is a finite number above
/// zero, rounded to cents: `NaN`, `Infinity`, `0` and negatives would otherwise
/// be saved and later break totals and charts.
double? parseAmount(String? text) {
  final value = double.tryParse((text ?? '').trim());
  if (value == null || !value.isFinite || value > 1e12) return null;

  final cents = (value * 100).round() / 100;
  return cents > 0 ? cents : null;
}

final _moneyFormat = NumberFormat('#,##0.00');

/// One way to show an amount everywhere: `₹1,234.50`.
String formatMoney(double amount) => '₹${_moneyFormat.format(amount)}';

/// Rounds a sum to cents, so ten additions of 0.1 give 1.0 and not 0.9999999999999999.
double roundCents(double value) => (value * 100).round() / 100;
