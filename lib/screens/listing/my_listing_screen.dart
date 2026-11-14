import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/listing.dart';
import '../../services/app_feedback.dart';
import '../../services/auth_service.dart';
import '../../services/avatar_message_service.dart';
import '../../services/listing_service.dart';
import '../../services/persona.dart';
import '../../services/pro_words.dart';
import '../clinic/clinic_settings_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  YOUR PUBLIC PAGE — a doctor's clinic, an advocate's chambers or a
///  business, published so people nearby find it in MyAssistant and anyone
///  finds it on Google (a real web page with call, WhatsApp, directions and
///  a booking form). Three parts: the page itself, short posts (not for
///  advocates — Bar Council rules), and booking requests to confirm.
///
///  Nothing is public until the professional taps "Go public", and doctors
///  and advocates need their registration / enrolment number first.
/// ─────────────────────────────────────────────────────────────────────────
class MyListingScreen extends StatefulWidget {
  const MyListingScreen({super.key, this.initialTab = 0});

  /// 0 page, 1 posts, 2 requests.
  final int initialTab;

  @override
  State<MyListingScreen> createState() => _MyListingScreenState();
}

class _MyListingScreenState extends State<MyListingScreen> {
  ListingState? _s;
  bool _failed = false;
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ListingService.instance.load();
    if (!mounted) return;
    setState(() {
      _s = s ?? _s;
      _failed = s == null && _s == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final tabs = <(int, String)>[
      (0, 'Page'),
      if (s == null || s.canPost) (1, 'Posts'),
      (2, 'Requests'),
    ];
    if (!tabs.any((t) => t.$1 == _tab)) _tab = 0;
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, 'Your public page'),
      body: _failed
          ? NeonErrorState(
              message: "Couldn't load your page. Check your connection.",
              onRetry: () {
                setState(() => _failed = false);
                _load();
              })
          : s == null
              ? const Center(child: NeonLoader())
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          for (final (i, label) in tabs)
                            ButtonSegment(
                              value: i,
                              label: ValueListenableBuilder<int>(
                                valueListenable: ListingService.instance.newRequests,
                                builder: (_, n, __) => Text(i == 2 && n > 0 ? '$label · $n' : label),
                              ),
                            ),
                        ],
                        selected: {_tab},
                        onSelectionChanged: (v) => setState(() => _tab = v.first),
                      ),
                    ),
                  ),
                  Expanded(
                    child: switch (_tab) {
                      1 => _PostsTab(state: s),
                      2 => const _RequestsTab(),
                      _ => _PageTab(state: s, onChanged: (n) => setState(() => _s = n), reload: _load),
                    },
                  ),
                ]),
    );
  }
}

/* ============================== PAGE ============================== */

class _PageTab extends StatefulWidget {
  const _PageTab({required this.state, required this.onChanged, required this.reload});
  final ListingState state;
  final ValueChanged<ListingState> onChanged;
  final Future<void> Function() reload;

  @override
  State<_PageTab> createState() => _PageTabState();
}

class _PageTabState extends State<_PageTab> {
  MyListing get _l => widget.state.listing;
  late final _name = TextEditingController(text: _l.displayName);
  late final _headline = TextEditingController(text: _l.headline);
  late final _place = TextEditingController(text: _l.placeName);
  late final _address = TextEditingController(text: _l.address);
  late final _area = TextEditingController(text: _l.area);
  late final _city = TextEditingController(text: _l.city);
  late final _pin = TextEditingController(text: _l.pincode);
  late final _phone = TextEditingController(text: _l.phone);
  late final _wa = TextEditingController(text: _l.whatsapp);
  late final _about = TextEditingController(text: _l.about);
  late final _services = TextEditingController(text: _l.services.join(', '));
  late final _langs = TextEditingController(text: _l.languages);
  late double? _lat = _l.lat;
  late double? _lng = _l.lng;
  late bool _accepts = _l.acceptsRequests;
  bool _dirty = false;
  bool _busy = false;
  bool _locating = false;
  Uint8List? _photo;

  List<TextEditingController> get _all =>
      [_name, _headline, _place, _address, _area, _city, _pin, _phone, _wa, _about, _services, _langs];

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  String get _persona => widget.state.listing.persona.isNotEmpty ? widget.state.listing.persona : Persona.value;
  ProWords get _w => ProWords.of(_persona);

