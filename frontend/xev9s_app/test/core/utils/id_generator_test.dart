import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:xev9s_app/core/utils/id_generator.dart';

void main() {
  group('UuidV4IdGenerator', () {
    test('generates valid UUID v4 shape (8-4-4-4-12 hex)', () {
      final generator = UuidV4IdGenerator();
      final id = generator.generate();

      final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidRegex.hasMatch(id), isTrue,
          reason: '$id does not match RFC 4122 v4 pattern');
    });

    test('generates unique ids on consecutive calls', () {
      final generator = UuidV4IdGenerator();
      final ids = List.generate(100, (_) => generator.generate()).toSet();
      expect(ids.length, 100);
    });

    test('accepts seeded Random instance for deterministic testing', () {
      final gen1 = UuidV4IdGenerator(Random(42));
      final gen2 = UuidV4IdGenerator(Random(42));

      expect(gen1.generate(), gen2.generate());
    });
  });
}
