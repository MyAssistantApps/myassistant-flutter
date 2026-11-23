import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/home_layout.dart';

void main() {
  test('no saved order: the default order', () {
    expect(HomeLayout.normalise(null), HomeLayout.defaults);
  });

  test('a saved order is kept; unknown ids are dropped, duplicates removed', () {
    final out = HomeLayout.normalise(
        ['quick_tools', 'gone', 'assistant', 'quick_tools', ...HomeLayout.defaults]);
    expect(out.first, 'quick_tools');
    expect(out[1], 'assistant');
    expect(out.toSet().length, out.length);
    expect(out, isNot(contains('gone')));
    expect(out.length, HomeLayout.defaults.length);
  });

  test('a section added in a later release appears in its default place', () {
    final saved = List.of(HomeLayout.defaults)..remove('payment_apps');
    final out = HomeLayout.normalise(saved);
    expect(out, contains('payment_apps'));
    expect(out.indexOf('payment_apps'), HomeLayout.defaults.indexOf('payment_apps'));
  });

  test("a saved order from before Today's Horoscope was removed loses it", () {
    final out = HomeLayout.normalise([...HomeLayout.defaults, 'horoscope']);
    expect(out, isNot(contains('horoscope')));
    expect(out, HomeLayout.defaults);
  });

  test('every section has a title and an icon', () {
    for (final id in HomeLayout.defaults) {
      expect(HomeLayout.sections[id], isNotNull, reason: id);
    }
  });
}
