import 'package:cryptography/cryptography.dart';
import 'package:eco/core/crypto/field_cipher.dart';
import 'package:eco/features/collections/data/models/collection_mapper.dart';
import 'package:eco/features/collections/data/models/collection_model.dart';
import 'package:flutter_test/flutter_test.dart';

FieldCipher cipherOf(int seed) => FieldCipher(
  SecretKeyData(List<int>.generate(32, (i) => (i + seed) & 0xFF)),
);

void main() {
  CollectionModel build() => CollectionModel()
    ..name = 'Lisbon trip'
    ..color = 0xFF3B82F6
    ..icon = 'flight';

  test('encrypts only the name and round-trips', () {
    final cipher = cipherOf(1);
    final json = build().toJson('user-1', cipher: cipher);

    expect(json['name'], isNot('Lisbon trip'));
    expect(json['color'], 0xFF3B82F6);
    expect(json['icon'], 'flight');
    expect(json['user_id'], 'user-1');

    final back = CollectionMapper.fromJson({
      ...json,
      'id': 'c-1',
    }, cipher: cipher);
    expect(back.remoteId, 'c-1');
    expect(back.name, 'Lisbon trip');
    expect(back.color, 0xFF3B82F6);
  });

  test('without a cipher the name stays readable', () {
    final json = build().toJson('user-1');
    expect(json['name'], 'Lisbon trip');
    expect(
      CollectionMapper.fromJson({...json, 'id': 'c-1'}).name,
      'Lisbon trip',
    );
  });
}