  String get _headlineLabel => switch (_persona) {
        'doctor' => 'Speciality (e.g. Dentist, Paediatrician)',
        'advocate' => 'Practice (e.g. Civil & property, Family law)',
        _ => 'What you do (e.g. Sarees & silks, CA firm)',
      };

  String get _servicesLabel => switch (_persona) {
        'doctor' => 'Treatments & services (comma separated)',
        'advocate' => 'Areas of practice (comma separated)',
        _ => 'Products & services (comma separated)',
      };

  Map<String, dynamic> get _patch => {
        'displayName': _name.text.trim(),
        'headline': _headline.text.trim(),
        'placeName': _place.text.trim(),
        'address': _address.text.trim(),
        'area': _area.text.trim(),
        'city': _city.text.trim(),
        'pincode': _pin.text.trim(),
        'phone': _phone.text.trim(),
        'whatsapp': _wa.text.trim(),
        'about': _about.text.trim(),
        'services': _services.text,
        'languages': _langs.text.trim(),
        'acceptsRequests': _accepts,
        'lat': _lat,
        'lng': _lng,
      };

  Future<ListingState?> _save({bool quiet = false}) async {
    setState(() => _busy = true);
    final s = await ListingService.instance.save(_patch);
    if (!mounted) return null;
    setState(() => _busy = false);
    if (s == null) {
      AppFeedback.toast("Couldn't save. Check your connection.");
      return null;
    }
    _dirty = false;
    widget.onChanged(s);
    if (!quiet) {
      HapticFeedback.lightImpact();
      AppFeedback.toast(s.listing.published ? 'Saved — your page is updated.' : 'Saved.');
    }
    return s;
  }

