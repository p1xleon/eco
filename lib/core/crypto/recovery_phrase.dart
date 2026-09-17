import 'dart:typed_data';

/// Encodes the data key as something a person can write on paper and type back.
///
/// Crockford's base32 rather than a word list: it needs no 2048-word asset, and
/// its alphabet drops the characters that get misread by hand — there is no
/// `I`, `L`, `O` or `U`, and [decode] folds the look-alikes (`I`/`L` to `1`,
/// `O` to `0`) back on input. 32 key bytes become 52 characters, grouped in
/// fours for transcription.
///
/// The phrase *is* the key, not a passphrase that unlocks one. There is nothing
/// to brute force and nothing on a server to attack; equally, there is no reset.
class RecoveryPhrase {
  const RecoveryPhrase._();

  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const _groupSize = 4;

  static String encode(List<int> bytes) {
    final buffer = StringBuffer();
    var bits = 0;
    var value = 0;

    for (final byte in bytes) {
      value = (value << 8) | byte;
      bits += 8;

      while (bits >= 5) {
        buffer.write(_alphabet[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }

    // Trailing bits are left-aligned into a final character, so the last group
    // is not silently dropped.
    if (bits > 0) {
      buffer.write(_alphabet[(value << (5 - bits)) & 31]);
    }

    return _group(buffer.toString());
  }

  static Uint8List decode(String phrase) {
    final normalized = phrase
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0');

    final bytes = <int>[];
    var bits = 0;
    var value = 0;

    for (final character in normalized.split('')) {
      final index = _alphabet.indexOf(character);
      if (index < 0) {
        throw FormatException('Not a valid recovery phrase character', character);
      }

      value = (value << 5) | index;
      bits += 5;

      if (bits >= 8) {
        bytes.add((value >> (bits - 8)) & 0xFF);
        bits -= 8;
      }
    }

    return Uint8List.fromList(bytes);
  }

  static String _group(String raw) {
    final groups = <String>[];

    for (var i = 0; i < raw.length; i += _groupSize) {
      groups.add(
        raw.substring(i, i + _groupSize > raw.length ? raw.length : i + _groupSize),
      );
    }

    return groups.join('-');
  }
}
