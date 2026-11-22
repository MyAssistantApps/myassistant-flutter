import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../ai/listen.dart' show SpeechToTextRecognizer;
import '../../ai/model_port.dart';
import '../../ai/speech.dart';
import '../../core/log.dart';
import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/audio/pcm_player.dart';
import '../../services/call_service.dart';
import 'voice_call_contacts.dart';
import 'voice_call_contacts_db.dart';

/// The names that reach a person besides the one shown: every saved name
/// and custom alias, without the shown name and without repeats.
List<String> otherNames(String primaryName, Iterable<String> aliases) {
  String key(String s) => s.trim().toLowerCase();
  final seen = <String>{key(primaryName)};
  return [
    for (final a in aliases)
      if (a.trim().isNotEmpty && seen.add(key(a))) a.trim(),
  ];
}

/// True when [name] has no letters: a number saved without a name.
bool isNameless(String name) => !RegExp(r'\p{L}', unicode: true).hasMatch(name);

/// The section a name is listed under: its first letter A–Z, or '#' for
/// numbers saved without a name and names that start with anything else.
String sectionOf(String name) {
  final t = name.trim();
  if (t.isEmpty || isNameless(t)) return '#';
  final c = t.characters.first.toUpperCase();
  return RegExp(r'^[A-Z]$').hasMatch(c) ? c : '#';
}

/// [names] grouped by [sectionOf], A–Z first and '#' last, each section
/// in alphabetical order. Returns the indexes into [names].
List<(String, List<int>)> sectionsOf(List<String> names) {
  final by = <String, List<int>>{};
  for (var i = 0; i < names.length; i++) {
    by.putIfAbsent(sectionOf(names[i]), () => []).add(i);
  }
  final keys = by.keys.toList()
    ..sort((a, b) => a == '#'
        ? 1
        : b == '#'
            ? -1
            : a.compareTo(b));
  return [
    for (final k in keys)
      (
        k,
        by[k]!
          ..sort((a, b) => names[a]
              .trim()
              .toLowerCase()
              .compareTo(names[b].trim().toLowerCase()))
      ),
  ];
}

/// What to do with one contact: from the Contacts mic, or from the main
/// assistant (open_app_screen with screen 'contacts').
enum ContactAction { show, call, addAlias, changeAlias, removeAlias }

class ContactsRequest {
  const ContactsRequest({
    this.contact = '',
    this.personId,
    this.action = ContactAction.show,
    this.alias = '',
    this.newAlias = '',
  });

  /// The name as it was said; resolved against the phone's contacts.
  final String contact;

  /// A person already known (a call the assistant just placed).
  final int? personId;
  final ContactAction action;
  final String alias;
  final String newAlias;

  /// The server's open_app_screen fields → a request, or null without a
  /// contact (just open the list).
  static ContactsRequest? fromAction(Map<String, dynamic> e) {
    final contact = (e['contact'] ?? '').toString().trim();
    if (contact.isEmpty) return null;
    final action = switch ((e['contact_action'] ?? '').toString()) {
      'add_alias' => ContactAction.addAlias,
      'change_alias' => ContactAction.changeAlias,
      'remove_alias' => ContactAction.removeAlias,
      'call' => ContactAction.call,
      _ => ContactAction.show,
    };
    return ContactsRequest(
      contact: contact,
      action: action,
      alias: (e['alias'] ?? '').toString().trim(),
      newAlias: (e['new_alias'] ?? '').toString().trim(),
    );
  }
}

