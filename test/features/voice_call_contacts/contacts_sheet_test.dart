import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myassistant/features/voice_call_contacts/contact_import.dart';
import 'package:myassistant/features/voice_call_contacts/contacts_screen.dart';
import 'package:myassistant/features/voice_call_contacts/voice_call_contacts.dart';
import 'package:myassistant/features/voice_call_contacts/voice_call_contacts_db.dart';

/// The contact sheet end to end: open a person, then add, change and
/// remove an alias by touch, and see each one saved and shown.
void main() {
  testWidgets('aliases can be added, changed and removed on the sheet',
      (tester) async {
    final db = VoiceCallContactsDb(NativeDatabase.memory());
    await tester.runAsync(() => SyncDeviceContactsToLocal(db).run(const [
          RawContact(name: 'Allen Lobo', phones: [('7349183105', 'mobile')]),
        ]));
    VoiceCallContacts.instance.debugUseDb(db);

    // Lets the database's real async work finish between frames. Fixed
    // pumps, not pumpAndSettle: the list page keeps a live stream open.
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<List<String>> custom() async {
      final rows = await tester.runAsync(() => db.select(db.personAliases).get());
      return [
        for (final a in rows!)
          if (a.origin == originUserCustom) a.alias
      ];
    }

    Finder dialogField() => find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));

    await tester.pumpWidget(const MaterialApp(home: ContactsScreen()));
    await settle();
    await tester.tap(find.text('Allen Lobo').first);
    await settle();

    // ADD — tapping the label under the circle (it did nothing before).
    await tester.tap(find.text('Add Alias'));
    await settle();
    expect(dialogField(), findsOneWidget, reason: 'the dialog should open');
    await tester.enterText(dialogField(), 'Papa');
    await tester.tap(find.text('Save'));
    await settle();
    expect(tester.takeException(), isNull);
    expect(await custom(), ['Papa']);
    expect(find.text('Papa'), findsOneWidget);
    expect(find.text('Alias you added'), findsOneWidget);

    // CHANGE
    await tester.tap(find.byTooltip('Change Alias'));
    await settle();
    await tester.enterText(dialogField(), 'Dad');
    await tester.tap(find.text('Save'));
    await settle();
    expect(tester.takeException(), isNull);
    expect(await custom(), ['Dad']);
    expect(find.text('Dad'), findsOneWidget);
    expect(find.text('Papa'), findsNothing);

    // REMOVE
    await tester.tap(find.byTooltip('Remove Alias'));
    await settle();
    expect(await custom(), isEmpty);
    expect(find.text('Dad'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => VoiceCallContacts.instance.dispose());
  });

  testWidgets('a request from the assistant opens the card and adds the alias',
      (tester) async {
    // Imported already: resolving the name must not read the phone.
    SharedPreferences.setMockInitialValues({'vcc_initial_import_done': true});
    final db = VoiceCallContactsDb(NativeDatabase.memory());
    await tester.runAsync(() => SyncDeviceContactsToLocal(db).run(const [
          RawContact(name: 'Allen Lobo', phones: [('7349183105', 'mobile')]),
          RawContact(name: 'Rohan Kulkarni', phones: [('9845012345', 'mobile')]),
        ]));
    VoiceCallContacts.instance.debugUseDb(db);

    Future<void> settle() async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(const MaterialApp(
        home: ContactsScreen(
            request: ContactsRequest(
                contact: 'Allen',
                action: ContactAction.addAlias,
                alias: 'Papa'))));
    await settle();

    final rows = await tester.runAsync(() => db.select(db.personAliases).get());
    expect(
        [for (final a in rows!) if (a.origin == originUserCustom) a.alias],
        ['Papa']);
    // Allen's card is open, showing the result and the new alias.
    expect(find.text('Also Known As'), findsOneWidget);
    expect(find.text('"Papa" now reaches Allen Lobo.'), findsOneWidget);
    expect(find.text('Alias you added'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => VoiceCallContacts.instance.dispose());
  });
}
