/// Parses an amount typed into a form. Null unless it is a finite number above
/// zero, rounded to cents: `NaN`, `Infinity`, `0` and negatives would otherwise
/// be saved and later break totals and charts.
double? parseAmount(String? text) {
  final value = double.tryParse((text ?? '').trim());
  if (value == null || !value.isFinite || value > 1e12) return null;

  final cents = (value * 100).round() / 100;
  return cents > 0 ? cents : null;
}
