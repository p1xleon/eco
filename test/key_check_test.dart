import 'package:cryptography/cryptography.dart';
import 'package:eco/core/crypto/field_cipher.dart';
import 'package:eco/core/crypto/key_check.dart';
import 'package:eco/core/crypto/recovery_phrase.dart';
import 'package:flutter_test/flutter_test.dart';

SecretKeyData keyOf(int seed) =>
    SecretKeyData(List<int>.generate(32, (i) => (i + seed) & 0xFF));

void main() {
  group('verifyKeyOpensServerData', () {
    final sample = FieldCipher(keyOf(1)).encrypt('Water bill');

    test('accepts the key that wrote the data', () async {
      await verifyKeyOpensServerData(
        candidate: keyOf(1),
        fetchSample: () async => sample,
      );
    });

    test('rejects a key that decodes fine but is wrong', () {
      expect(
        verifyKeyOpensServerData(
          candidate: keyOf(2),
          fetchSample: () async => sample,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'has nothing to check against when the server holds no ciphertext',
      () async {
        await verifyKeyOpensServerData(
          candidate: keyOf(2),
          fetchSample: () async => null,
        );
      },
    );
  });

  group('RecoveryPhrase', () {
    test('round-trips a key', () {
      final key = keyOf(7);
      final phrase = RecoveryPhrase.encode(key.bytes);

      expect(RecoveryPhrase.decode(phrase), key.bytes);
    });

    test('a changed last character is caught by the padding bits', () {
      final phrase = RecoveryPhrase.encode(keyOf(7).bytes);
      final broken = '${phrase.substring(0, phrase.length - 1)}1';

      expect(() => RecoveryPhrase.decode(broken), throwsFormatException);
    });
  });
}
