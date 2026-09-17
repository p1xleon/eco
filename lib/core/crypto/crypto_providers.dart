import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data_key_store.dart';
import 'field_cipher.dart';

final dataKeyStoreProvider = Provider<DataKeyStore>((ref) => DataKeyStore());

/// The loaded data key, or null when this device has not set up encryption yet.
///
/// Seeded in `main()` from secure storage, the same way the theme and
/// visibility settings are, so the first frame already knows whether to show
/// the setup gate.
final dataKeyProvider = StateNotifierProvider<DataKeyNotifier, SecretKeyData?>(
  (ref) => DataKeyNotifier(null, ref.read(dataKeyStoreProvider)),
);

class DataKeyNotifier extends StateNotifier<SecretKeyData?> {
  DataKeyNotifier(super.initial, this._store);

  final DataKeyStore _store;

  bool get hasKey => state != null;

  /// Generates this device's key and returns the phrase to write down.
  Future<String> create() async {
    final key = await _store.create();
    state = key;

    return _store.phraseFor(key);
  }

  Future<void> restoreFromPhrase(String phrase) async {
    state = await _store.restoreFromPhrase(phrase);
  }

  String? get recoveryPhrase {
    final key = state;

    return key == null ? null : _store.phraseFor(key);
  }

  /// Forgets the key on this device, for the recovery drill.
  Future<void> forget() async {
    await _store.clear();
    state = null;
  }
}

/// The cipher, or null until a key exists.
///
/// Null is meaningful rather than an error: before setup there is nothing to
/// encrypt with, and the callers — backups and the mappers — are expected to
/// say so plainly rather than write plaintext as a fallback.
final fieldCipherProvider = Provider<FieldCipher?>((ref) {
  final key = ref.watch(dataKeyProvider);

  return key == null ? null : FieldCipher(key);
});
