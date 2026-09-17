import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// AES-GCM-256 over individual field values, on the way to and from the server.
///
/// Values carry a `v1:` prefix so a reader can tell ciphertext from a value
/// written before encryption existed. [decrypt] passes anything unprefixed
/// through unchanged, which is what lets rows migrate one at a time instead of
/// needing a flag day.
///
/// The synchronous pure-Dart implementation is deliberate: the mappers this
/// runs inside (`transaction_mapper.dart` and friends) are synchronous and are
/// called from the repositories on every read and write. Making them async
/// would ripple through the whole sync engine to buy nothing — these are short
/// strings, not bulk data.
class FieldCipher {
  FieldCipher(this._key);

  /// Marks a value as encrypted, and identifies the scheme that produced it.
  /// Any future change to the format gets its own prefix rather than silently
  /// reinterpreting old bytes.
  static const versionPrefix = 'v1:';

  static final _algorithm = DartAesGcm.with256bits();

  final SecretKeyData _key;

  /// True when [value] was written by this class rather than left as plaintext.
  static bool isEncrypted(String value) => value.startsWith(versionPrefix);

  String encrypt(String plainText) {
    final box = _algorithm.encryptSync(
      utf8.encode(plainText),
      secretKeyData: _key,
    );

    // nonce | ciphertext | mac, so the whole thing travels as one column value.
    final packed = Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);

    return '$versionPrefix${base64.encode(packed)}';
  }

  /// Returns the plaintext of [value], or [value] itself if it was never
  /// encrypted.
  ///
  /// Throws [SecretBoxAuthenticationError] if the ciphertext was tampered with
  /// or the key is wrong. That is deliberately not caught here: silently
  /// returning a corrupted value would let bad data reach the local database.
  String decrypt(String value) {
    if (!isEncrypted(value)) return value;

    final packed = base64.decode(value.substring(versionPrefix.length));
    final nonceLength = _algorithm.nonceLength;
    final macLength = _algorithm.macAlgorithm.macLength;

    final box = SecretBox(
      packed.sublist(nonceLength, packed.length - macLength),
      nonce: packed.sublist(0, nonceLength),
      mac: Mac(packed.sublist(packed.length - macLength)),
    );

    return utf8.decode(_algorithm.decryptSync(box, secretKeyData: _key));
  }

  String? encryptNullable(String? plainText) =>
      plainText == null ? null : encrypt(plainText);

  String? decryptNullable(String? value) =>
      value == null ? null : decrypt(value);

  /// Amounts are numbers locally but ciphertext on the server, so they move
  /// through a text column. See the `amount_enc` migration.
  String? encryptNumber(num? value) =>
      value == null ? null : encrypt(value.toString());

  double? decryptNumber(String? value) {
    if (value == null) return null;

    return double.parse(decrypt(value));
  }

  /// Reads a server value that may or may not be encrypted.
  ///
  /// [cipher] is null before the user sets up a key. A plaintext value still
  /// reads fine in that state — that is what keeps an un-migrated install
  /// working — but ciphertext throws rather than being stored raw. Writing
  /// `v1:…` into the local database would look like a title until it was
  /// pushed back and encrypted a second time.
  static String? readString(FieldCipher? cipher, Object? raw) {
    if (raw == null) return null;

    final value = raw as String;
    if (!isEncrypted(value)) return value;

    if (cipher == null) {
      throw StateError(
        'This data is encrypted and no key is set up on this device. '
        'Enter your recovery phrase in Settings → Encryption.',
      );
    }

    return cipher.decrypt(value);
  }

  /// Reads an amount from either the legacy numeric column or its encrypted
  /// text counterpart. See the `amount_enc` migration.
  static double? readNumber(FieldCipher? cipher, Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();

    final value = readString(cipher, raw);

    return value == null ? null : double.parse(value);
  }
}
