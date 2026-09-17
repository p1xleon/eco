import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'recovery_phrase.dart';

/// Holds the single key everything on the server is encrypted with.
///
/// The key never leaves the device except as a [RecoveryPhrase] the user writes
/// down. It is not derived from the login password, so a password reset does
/// not invalidate a single row.
///
/// Default [AndroidOptions] already back the store with the Android Keystore
/// (AES-GCM under an RSA-wrapped key), so no extra configuration is needed.
class DataKeyStore {
  DataKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'eco.data_key.v1';
  static const keyLengthBytes = 32;

  final FlutterSecureStorage _storage;

  /// The key, or null when encryption has not been set up on this device.
  Future<SecretKeyData?> load() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored == null) return null;

    return SecretKeyData(base64.decode(stored));
  }

  Future<bool> get exists async =>
      await _storage.read(key: _storageKey) != null;

  /// Creates a key for a device that has never had one, and persists it.
  ///
  /// Uses [Random.secure]; a key from a predictable generator would be no key
  /// at all.
  Future<SecretKeyData> create() async {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(keyLengthBytes, (_) => random.nextInt(256)),
    );

    await _persist(bytes);

    return SecretKeyData(bytes);
  }

  /// Restores the key on a new device from the phrase shown at setup.
  ///
  /// Throws [FormatException] if the phrase is malformed or the wrong length —
  /// worth surfacing, because the alternative is a key that decrypts nothing
  /// and looks like data corruption.
  Future<SecretKeyData> restoreFromPhrase(String phrase) async {
    final bytes = RecoveryPhrase.decode(phrase);

    if (bytes.length != keyLengthBytes) {
      throw FormatException(
        'A recovery phrase holds $keyLengthBytes bytes, this one holds '
        '${bytes.length}',
      );
    }

    await _persist(bytes);

    return SecretKeyData(bytes);
  }

  String phraseFor(SecretKeyData key) => RecoveryPhrase.encode(key.bytes);

  /// Forgets the key on this device. The server copy stays encrypted, so this
  /// is only safe when the phrase has been written down.
  Future<void> clear() => _storage.delete(key: _storageKey);

  Future<void> _persist(List<int> bytes) =>
      _storage.write(key: _storageKey, value: base64.encode(bytes));
}