  Future<void> _publish(bool on) async {
    if (on && (_dirty || widget.state.listing.draft)) {
      if (await _save(quiet: true) == null) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final r = await ListingService.instance.publish(on);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.state != null) {
      widget.onChanged(r.state!);
      HapticFeedback.mediumImpact();
      AppFeedback.toast(on ? 'You\'re live — people nearby can find you now.' : 'Your page is hidden.');
    } else if (r.missing.isNotEmpty) {
      AppFeedback.toast(r.message ?? 'Add: ${r.missing.map(missingLabel).join(', ')}');
      await widget.reload();
    } else {
      AppFeedback.toast("Couldn't change that. Check your connection.");
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        AppFeedback.toast('Allow location to pin your place — or paste a Google Maps link.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _dirty = true;
      });
      AppFeedback.toast(pos.accuracy > 60
          ? 'Pinned, but GPS was rough (±${pos.accuracy.round()} m). Check it on the map.'
          : 'Pinned to where you are now.');
    } catch (_) {
      AppFeedback.toast("Couldn't get your location. Try again outdoors, or paste a map link.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pasteLink() async {
    final clip = (await Clipboard.getData('text/plain'))?.text ?? '';
    if (!mounted) return;
    final c = TextEditingController(text: parseLatLng(clip) != null ? clip : '');
    final got = await showDialog<({double lat, double lng})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste a map link'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('In Google Maps, long-press your place, tap Share → Copy link, and paste it here. '
              'Coordinates like "12.8714, 74.8432" work too.'),
          const SizedBox(height: 12),
          TextField(controller: c, autofocus: true, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: 'https://maps.google.com/…')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final p = parseLatLng(c.text);
              if (p == null) {
                AppFeedback.toast("That link has no map location in it. Short links (maps.app.goo.gl) — open them first, then copy the address bar.");
                return;
              }
              Navigator.pop(ctx, p);
            },
            child: const Text('Use this'),
          ),
        ],
      ),
    );
    c.dispose();
    if (got == null || !mounted) return;
    setState(() {
      _lat = got.lat;
      _lng = got.lng;
      _dirty = true;
    });
  }

  void _checkOnMap() {
    if (_lat == null) return;
    launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$_lat,$_lng'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _pickPhoto() async {
    if (widget.state.listing.draft) {
      if (await _save(quiet: true) == null) return;
    }
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 80);
    if (x == null) return;
    var bytes = await x.readAsBytes();
    if (bytes.length > 380 * 1024) {
      final y = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 60);
      if (y == null) return;
      bytes = await y.readAsBytes();
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final s = await ListingService.instance.setPhoto(bytes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (s != null) _photo = bytes;
    });
    if (s == null) {
      AppFeedback.toast("Couldn't upload that photo. Use a JPEG or PNG under 400 KB.");
    } else {
      widget.onChanged(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final l = s.listing;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        _StatusCard(
          state: s,
          busy: _busy,
          dirty: _dirty,
          onPublish: () => _publish(true),
          onUnpublish: () => _publish(false),
          onFixReg: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ClinicSettingsScreen()));
            await widget.reload();
          },
        ),
        const SizedBox(height: 18),
        _section('Photo'),
        GroupedCard(children: [
          ListTile(
            leading: _PhotoThumb(bytes: _photo, url: l.published && l.hasPhoto && s.url != null ? '${s.url}/photo?v=${l.updatedAt}' : null, has: l.hasPhoto),
            title: Text(l.hasPhoto ? 'Change photo' : 'Add a photo', style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
            subtitle: Text('Your face or your ${_w.workspace.toLowerCase()} front, so people recognise you.',
                style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
            trailing: l.hasPhoto
                ? IconButton(
                    tooltip: 'Remove photo',
                    icon: Icon(Icons.delete_outline_rounded, color: Neon.textLo),
                    onPressed: _busy
                        ? null
                        : () async {
                            final r = await ListingService.instance.removePhoto();
                            if (r != null && mounted) {
                              setState(() => _photo = null);
                              widget.onChanged(r);
                            }
                          })
                : null,
            onTap: _busy ? null : _pickPhoto,
          ),
        ]),
        const SizedBox(height: 18),
        _section('Who you are'),
        _field(_name, 'Name shown on the page', Icons.badge_rounded, caps: TextCapitalization.words),
        _field(_headline, _headlineLabel, Icons.workspace_premium_rounded, caps: TextCapitalization.sentences),
        const SizedBox(height: 8),
        _section('Where'),
        _field(_place, _w.placeName, Icons.storefront_rounded, caps: TextCapitalization.words),
        _field(_address, 'Full address (building, street, landmark)', Icons.home_work_rounded,
            caps: TextCapitalization.sentences, lines: 2),
        Row(children: [
          Expanded(child: _field(_area, 'Area', Icons.place_rounded, caps: TextCapitalization.words)),
          const SizedBox(width: 10),
          Expanded(child: _field(_city, 'City', Icons.location_city_rounded, caps: TextCapitalization.words)),
        ]),
        _field(_pin, 'PIN code', Icons.markunread_mailbox_rounded, keyboard: TextInputType.number),
        _PinCard(
          lat: _lat,
          lng: _lng,
          locating: _locating,
          onHere: _useCurrentLocation,
          onPaste: _pasteLink,
          onCheck: _checkOnMap,
        ),
        const SizedBox(height: 18),
        _section('Contact'),
        _field(_phone, 'Phone for patients / clients to call', Icons.call_rounded, keyboard: TextInputType.phone),
        _field(_wa, 'WhatsApp number (optional)', Icons.chat_rounded, keyboard: TextInputType.phone,
            suffix: _phone.text.trim().isEmpty
                ? null
                : TextButton(onPressed: () => _wa.text = _phone.text.trim(), child: const Text('Same'))),
        const SizedBox(height: 8),
        _section('About'),
        _field(_about, 'A few lines about you and your ${_w.workspace.toLowerCase()}', Icons.notes_rounded,
            caps: TextCapitalization.sentences, lines: 4),
        _field(_services, _servicesLabel, Icons.checklist_rounded, caps: TextCapitalization.sentences, lines: 2),
        _field(_langs, 'Languages (e.g. Kannada, English, Tulu)', Icons.translate_rounded, caps: TextCapitalization.words),
        GroupedCard(children: [
          SwitchListTile(
            value: _accepts,
            onChanged: (v) => setState(() {
              _accepts = v;
              _dirty = true;
            }),
            title: Text('Take booking requests', style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
            subtitle: Text('A "Request booking" form on your page. You confirm each one.',
                style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
          ),
        ]),
        if (s.hours.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Timings on the page come from ${_w.settings}: ${s.hours}',
                style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 20),
        ApplePrimaryButton(
          label: _busy ? 'Saving…' : (l.published ? 'Save & update page' : 'Save'),
          icon: Icons.check_rounded,
          onPressed: _busy || (!_dirty && !l.draft) ? null : () => _save(),
        ),
      ],
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t.toUpperCase(), style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
      );

  Widget _field(TextEditingController c, String label, IconData icon,
          {TextCapitalization caps = TextCapitalization.none, TextInputType? keyboard, int lines = 1, Widget? suffix}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          textCapitalization: caps,
          keyboardType: lines > 1 ? TextInputType.multiline : keyboard,
          minLines: 1,
          maxLines: lines,
          onChanged: suffix != null ? (_) => setState(() {}) : null,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIcon: suffix),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.busy,
    required this.dirty,
    required this.onPublish,
    required this.onUnpublish,
    required this.onFixReg,
  });
  final ListingState state;
  final bool busy;
  final bool dirty;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onFixReg;

  @override
  Widget build(BuildContext context) {
    final l = state.listing;
    final live = l.published;
    final tint = live ? Neon.success : Neon.violet;
    final needsReg = state.missing.any((m) => m == 'reg_no' || m == 'enrolment_no');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Color.alphaBlend(tint.withValues(alpha: 0.10), Neon.surface),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(live ? Icons.public_rounded : Icons.public_off_rounded, size: 15, color: tint),
              const SizedBox(width: 5),
              Text(live ? 'LIVE' : 'NOT PUBLIC', style: TextStyle(color: tint, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
            ]),
          ),
          const Spacer(),
          if (live)
            Text('${l.views} ${l.views == 1 ? 'visit' : 'visits'}', style: TextStyle(color: Neon.textLo, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Text(
          live
              ? 'People near you find you in MyAssistant, and anyone can open your page from Google.'
              : 'Go public and people nearby find you when they search "${_example(l.persona)}" — in MyAssistant and on Google.',
          style: TextStyle(color: Neon.textHi, fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600),
        ),
        if (live && state.url != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(color: Neon.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Neon.line)),
            child: Row(children: [
              Expanded(
                child: Text(state.url!.replaceFirst(RegExp(r'^https?://'), ''),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Neon.textLo, fontSize: 13)),
              ),
              IconButton(
                tooltip: 'Copy link',
                icon: Icon(Icons.copy_rounded, size: 19, color: Neon.textLo),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: state.url!));
                  if (context.mounted) AppFeedback.copied(context, 'Link copied');
                },
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Share.share(
                    '${l.persona == 'business' && l.placeName.isNotEmpty ? l.placeName : l.displayName} — ${state.url}'),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(state.url!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('View'),
              ),
            ),
          ]),
          if (dirty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('You have unsaved changes — save to update the page.', style: TextStyle(color: Neon.warning, fontSize: 12.5)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: busy ? null : onUnpublish, child: Text('Take page down', style: TextStyle(color: Neon.textLo))),
          ),
        ] else ...[
          if (state.missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Before you go public:', style: TextStyle(color: Neon.textLo, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final m in state.missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(Icons.radio_button_unchecked_rounded, size: 16, color: Neon.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text(missingLabel(m), style: TextStyle(color: Neon.textHi, fontSize: 14))),
                ]),
              ),
            if (needsReg)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onFixReg,
                  icon: const Icon(Icons.verified_user_rounded, size: 18),
                  label: Text('Add it in ${ProWords.of(l.persona).settings}'),
                ),
              ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Neon.success, padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: busy ? null : onPublish,
              icon: const Icon(Icons.campaign_rounded),
              label: Text(busy ? 'Working…' : 'Go public'),
            ),
          ),
        ],
      ]),
    );
  }

  static String _example(String persona) => switch (persona) {
        'doctor' => 'doctors near me',
        'advocate' => 'lawyers near me',
        _ => 'shops near me',
      };
}

