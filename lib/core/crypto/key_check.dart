import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/remote_call.dart';
import 'field_cipher.dart';

/// An encrypted value from the signed-in account, or null when the server holds
/// none yet. Titles come first, then category names.
Future<String?> fetchEncryptedSample(SupabaseClient client) async {
  for (final (table, column) in const [
    ('transactions', 'title'),
    ('categories', 'name'),
  ]) {
    final rows = await remoteCall(
      () async => await client
          .from(table)
          .select(column)
          .like(column, '${FieldCipher.versionPrefix}%')
          .limit(1),
    );
    if (rows.isNotEmpty) return rows.first[column] as String?;
  }

  return null;
}

/// Throws [FormatException] unless [candidate] opens what is on the server.
///
/// A recovery phrase has no checksum, so one wrong character still decodes to a
/// valid key. Saving it would make every row unreadable and let later edits be
/// written under the wrong key, so a real ciphertext is tried first. With
/// nothing encrypted on the server there is nothing to check against.
Future<void> verifyKeyOpensServerData({
  required SecretKeyData candidate,
  required Future<String?> Function() fetchSample,
}) async {
  final sample = await fetchSample();
  if (sample == null) return;

  try {
    FieldCipher(candidate).decrypt(sample);
  } catch (_) {
    throw const FormatException(
      'This phrase does not open the data on your account. '
      'Check it for a typo and try again.',
    );
  }
}
