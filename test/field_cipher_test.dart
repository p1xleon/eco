import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:eco/core/crypto/field_cipher.dart';
import 'package:eco/core/crypto/recovery_phrase.dart';
import 'package:flutter_test/flutter_test.dart';

SecretKeyData keyOf(int seed) =>
    SecretKeyData(List<int>.generate(32, (i) => (i + seed) & 0xFF));

void main() {
  group('FieldCipher', () {
    late FieldCipher cipher;

    setUp(() => cipher = FieldCipher(keyOf(1)));

    test('round-trips a value', () {
      final encrypted = cipher.encrypt('Water bill');

      expect(encrypted, startsWith(FieldCipher.versionPrefix));
      expect(encrypted, isNot(contains('Water')));
      expect(cipher.decrypt(encrypted), 'Water bill');
    });

    test('uses a fresh nonce, so equal values differ on the server', () {
      expect(cipher.encrypt('Rent'), isNot(cipher.encrypt('Rent')));
    });

    test('passes through a value written before encryption existed', () {
      expect(cipher.decrypt('Rent'), 'Rent');
    });

    test('round-trips amounts through a text column', () {
      final encrypted = cipher.encryptNumber(1234.56);

      expect(cipher.decryptNumber(encrypted), 1234.56);
      expect(cipher.encryptNumber(null), isNull);
      expect(cipher.decryptNumber(null), isNull);
    });

    test('rejects a tampered ciphertext instead of returning garbage', () {
      final packed = base64.decode(
        cipher.encrypt('Rent').substring(FieldCipher.versionPrefix.length),
      );
      packed[packed.length - 1] ^= 0xFF;

      expect(
        () => cipher.decrypt(
          '${FieldCipher.versionPrefix}${base64.encode(packed)}',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('rejects the wrong key', () {
      final encrypted = cipher.encrypt('Rent');

      expect(
        () => FieldCipher(keyOf(2)).decrypt(encrypted),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('RecoveryPhrase', () {
    test('round-trips a key', () {
      final bytes = List<int>.generate(32, (i) => (i * 7) & 0xFF);

      expect(RecoveryPhrase.decode(RecoveryPhrase.encode(bytes)), bytes);
    });

    test('is grouped for transcription', () {
      final phrase = RecoveryPhrase.encode(List<int>.filled(32, 0));

      expect(phrase, contains('-'));
      expect(phrase.replaceAll('-', '').length, 52);
    });

    test('forgives the characters people misread', () {
      final phrase = RecoveryPhrase.encode(List<int>.generate(32, (i) => i));
      final retyped = phrase.toLowerCase().replaceAll('1', 'l');

      expect(RecoveryPhrase.decode(retyped), RecoveryPhrase.decode(phrase));
    });

    test('rejects a character outside the alphabet', () {
      expect(() => RecoveryPhrase.decode('ZZZZ-ZZZU!'), throwsFormatException);
    });
  });
}