/// What was said to the Contacts mic, with the contact it is about:
/// "Give alias Papa to Allen", "Call Rohan", "Change Allen's alias Papa to
/// Dad", "Remove alias Boss from Rohan", "Open Allen" — or null.
ContactsRequest? parseContactsCommand(String words) {
  var t = words.trim().replaceAll(RegExp(r'[.!?]+$'), '').trim();
  t = t.replaceFirst(
      RegExp(r'^(please|okay|ok|hey)\s+', caseSensitive: false), '');
  if (t.isEmpty) return null;
  String clean(String s) => s
      .trim()
      .replaceAll(RegExp(r'''^["'“”]+|["'“”]+$'''), '')
      .replaceAll(RegExp(r"'s$"), '')
      .replaceAll(RegExp(r'\s+(?:contact|please|now)$', caseSensitive: false), '')
      .trim();
  RegExpMatch? m(String re) => RegExp(re, caseSensitive: false).firstMatch(t);
  const alias = r'(?:alias|nickname|name)';

  // Change: "change Allen's alias Papa to Dad" / "change alias Papa of
  // Allen to Dad".
  var x = m(r"^(?:change|rename|edit|replace)\s+(.+?)'s\s+" + alias +
      r'\s+(.+?)\s+(?:to|as|with|into)\s+(.+)$');
  if (x != null) {
    return ContactsRequest(
        contact: clean(x[1]!),
        action: ContactAction.changeAlias,
        alias: clean(x[2]!),
        newAlias: clean(x[3]!));
  }
  x = m(r'^(?:change|rename|edit|replace)\s+(?:the\s+)?' + alias +
      r'\s+(.+?)\s+(?:of|for|from|on)\s+(.+?)\s+(?:to|as|with|into)\s+(.+)$');
  if (x != null) {
    return ContactsRequest(
        contact: clean(x[2]!),
        action: ContactAction.changeAlias,
        alias: clean(x[1]!),
        newAlias: clean(x[3]!));
  }
  // Remove: "remove alias Boss from Rohan" / "remove Rohan's alias Boss".
  x = m(r'^(?:remove|delete)\s+(?:the\s+)?' + alias +
      r'\s+(.+?)\s+(?:from|of|for|on)\s+(.+)$');
  if (x != null) {
    return ContactsRequest(
        contact: clean(x[2]!),
        action: ContactAction.removeAlias,
        alias: clean(x[1]!));
  }
  x = m(r"^(?:remove|delete)\s+(.+?)'s\s+" + alias + r'\s+(.+)$');
  if (x != null) {
    return ContactsRequest(
        contact: clean(x[1]!),
        action: ContactAction.removeAlias,
        alias: clean(x[2]!));
  }
  // Add: "give alias Papa to Allen" / "add the name Boss for Rohan" /
  // "save Allen as Papa".
  x = m(r'^(?:give|add|set|save|assign)\s+(?:the\s+|an?\s+)?(?:new\s+)?' +
      alias + r'\s+(.+?)\s+(?:to|for|on)\s+(.+)$');
  if (x != null) {
    return ContactsRequest(
        contact: clean(x[2]!),
        action: ContactAction.addAlias,
        alias: clean(x[1]!));
  }
  x = m(r'^(?:save|name)\s+(.+?)\s+as\s+(.+)$');
  if (x != null) {
    return ContactsRequest(
        contact: clean(x[1]!),
        action: ContactAction.addAlias,
        alias: clean(x[2]!));
  }
  // Call: "call Rohan".
  x = m(r'^(?:call|dial|phone|ring)\s+(.+)$');
  if (x != null) {
    return ContactsRequest(contact: clean(x[1]!), action: ContactAction.call);
  }
  // Show: "open Allen", "show me Allen's contact", or just a name.
  x = m(r'^(?:open|show|find)\s+(?:me\s+)?(.+)$');
  if (x != null) return ContactsRequest(contact: clean(x[1]!));
  return null;
}

/// The result of a contact change, read aloud in the assistant's own
/// voice (the server's TTS via ai/speech.dart, into the app's one
/// player). Its own engine, so stopping it never cancels a reply.
class _ResultVoice {
  SpeechEngine? _engine;

  Future<void> say(String text) async {
    final v = _engine ??= SpeechEngine(port: ModelPorts.cloud());
    try {
      await v.cancel(sink: PcmPlayer.instance);
      await v.speak(text, PcmPlayer.instance, style: 'warm and friendly');
    } catch (e) {
      AppLog.add('contacts', 'could not speak the result: $e');
    }
  }

