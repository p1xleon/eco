/// Identifies "the same transaction" for duplicate checks: same day, same
/// amount to the cent, same title. Used by import and bulk add so the two cannot
/// disagree about what a duplicate is.
String transactionFingerprint({
  required DateTime date,
  required double amount,
  required String title,
}) {
  return '${date.year}-${date.month}-${date.day}'
      '|${(amount * 100).round()}'
      '|${title.trim().toLowerCase()}';
}
