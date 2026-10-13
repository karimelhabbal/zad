import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zad/data/models/azkar_models.dart';
import 'package:zad/data/repositories/local_store.dart';
import 'package:zad/data/repositories/tasbeeh_repository.dart';
import 'package:zad/state/tasbeeh_controller.dart';

/// The digital tasbeeh: validation, CRUD, counter isolation and persistence.
///
/// The spec requires that editing or deleting one dhikr never resets an
/// unrelated counter, and that everything survives a restart — both are
/// covered here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TasbeehController controller;

  const tasbeehCategory = ZikrCategory(
    id: 'tasbeeh',
    icon: 'beads',
    title: LocalizedText(ar: 'التسابيح', en: 'Tasbeeh'),
    subtitle: LocalizedText(ar: 'أذكار مطلقة', en: 'Unrestricted adhkar'),
    items: <ZikrItem>[
      ZikrItem(id: 'subhan', text: 'سُبْحَانَ اللَّهِ', count: 33),
      ZikrItem(id: 'hamd', text: 'الْحَمْدُ لِلَّهِ', count: 100),
    ],
  );

  Future<TasbeehController> freshController({bool initialise = true}) async {
    LocalStore.overrideInstance(null);
    final store = await LocalStore.instance();
    final created = TasbeehController(TasbeehRepository(store));
    if (initialise) {
      await created.initialise(<ZikrCategory>[tasbeehCategory]);
    }
    return created;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    controller = await freshController();
  });

  group('validation', () {
    test('rejects an empty text', () {
      expect(
        controller.validate(text: '   ', target: 33),
        'tasbeeh.errorEmptyText',
      );
    });

    test('rejects a non-positive target', () {
      expect(controller.validate(text: 'ذكر', target: 0), 'tasbeeh.errorTarget');
      expect(controller.validate(text: 'ذكر', target: -1), 'tasbeeh.errorTarget');
      expect(controller.validate(text: 'ذكر', target: null), 'tasbeeh.errorTarget');
    });

    test('rejects an absurdly large target', () {
      expect(
        controller.validate(text: 'ذكر', target: 200000),
        'tasbeeh.errorTargetTooLarge',
      );
    });

    test('accepts the documented presets and a user-defined value', () {
      expect(controller.validate(text: 'ذكر', target: 33), isNull);
      expect(controller.validate(text: 'ذكر', target: 100), isNull);
      expect(controller.validate(text: 'ذكر', target: 7), isNull);
    });

    test('preset targets match the design', () {
      expect(TasbeehController.presetTargets, <int>[33, 100]);
    });
  });

  group('built-in adhkar', () {
    test('are extracted from the tasbeeh category', () {
      expect(controller.builtIn.length, 2);
      expect(controller.builtIn.first.id, 'subhan');
      expect(controller.builtIn.first.target, 33);
      expect(controller.active?.storageId, 'builtin:subhan');
    });

    test('a target override does not alter the documented count', () async {
      final dhikr = controller.active!;
      expect(controller.targetFor(dhikr), 33);

      await controller.setTargetFor(dhikr, 100);
      expect(controller.targetFor(dhikr), 100);
      expect(dhikr.target, 33, reason: 'the asset count is untouched');

      await controller.setTargetFor(dhikr, 0);
      expect(controller.targetFor(dhikr), 0, reason: '0 means unlimited');
    });
  });

  group('counting', () {
    test('increments and reports when the target is reached', () async {
      final dhikr = controller.active!;
      await controller.setTargetFor(dhikr, 3);

      expect(await controller.increment(), isFalse);
      expect(await controller.increment(), isFalse);
      expect(await controller.increment(), isTrue);

      expect(controller.activeCount, 3);
      expect(controller.activeLaps, 1);
      expect(controller.activeProgress, 1.0);
      expect(controller.totalToday, 3);
      expect(controller.totalAllTime, 3);
    });

    test('unlimited counting never reports completion', () async {
      final dhikr = controller.active!;
      await controller.setTargetFor(dhikr, 0);
      for (var i = 0; i < 5; i++) {
        expect(await controller.increment(), isFalse);
      }
      expect(controller.activeCount, 5);
      expect(controller.activeLaps, 0);
      expect(controller.activeProgress, 0);
    });
  });

  group('custom dhikr CRUD', () {
    test('create validates, stores and selects the new entry', () async {
      expect(
        await controller.addCustom(text: '', target: 33),
        'tasbeeh.errorEmptyText',
      );
      expect(controller.custom, isEmpty);

      expect(await controller.addCustom(text: '  أستغفر الله  ', target: 33), isNull);
      expect(controller.custom.length, 1);
      expect(controller.custom.first.text, 'أستغفر الله');
      expect(controller.custom.first.target, 33);
      expect(controller.active?.isCustom, isTrue);
    });

    test('update keeps the entry identity and its counter', () async {
      await controller.addCustom(text: 'ذكر أ', target: 33);
      final id = controller.custom.first.id;
      await controller.increment();
      expect(controller.countForStorageId('custom:$id'), 1);

      expect(
        await controller.updateCustom(id: id, text: 'ذكر ب', target: 100),
        isNull,
      );
      expect(controller.custom.single.text, 'ذكر ب');
      expect(controller.custom.single.target, 100);
      expect(controller.countForStorageId('custom:$id'), 1);
    });

    test('update rejects invalid input without changing anything', () async {
      await controller.addCustom(text: 'ذكر أ', target: 33);
      final id = controller.custom.first.id;
      expect(
        await controller.updateCustom(id: id, text: '', target: 33),
        'tasbeeh.errorEmptyText',
      );
      expect(controller.custom.single.text, 'ذكر أ');
    });
  });

  group('counter isolation', () {
    test('counting one dhikr never touches another', () async {
      await controller.addCustom(text: 'الأول', target: 33);
      final firstId = controller.custom.first.id;
      await controller.increment();
      await controller.increment();

      await controller.addCustom(text: 'الثاني', target: 100);
      final secondId = controller.custom.last.id;
      expect(controller.active?.id, secondId);

      await controller.increment();

      expect(controller.countForStorageId('custom:$firstId'), 2);
      expect(controller.countForStorageId('custom:$secondId'), 1);
      expect(controller.countForStorageId('builtin:subhan'), 0);
    });

    test('resetting the active counter leaves the others intact', () async {
      await controller.addCustom(text: 'الأول', target: 33);
      final firstId = controller.custom.first.id;
      await controller.increment();
      await controller.increment();

      await controller.addCustom(text: 'الثاني', target: 100);
      final secondId = controller.custom.last.id;
      await controller.increment();

      await controller.resetActiveCounter();

      expect(controller.countForStorageId('custom:$secondId'), 0);
      expect(controller.countForStorageId('custom:$firstId'), 2);
      expect(controller.totalToday, 2, reason: 'stats only lose the reset amount');
    });

    test('deleting one dhikr removes only its own counter', () async {
      await controller.addCustom(text: 'الأول', target: 33);
      final firstId = controller.custom.first.id;
      await controller.increment();

      await controller.addCustom(text: 'الثاني', target: 100);
      final secondId = controller.custom.last.id;
      await controller.increment();
      await controller.increment();

      await controller.deleteCustom(firstId);

      expect(controller.custom.length, 1);
      expect(controller.custom.single.id, secondId);
      expect(controller.countForStorageId('custom:$firstId'), 0);
      expect(controller.countForStorageId('custom:$secondId'), 2);
    });

    test('deleting the active dhikr re-points the selection safely', () async {
      await controller.addCustom(text: 'الأول', target: 33);
      final id = controller.custom.first.id;
      await controller.deleteCustom(id);
      expect(controller.active, isNotNull);
      expect(controller.active!.storageId, isNot('custom:$id'));
    });
  });

  group('persistence', () {
    test('custom adhkar, counters and stats survive a restart', () async {
      await controller.addCustom(text: 'ذكر محفوظ', target: 33);
      final id = controller.custom.first.id;
      await controller.increment();
      await controller.increment();
      await controller.selectDhikr('builtin:hamd');
      await controller.increment();

      // Simulate a restart with the same on-device storage.
      final restored = await freshController();

      expect(restored.custom.length, 1);
      expect(restored.custom.first.text, 'ذكر محفوظ');
      expect(restored.countForStorageId('custom:$id'), 2);
      expect(restored.countForStorageId('builtin:hamd'), 1);
      expect(restored.totalToday, 3);
      expect(restored.totalAllTime, 3);
      expect(restored.active?.storageId, 'builtin:hamd');
    });

    test('a corrupt custom-dhikr record does not wipe the valid ones', () async {
      await controller.addCustom(text: 'صحيح', target: 33);

      // Inject a malformed record alongside the valid one.
      final store = await LocalStore.instance();
      final raw = store.getJsonList(LocalStore.keyCustomDhikr)!;
      raw.add(<String, dynamic>{'id': 'broken', 'text': '', 'target': 0});
      await store.setJson(LocalStore.keyCustomDhikr, raw);

      final restored = await freshController();
      expect(restored.custom.length, 1);
      expect(restored.custom.single.text, 'صحيح');
    });
  });

  group('reloadPersisted', () {
    test('clears the counters after a full data reset', () async {
      await controller.addCustom(text: 'ذكر', target: 33);
      await controller.increment();
      expect(controller.totalToday, 1);

      final store = await LocalStore.instance();
      await store.clearAppData();
      await controller.reloadPersisted();

      expect(controller.custom, isEmpty);
      expect(controller.activeCount, 0);
      expect(controller.totalToday, 0);
      expect(controller.totalAllTime, 0);
    });
  });
}