class _PinCard extends StatelessWidget {
  const _PinCard({required this.lat, required this.lng, required this.locating, required this.onHere, required this.onPaste, required this.onCheck});
  final double? lat;
  final double? lng;
  final bool locating;
  final VoidCallback onHere;
  final VoidCallback onPaste;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final has = lat != null && lng != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: has ? Neon.success.withValues(alpha: 0.5) : Neon.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(has ? Icons.location_on_rounded : Icons.location_off_rounded, color: has ? Neon.success : Neon.textLo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              has ? 'Map pin set · ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}' : 'No map pin yet',
              style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w700),
            ),
          ),
          if (has) TextButton(onPressed: onCheck, child: const Text('Check')),
        ]),
        const SizedBox(height: 4),
        Text('Stand inside your place and tap "I\'m here" — or paste its Google Maps link. This is where Directions will lead.',
            style: TextStyle(color: Neon.textLo, fontSize: 12.5, height: 1.35)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: locating ? null : onHere,
              icon: locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(locating ? 'Locating…' : "I'm here"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPaste,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Map link'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({this.bytes, this.url, required this.has});
  final Uint8List? bytes;
  final String? url;
  final bool has;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (bytes != null) {
      child = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (url != null) {
      child = Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _icon(true));
    } else {
      child = _icon(has);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 48, height: 48, child: child));
  }

  Widget _icon(bool has) => Container(
        color: Neon.bg,
        child: Icon(has ? Icons.check_circle_rounded : Icons.add_a_photo_rounded, color: has ? Neon.success : Neon.textLo),
      );
}

