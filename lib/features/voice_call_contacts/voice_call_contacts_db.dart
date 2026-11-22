import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'name_collision_indexer.dart';

part 'voice_call_contacts_db.g.dart';

/// VOICE-CALL CONTACTS (2026-11-22): the phone's address book, reduced to
/// one row per real person, kept ONLY in this SQLite file on the handset.
/// Nothing here is ever sent to the server.

/// One real person. Several address-book entries that share a number
/// ("Rohan", "Dad") collapse into one row; [mergedCount] says how many.
class CanonicalPersons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get primaryName => text()();

  /// What the UI and the "which one?" question show: [primaryName], or
  /// "Lobo 1" / "Lobo 2" when several people (different numbers) share the
  /// name. Null only until the first import after the column was added.
  TextColumn get displayLabel => text().nullable()();
  IntColumn get mergedCount => integer().withDefault(const Constant(1))();
  IntColumn get callCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastCalledAt => dateTime().nullable()();
}

/// A number that reaches a person, normalised to E.164 (+91 by default).
class PersonPhones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer()
      .references(CanonicalPersons, #id, onDelete: KeyAction.cascade)();
  TextColumn get e164 => text().unique()();
  TextColumn get label => text()();
  BoolColumn get isPrimary => boolean()();
}

/// A name the user might say for a person: the saved name, its first
/// word, a nickname, a family word, or one the user added in the app.
@DataClassName('PersonAlias')
@TableIndex(name: 'person_aliases_normalized', columns: {#normalizedAlias})
class PersonAliases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get personId => integer()
      .references(CanonicalPersons, #id, onDelete: KeyAction.cascade)();
  TextColumn get alias => text()();
  TextColumn get normalizedAlias => text()();

  /// 'device_import' (replaced on every import) or 'user_custom' (kept).
  TextColumn get origin => text()();
  RealColumn get weight => real().withDefault(const Constant(1.0))();
}

const originDeviceImport = 'device_import';
const originUserCustom = 'user_custom';

extension CanonicalPersonLabel on CanonicalPerson {
  /// The name to show for this person ("Lobo 1"), never null.
  String get label => displayLabel ?? primaryName;
}

@DriftDatabase(tables: [CanonicalPersons, PersonPhones, PersonAliases])
class VoiceCallContactsDb extends _$VoiceCallContactsDb {
  /// [executor] lets tests pass `NativeDatabase.memory()`.
  VoiceCallContactsDb([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'voice_call_contacts'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(canonicalPersons, canonicalPersons.displayLabel);
            // Label the people already stored, without waiting for a sync.
            await NameCollisionIndexer(this).run();
          }
        },
        beforeOpen: (_) async {
          // SQLite ignores foreign keys (and so the cascades) unless asked.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
