import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/quick_app_store.dart';
import 'package:myassistant/features/home/quick_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('saved edits are read defensively', () {
    test('a usable entry', () {
      final a = AddedApp.fromJson({'name': ' My Bank ', 'pkg': 'com.mybank.app'});
      expect(a?.name, 'My Bank');
      expect(a?.pkg, 'com.mybank.app');
    });

    test('junk is dropped, never thrown', () {
      expect(AddedApp.fromJson(null), isNull);
      expect(AddedApp.fromJson({'name': 'X'}), isNull);
      expect(AddedApp.fromJson({'name': '', 'pkg': 'com.a.b'}), isNull);
      expect(AddedApp.fromJson({'name': 'Bad', 'pkg': 'not a package'}), isNull);
      expect(QuickAppStore.decode('not json'), isEmpty);
      expect(QuickAppStore.decode('[1,2]'), isEmpty);
      final e = QuickAppStore.decode(
          '{"quick_apps":{"removed":["YouTube",3],"added":[{"name":"A","pkg":"com.a.b"},{"name":"A again","pkg":"com.a.b"},7]}}');
      expect(e['quick_apps']!.removed, {'YouTube'});
      expect(e['quick_apps']!.added.map((a) => a.name), ['A']);
    });

    test('edits round-trip through JSON', () {
      const e = SectionEdits(removed: {'Gmail'}, added: [AddedApp('Zomato', 'com.application.zomato')]);
      final back = SectionEdits.fromJson(e.toJson());
      expect(back.removed, {'Gmail'});
      expect(back.added.single.pkg, 'com.application.zomato');
    });
  });

  group('what a section shows', () {
    test('removed built-ins go; added apps follow, once', () {
      final e = SectionEdits.empty
          .withRemoved('YouTube')
          .withAdded(const AddedApp('Zomato', 'com.application.zomato'))
          .withAdded(const AddedApp('Zomato', 'com.application.zomato'))
          .withAdded(const AddedApp('WhatsApp copy', 'com.whatsapp'));
      final names = visibleApps(otherApps, e).map((a) => a.name).toList();
      expect(names, isNot(contains('YouTube')));
      expect(names.where((n) => n == 'Zomato').length, 1);
      expect(names.last, 'Zomato');
      // WhatsApp is already shown as a built-in: not drawn twice.
      expect(names, isNot(contains('WhatsApp copy')));
    });

    test('an added app can be removed again', () {
      final e = SectionEdits.empty
          .withAdded(const AddedApp('Zomato', 'com.application.zomato'))
          .withoutAdded('com.application.zomato');
      expect(visibleApps(otherApps, e).length, otherApps.length);
    });
  });

  group('the assistant finds an added app by name', () {
    const apps = [AddedApp('My Bank', 'com.mybank.app'), AddedApp('Zomato', 'com.application.zomato')];

    test('exact, ignoring case and spaces', () {
      expect(matchAddedApp('my bank', apps), 'com.mybank.app');
      expect(matchAddedApp('ZOMATO', apps), 'com.application.zomato');
    });

    test('a close name', () {
      expect(matchAddedApp('mybank app', apps), 'com.mybank.app');
    });

    test('nothing for an app they did not add', () {
      expect(matchAddedApp('Swiggy', apps), isNull);
      expect(matchAddedApp('', apps), isNull);
      expect(matchAddedApp('my', apps), isNull);
    });
  });

  test('the store saves and reloads on this phone', () async {
    SharedPreferences.setMockInitialValues({});
    final store = QuickAppStore.instance;
    await store.load();
    await store.add('quick_apps', const AddedApp('Zomato', 'com.application.zomato'));
    await store.removeBuiltIn('payment_apps', 'Paytm');
    expect(await store.pkgFor('zomato'), 'com.application.zomato');
    final prefs = await SharedPreferences.getInstance();
    final saved = QuickAppStore.decode(prefs.getString('quick_apps_edits_v1'));
    expect(saved['payment_apps']!.removed, {'Paytm'});
    await store.reset('quick_apps');
    expect(store.of('quick_apps').added, isEmpty);
  });
}