/* ============================== POSTS ============================== */

class _PostsTab extends StatefulWidget {
  const _PostsTab({required this.state});
  final ListingState state;

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  List<ListingPost>? _posts;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ListingService.instance.posts();
    if (!mounted) return;
    setState(() {
      _posts = p ?? _posts;
      _failed = p == null && _posts == null;
    });
  }

  Future<void> _new() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _PostSheet(kinds: widget.state.postKinds),
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    final doctor = widget.state.listing.persona == 'doctor';
    return Stack(children: [
      if (_failed)
        NeonErrorState(message: "Couldn't load posts.", onRetry: () {
          setState(() => _failed = false);
          _load();
        })
      else if (posts == null)
        const Center(child: NeonLoader())
      else if (posts.isEmpty)
        NeonEmptyState(
          icon: Icons.campaign_rounded,
          title: 'No posts yet',
          body: doctor
              ? 'Share updates — "Closed on Sunday", "Free BP camp on Saturday". They show on your page and to people nearby. No one is notified.'
              : 'Share an update or an offer — "Diwali 20% off", "New stock in". It shows on your page and to people nearby. No one is notified.',
          actionLabel: 'New post',
          actionIcon: Icons.add_rounded,
          onAction: _new,
        )
      else
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('Shown on your page and to people nearby until they expire. Nobody gets a notification.',
                    style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
              ),
              GroupedCard(dividerInset: 16, children: [
                for (final p in posts)
                  ListTile(
                    title: Row(children: [
                      if (p.isOffer)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: Neon.warning.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                          child: Text('OFFER', style: TextStyle(color: Neon.warning, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                      Expanded(child: Text(p.title.isNotEmpty ? p.title : p.body, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w700))),
                    ]),
                    subtitle: Text(
                      [if (p.title.isNotEmpty && p.body.isNotEmpty) p.body, 'until ${_date(p.expiresAt)}'].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Neon.textLo, fontSize: 12.5),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: Icon(Icons.delete_outline_rounded, color: Neon.textLo),
                      onPressed: () async {
                        if (await ListingService.instance.deletePost(p.id)) _load();
                      },
                    ),
                  ),
              ]),
            ],
          ),
        ),
      if (posts != null && posts.isNotEmpty)
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
          child: FloatingActionButton.extended(
            backgroundColor: Neon.violet,
            foregroundColor: Colors.white,
            onPressed: _new,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New post'),
          ),
        ),
    ]);
  }
}

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]}';
}

class _PostSheet extends StatefulWidget {
  const _PostSheet({required this.kinds});
  final List<String> kinds;
  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late String _kind = widget.kinds.first;
  int _days = 14;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_title.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    final p = await ListingService.instance.addPost(kind: _kind, title: _title.text.trim(), body: _body.text.trim(), days: _days);
    if (!mounted) return;
    if (p == null) {
      setState(() => _busy = false);
      AppFeedback.toast("Couldn't post. You can have up to 10 live posts.");
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('New post', style: TextStyle(color: Neon.textHi, fontSize: 19, fontWeight: FontWeight.w700)),
        if (widget.kinds.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final k in widget.kinds)
              ChoiceChip(
                label: Text(k == 'offer' ? 'Offer' : 'Update'),
                selected: _kind == k,
                showCheckmark: false,
                selectedColor: Neon.violet.withValues(alpha: 0.15),
                onSelected: (_) => setState(() => _kind = k),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          autofocus: true,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: _kind == 'offer' ? 'Offer (e.g. 20% off all sarees)' : 'Headline (e.g. Clinic closed on Sunday)'),
        ),
        TextField(
          controller: _body,
          minLines: 2,
          maxLines: 5,
          maxLength: 600,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Details (optional)'),
        ),
        Text('Show for', style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final (d, label) in const [(3, '3 days'), (7, '1 week'), (14, '2 weeks'), (30, '1 month')])
            ChoiceChip(
              label: Text(label),
              selected: _days == d,
              showCheckmark: false,
              selectedColor: Neon.violet.withValues(alpha: 0.15),
              onSelected: (_) => setState(() => _days = d),
            ),
        ]),
        const SizedBox(height: 18),
        ApplePrimaryButton(label: _busy ? 'Posting…' : 'Post', onPressed: _title.text.trim().isEmpty || _busy ? null : _post),
      ]),
    );
  }
}