  /// Silent at once (the mic opening, the screen closing).
  void hush() {
    final v = _engine;
    if (v != null) unawaited(v.cancel(sink: PcmPlayer.instance));
  }
}

/// HUB → PHONE → CONTACTS (2026-11-22): the phone's contacts as the
/// assistant knows them, A–Z under letter headers, numbers saved without
/// a name last under '#'. One mic orb at the bottom takes commands about
/// any contact ("give alias Papa to Allen"): it opens that contact's card
/// and makes the change there. The main assistant does the same through
/// [requests]. Syncs from the phone each time the screen opens. Stored on
/// this phone only (lib/features/voice_call_contacts/).
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.request});

  /// Done once the list is up (the assistant opened the screen for it).
  final ContactsRequest? request;

  /// How many Contacts screens are open: the assistant sends a request
  /// to the open one instead of stacking another.
  static int showing = 0;

  /// A request for the open screen (see [showing]).
  static final requests = ValueNotifier<ContactsRequest?>(null);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _vcc = VoiceCallContacts.instance;
  late final Stream<List<LocalPerson>> _persons;
  final _search = TextEditingController();
  final _speech = SpeechToTextRecognizer();
  final _voice = _ResultVoice();
  String _query = '';
  bool _syncing = false;
  bool _noPermission = false;
  bool _listening = false;
  bool _heard = false;
  String _caption = '';
  String? _status;
  bool _statusIsError = false;

  /// A card is open over the list: a new request closes it first.
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    ContactsScreen.showing++;
    _vcc.hold();
    _persons = _vcc.watchPersons();
    ContactsScreen.requests.addListener(_onRequest);
    final first = widget.request;
    unawaited(() async {
      await _sync();
      if (first != null && mounted) await _handle(first);
    }());
  }

  @override
  void dispose() {
    ContactsScreen.showing--;
    ContactsScreen.requests.removeListener(_onRequest);
    if (_listening) _speech.cancel();
    _voice.hush();
    _search.dispose();
    _vcc.release();
    super.dispose();
  }

  void _onRequest() {
    final r = ContactsScreen.requests.value;
    if (r == null) return;
    ContactsScreen.requests.value = null;
    unawaited(_handle(r));
  }

  // Automatic: runs on open, quietly. The list updates itself when done.
  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final n = await _vcc.syncFromPhone();
      if (mounted) setState(() => _noPermission = n == null);
    } catch (_) {
      // The saved list stays on screen; the next open tries again.
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _say(String s, {bool error = false, bool speak = true}) {
    if (!mounted) return;
    setState(() {
      _status = s;
      _statusIsError = error;
    });
    if (speak) unawaited(_voice.say(s));
  }

  void _setQuery(String q) {
    _search.value = TextEditingValue(
        text: q, selection: TextSelection.collapsed(offset: q.length));
    setState(() => _query = q);
  }

  bool _matches(LocalPerson p) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.person.primaryName.toLowerCase().contains(q) ||
        p.aliases.any((a) => a.alias.toLowerCase().contains(q)) ||
        p.phones.any((ph) => ph.e164.contains(q.replaceAll(RegExp(r'\s'), '')));
  }

  /// Finds the contact a request names, then opens their card with the
  /// request, which the card carries out and shows.
  Future<void> _handle(ContactsRequest r) async {
    List<LocalPerson> all;
    try {
      all = await _vcc.persons();
    } catch (e) {
      AppLog.add('contacts', 'could not read contacts: $e');
      _say('Unable to read your contacts. Please try again.', error: true);
      return;
    }
    if (!mounted) return;
    LocalPerson? person;
    if (r.personId != null) {
      person = all.where((p) => p.person.id == r.personId).firstOrNull;
    } else {
      List<LocalCallMatch> found = const [];
      try {
        found = await _vcc.resolve(r.contact);
      } catch (e) {
        AppLog.add('contacts', 'resolve failed: $e');
      }
      if (!mounted) return;
      final ids = {for (final f in found) f.personId};
      if (ids.length > 1) {
        // Several people answer to it: show them and let the user pick.
        _setQuery(r.contact);
        _say('${ids.length} contacts match "${r.contact}". Tap the one you mean.');
        return;
      }
      if (ids.length == 1) {
        person = all.where((p) => p.person.id == ids.first).firstOrNull;
      }
    }
    if (person == null) {
      _say('No contact named "${r.contact}" was found on this phone.',
          error: true);
      return;
    }
    _setQuery('');
    setState(() => _status = null);
    _open(person, request: r);
  }

  void _open(LocalPerson p, {ContactsRequest? request}) {
    HapticFeedback.selectionClick();
    _voice.hush();
    final nav = Navigator.of(context);
    if (_sheetOpen) nav.pop();
    _sheetOpen = true;
    unawaited(showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PersonSheet(
          personId: p.person.id, initial: p, request: request, voice: _voice),
    ).whenComplete(() => _sheetOpen = false));
  }

  Future<void> _mic() async {
    HapticFeedback.mediumImpact();
    // Never into an open microphone: a result still being read stops.
    _voice.hush();
    if (_listening) {
      await _speech.stop();
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') &&
            mounted &&
            _listening &&
            !_heard) {
          setState(() => _listening = false);
        }
      },
      onError: (e, permanent) {
        AppLog.add('contacts', 'voice error: $e (permanent: $permanent)');
        if (!mounted) return;
        setState(() => _listening = false);
        if (permanent) _say(_voiceError(e), error: true);
      },
    );
    if (!mounted) return;
    if (!ok) {
      _say('Voice is unavailable on this device. Use the list instead.',
          error: true);
      return;
    }
    setState(() {
      _listening = true;
      _heard = false;
      _caption = '';
      _status = null;
    });
    await _speech.listen(
      onDevice: false,
      // 2 s of silence (counted from the start) cut people off before
      // they began: the phone closed the mic after 1.8 s, "no speech".
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 5),
      onResult: (words, isFinal) {
        if (!mounted) return;
        if (!isFinal) {
          setState(() => _caption = words);
          return;
        }
        _heard = true;
        setState(() {
          _listening = false;
          _caption = words;
        });
        if (words.trim().isEmpty) {
          _say('Nothing was heard. Tap the mic and try again.', error: true);
          return;
        }
        final r = parseContactsCommand(words);
        if (r == null || r.contact.isEmpty) {
          _say('Say, for example, "Give alias Papa to Allen" or "Call Rohan".',
              error: true);
          return;
        }
        unawaited(_handle(r));
      },
    );
  }

  /// speech_to_text's error codes, in words the user can act on.
  String _voiceError(String code) {
    if (code.contains('permission')) {
      return 'Microphone access is required. Allow it in Settings.';
    }
    if (code.contains('no_match') || code.contains('speech_timeout')) {
      return 'Nothing was heard. Tap the mic and talk after the tone.';
    }
    if (code.contains('network') || code.contains('server')) {
      return 'Voice needs an internet connection. Check it and try again.';
    }
    if (code.contains('busy')) {
      return 'The microphone is in use. Wait a moment and try again.';
    }
    return 'Voice is unavailable at the moment. Use the list instead.';
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Contacts'),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            StreamBuilder<List<LocalPerson>>(
              stream: _persons,
              builder: (context, snap) {
                if (snap.hasError) {
                  return NeonErrorState(
                      message: 'Unable to load your contacts.',
                      onRetry: _sync);
                }
                if (!snap.hasData) {
                  return const NeonLoader.page(
                      semanticLabel: 'Loading contacts');
                }
                return _list(snap.data!);
              },
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _MicDock(
                listening: _listening,
                caption: _caption,
                status: _status,
                statusIsError: _statusIsError,
                onTap: _mic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<LocalPerson> all) {
    final shown = all.where(_matches).toList();
    final sections = sectionsOf([for (final p in shown) p.person.primaryName]);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // The bottom clears the mic orb and its caption.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 170),
      children: [
        if (_syncing)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('Syncing with your phone…',
                style:
                    TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
          ),
        if (all.isNotEmpty) ...[
          AppleSearchField(
            controller: _search,
            hint: 'Search names or numbers',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 18),
        ],
        if (all.isEmpty && _noPermission)
          NeonEmptyState(
            icon: Icons.contacts_rounded,
            title: 'Contacts Access Is Off',
            body: 'Allow Contacts for this app in your phone Settings, '
                'then try again.',
            actionLabel: 'Try Again',
            actionIcon: Icons.refresh_rounded,
            onAction: _sync,
          )
        else if (all.isEmpty && !_syncing)
          const NeonEmptyState(
            icon: Icons.contacts_rounded,
            title: 'No Contacts Yet',
            body: 'Contacts saved on this phone appear here.',
          )
        else if (all.isNotEmpty && shown.isEmpty)
          const NeonEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No Matching Contacts',
          )
        else
          for (final (letter, idx) in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: GroupLabel(letter)),
                  GroupedCard(
                    dividerInset: 66,
                    children: [
                      for (final i in idx)
                        _ContactRow(
                            person: shown[i], onTap: () => _open(shown[i])),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// The page's one mic: an orb at the bottom, with what it heard or the
/// result above it.
class _MicDock extends StatelessWidget {
  const _MicDock({
    required this.listening,
    required this.caption,
    required this.status,
    required this.statusIsError,
    required this.onTap,
  });
  final bool listening;
  final String caption;
  final String? status;
  final bool statusIsError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = listening
        ? (caption.isEmpty
            ? 'Listening… say "Give alias Papa to Allen"'
            : '“$caption”')
        : status;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Neon.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Neon.line),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: !listening && statusIsError ? Neon.error : Neon.textHi,
                  fontSize: NeonType.footnote,
                  height: 1.35),
            ),
          ),
        Semantics(
          button: true,
          label: listening ? 'Stop Listening' : 'Speak a Contact Command',
          child: PressScale(
            child: Material(
              color: listening ? Neon.violet : NeonTone.brand.fill,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              elevation: 6,
              child: InkWell(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: listening
                        ? [
                            BoxShadow(
                                color: Neon.violet.withValues(alpha: 0.6),
                                blurRadius: 22)
                          ]
                        : const [],
                  ),
                  child: Icon(
                      listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      size: 30,
                      color: listening ? Colors.white : NeonTone.brand.ink),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _primaryPhone(LocalPerson p) {
  if (p.phones.isEmpty) return '';
  return p.phones
      .firstWhere((ph) => ph.isPrimary, orElse: () => p.phones.first)
      .e164;
}

/// The name shown for a person: their saved name, or the number when the
/// number was saved without one.
String _shownName(LocalPerson p) {
  final n = p.person.primaryName.trim();
  if (n.isNotEmpty && !isNameless(n)) return n;
  final ph = _primaryPhone(p);
  return ph.isNotEmpty ? ph : (n.isEmpty ? 'No Name' : n);
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.person, required this.onTap});
  final LocalPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nameless = isNameless(person.person.primaryName);
    final aka = otherNames(
        person.person.primaryName, person.aliases.map((a) => a.alias));
    return AppleRow(
      leading: _Initial(person.person.primaryName),
      title: _shownName(person),
      subtitle: nameless
          ? 'No name saved'
          : aka.isEmpty
              ? _primaryPhone(person)
              : 'Also ${aka.take(2).join(', ')}${aka.length > 2 ? '…' : ''}',
      onTap: onTap,
    );
  }
}

/// A round tile with the person's first letter ('#' without a name).
class _Initial extends StatelessWidget {
  const _Initial(this.name, {this.size = 36});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    final letter =
        t.isEmpty || isNameless(t) ? '#' : t.characters.first.toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Neon.accentFill,
      child: Text(
        letter,
        style: TextStyle(
            color: Neon.onAccent,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A contact's card, live: call them, and add, change or remove their
/// aliases. A [request] (from the page's mic or the assistant) is carried
/// out as the card opens, and its result is shown and spoken here.
class _PersonSheet extends StatefulWidget {
  const _PersonSheet({
    required this.personId,
    required this.initial,
    required this.voice,
    this.request,
  });
  final int personId;
  final LocalPerson initial;
  final _ResultVoice voice;
  final ContactsRequest? request;

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  final _vcc = VoiceCallContacts.instance;
  late final Stream<List<LocalPerson>> _persons;

  // Said inside the sheet: a toast raised here would land on the page
  // BEHIND it, under the barrier, where nobody sees it.
  String? _status;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _vcc.hold();
    _persons = _vcc.watchPersons();
    final r = widget.request;
    if (r != null && r.action != ContactAction.show) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(r));
    }
  }

  @override
  void dispose() {
    _vcc.release();
    super.dispose();
  }

  void _say(String s, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _status = s;
      _statusIsError = error;
    });
    unawaited(widget.voice.say(s));
  }

  Future<void> _run(ContactsRequest r) async {
    final p = widget.initial;
    switch (r.action) {
      case ContactAction.show:
        break;
      case ContactAction.call:
        await _call(p);
      case ContactAction.addAlias:
        await _safely(() => _add(p, r.alias));
      case ContactAction.changeAlias:
        await _safely(() => _rename(p, r.alias, r.newAlias));
      case ContactAction.removeAlias:
        await _safely(() => _remove(p, r.alias));
    }
  }

  Future<void> _call(LocalPerson p, [String? number]) async {
    final n = number ?? _primaryPhone(p);
    if (n.isEmpty) {
      _say('There is no number saved for this contact.', error: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final ok = await CallService.instance.call(n);
    if (!ok) {
      _say('Unable to place the call. Check the number and try again.',
          error: true);
      return;
    }
    unawaited(_vcc.recordCall(p.person.id).catchError((_) {}));
  }

  PersonAlias? _findAlias(LocalPerson p, String name) {
    final k = name.trim().toLowerCase();
    for (final a in p.aliases) {
      if (a.alias.trim().toLowerCase() == k) return a;
    }
    return null;
  }

  Future<void> _add(LocalPerson p, String alias) async {
    final a = alias.trim();
    if (a.isEmpty) return;
    if (_findAlias(p, a) != null ||
        a.toLowerCase() == p.person.primaryName.trim().toLowerCase()) {
      _say('"$a" already reaches ${_shownName(p)}.');
      return;
    }
    await _vcc.addAlias(p.person.id, a);
    _say('"$a" now reaches ${_shownName(p)}.');
  }

  Future<void> _rename(LocalPerson p, String from, String to) async {
    final old = _findAlias(p, from);
    if (old == null) {
      _say('"$from" is not one of ${_shownName(p)}\'s names.', error: true);
      return;
    }
    if (old.origin != originUserCustom) {
      // Names saved on the phone come back on every sync; add the new one.
      await _vcc.addAlias(p.person.id, to);
      _say('"${to.trim()}" added. "${old.alias}" is saved on your phone, '
          'so it stays.');
      return;
    }
    await _vcc.removeAlias(old.id);
    await _vcc.addAlias(p.person.id, to);
    _say('"${old.alias}" changed to "${to.trim()}".');
  }

  Future<void> _remove(LocalPerson p, String name) async {
    final a = _findAlias(p, name);
    if (a == null) {
      _say('"$name" is not one of ${_shownName(p)}\'s names.', error: true);
      return;
    }
    if (a.origin != originUserCustom) {
      _say(
          '"${a.alias}" is saved on your phone. Change it in your phone '
          'Contacts.',
          error: true);
      return;
    }
    await _vcc.removeAlias(a.id);
    _say('"${a.alias}" removed.');
  }

  /// Runs an alias change; a failure is said in the sheet, not swallowed.
  Future<void> _safely(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      AppLog.add('contacts', 'alias change failed: $e');
      _say('Unable to save the change. Please try again.', error: true);
    }
  }

  // The dialog owns its text controller (_NameDialog): disposing it here,
  // while the dialog was still fading out, broke the sheet's next build.
  Future<String?> _askName(String title, {String initial = ''}) async {
    final v = await showAppDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial),
    );
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LocalPerson>>(
      stream: _persons,
      builder: (context, snap) {
        final p = snap.data
                ?.where((x) => x.person.id == widget.personId)
                .firstOrNull ??
            widget.initial;
        return _body(context, p);
      },
    );
  }

  Widget _body(BuildContext context, LocalPerson p) {
    final name = p.person.primaryName;
    final others = otherNames(name, p.aliases.map((a) => a.alias));
    final hasPhone = p.phones.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 24 + MediaQuery.of(context).viewPadding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(child: _Initial(name, size: 64)),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(_shownName(p),
                  textAlign: TextAlign.center,
                  style: NeonType.cardTitle
                      .copyWith(color: Neon.textHi, letterSpacing: -0.2)),
            ),
            if (hasPhone && !isNameless(name)) ...[
              const SizedBox(height: 2),
              Text(_primaryPhone(p),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Neon.textLo, fontSize: NeonType.footnote)),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.call_rounded,
                  label: 'Call',
                  onTap: hasPhone ? () => _call(p) : null,
                ),
                _ActionButton(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Add Alias',
                  onTap: () async {
                    final a = await _askName('Add Alias');
                    if (a != null) await _safely(() => _add(p, a));
                  },
                ),
              ],
            ),
            if (_status != null) ...[
              const SizedBox(height: 14),
              Text(
                _status!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _statusIsError ? Neon.error : Neon.textLo,
                    fontSize: NeonType.footnote,
                    height: 1.35),
              ),
            ],
            const SizedBox(height: 20),
            const GroupLabel('Numbers'),
            GroupedCard(
              children: [
                if (!hasPhone)
                  const AppleRow(title: 'No Number Saved')
                else
                  for (final ph in p.phones)
                    AppleRow(
                      title: ph.e164,
                      subtitle:
                          ph.isPrimary ? '${ph.label} · primary' : ph.label,
                      trailing: Icon(Icons.call_rounded,
                          color: Neon.accentD, size: 20),
                      onTap: () => _call(p, ph.e164),
                    ),
              ],
            ),
            const SizedBox(height: 18),
            const GroupLabel('Also Known As'),
            GroupedCard(
              children: [
                if (others.isEmpty)
                  const AppleRow(
                      title: 'No Other Names',
                      subtitle: 'Add an alias to call them by another name')
                else
                  for (final n in others) _aliasRow(p, n),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aliasRow(LocalPerson p, String n) {
    final a = _findAlias(p, n);
    final custom = a?.origin == originUserCustom;
    if (!custom) {
      return AppleRow(title: n, subtitle: 'Saved on this phone');
    }
    return AppleRow(
      title: n,
      subtitle: 'Alias you added',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Change Alias',
            icon: Icon(Icons.edit_rounded, color: Neon.textLo, size: 20),
            onPressed: () async {
              final to = await _askName('Change Alias', initial: n);
              if (to != null && to != n) {
                await _safely(() => _rename(p, n, to));
              }
            },
          ),
          IconButton(
            tooltip: 'Remove Alias',
            icon:
                Icon(Icons.delete_outline_rounded, color: Neon.textLo, size: 20),
            onPressed: () => _safely(() => _remove(p, n)),
          ),
        ],
      ),
    );
  }
}

/// A round action under the contact's name (Call, Add Alias). The label
/// is part of the button: a tap on "Add Alias" under the circle did
/// nothing before.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PressScale(
                  child: Material(
                    color: NeonTone.brand.fill,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child:
                            Icon(icon, size: 24, color: NeonTone.brand.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(
                        color: Neon.textHi, fontSize: NeonType.footnote)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add Alias" / "Change Alias": one name, typed. It owns its controller,
/// so the text box is never left holding a disposed one while the dialog
/// fades out.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial = ''});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Neon.surfaceHigh,
      title: Text(widget.title, style: TextStyle(color: Neon.textHi)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(color: Neon.textHi),
        decoration: InputDecoration(
          hintText: 'For example "Boss" or "Uncle"',
          hintStyle: TextStyle(color: Neon.textDim),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: const Text('Save')),
      ],
    );
  }
}