/* ============================== REQUESTS ============================== */

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();
  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  List<BookingRequest>? _list;
  bool _failed = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ListingService.instance.requests();
    if (!mounted) return;
    setState(() {
      _list = r ?? _list;
      _failed = r == null && _list == null;
    });
  }

  Future<void> _confirm(BookingRequest r) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 120)),
      helpText: 'Appointment for ${r.name}',
    );
    if (day == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t == null || !mounted) return;
    final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
    if (at.isBefore(DateTime.now())) {
      AppFeedback.toast('Pick a time that has not passed.');
      return;
    }
    setState(() => _busy.add(r.id));
    final ok = await ListingService.instance.accept(r.id, at);
    if (!mounted) return;
    setState(() => _busy.remove(r.id));
    if (!ok) {
      AppFeedback.toast("Couldn't book that. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    AppFeedback.toast('Booked ${r.name} for ${_date(at)}, ${t.format(context)}. Call them to confirm.');
    _load();
  }

  Future<void> _decline(BookingRequest r) async {
    setState(() => _busy.add(r.id));
    final ok = await ListingService.instance.decline(r.id);
    if (!mounted) return;
    setState(() => _busy.remove(r.id));
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (_failed) {
      return NeonErrorState(message: "Couldn't load requests.", onRetry: () {
        setState(() => _failed = false);
        _load();
      });
    }
    if (list == null) return const Center(child: NeonLoader());
    if (list.isEmpty) {
      return const NeonEmptyState(
        icon: Icons.event_note_rounded,
        title: 'No booking requests yet',
        body: 'When someone taps "Request booking" on your page or in MyAssistant, it lands here and you get a notification.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = list[i];
          final busy = _busy.contains(r.id);
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            decoration: BoxDecoration(
              color: Neon.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: r.isNew ? Neon.violet.withValues(alpha: 0.45) : Neon.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(
                      [r.phone, '${r.source == 'app' ? 'via app' : 'via web page'} · ${_date(r.createdAt)}'].join('  ·  '),
                      style: TextStyle(color: Neon.textLo, fontSize: 12.5),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: 'Call ${r.name}',
                  icon: Icon(Icons.call_rounded, color: Neon.accentE),
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: r.phone)),
                ),
              ]),
              if (r.preferred.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Wants: ${r.preferred}', style: TextStyle(color: Neon.textHi, fontSize: 14)),
              ],
              if (r.message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.message, style: TextStyle(color: Neon.textLo, fontSize: 13.5)),
              ],
              const SizedBox(height: 6),
              if (r.isNew)
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => _confirm(r),
                      child: const Text('Book a time'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: busy ? null : () => _decline(r), child: const Text('Decline')),
                  const SizedBox(width: 4),
                ])
              else
                Text(r.status == 'accepted' ? 'Booked' : 'Declined',
                    style: TextStyle(color: r.status == 'accepted' ? Neon.success : Neon.textDim, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          );
        },
      ),
    );
  }
}

/// Used by the assistant page's card (kept here so it shares the words).
String listingCardLine(ListingState? s) {
  if (s == null) return 'Be found by people nearby and on Google';
  final l = s.listing;
  if (l.published) {
    final parts = ['Live', '${l.views} ${l.views == 1 ? 'visit' : 'visits'}'];
    if (s.newRequests > 0) parts.add('${s.newRequests} new ${s.newRequests == 1 ? 'request' : 'requests'}');
    return parts.join(' · ');
  }
  return s.missing.isEmpty ? 'Ready — tap to go public' : 'Not public yet · ${s.missing.length} to add';
}

/// Opens the booking requests from a tapped notification (kind
/// listing_request), waiting for the navigator on a cold start.
abstract final class ListingNav {
  static const payload = 'listing_requests';

  static Future<void> open() async {
    for (var i = 0; i < 24; i++) {
      final nav = AvatarMessageService.navigatorKey.currentState;
      if (nav != null && AuthService.instance.user != null) {
        unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => const MyListingScreen(initialTab: 2))));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}
