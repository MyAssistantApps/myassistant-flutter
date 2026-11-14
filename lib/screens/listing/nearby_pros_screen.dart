import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/listing.dart';
import '../../services/api_service.dart';
import '../../services/app_feedback.dart';
import '../../services/auth_service.dart';
import '../../services/listing_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PROFESSIONALS NEAR YOU — doctors, advocates and businesses on
///  MyAssistant who published their page, nearest first. Call, WhatsApp,
///  directions, or request a booking (it lands in their app to confirm).
///  Posts and offers show on each card; nobody is ever notified of them.
/// ─────────────────────────────────────────────────────────────────────────
class NearbyProsScreen extends StatefulWidget {
  const NearbyProsScreen({super.key, this.initialPersona = '', this.initialQuery = ''});
  final String initialPersona;
  final String initialQuery;

  @override
  State<NearbyProsScreen> createState() => _NearbyProsScreenState();
}

class _NearbyProsScreenState extends State<NearbyProsScreen> {
  late final _q = TextEditingController(text: widget.initialQuery);
  late String _persona = widget.initialPersona;
  int _radius = 15;
  List<ProCard>? _results;
  String? _problem; // 'location' | 'network'
  bool _loading = false;
  Timer? _debounce;
  double? _lat;
  double? _lng;

  static const _filters = [('', 'All'), ('doctor', 'Doctors'), ('advocate', 'Advocates'), ('business', 'Businesses')];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<bool> _locate() async {
    if (_lat != null) return true;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos == null || DateTime.now().difference(pos.timestamp) > const Duration(minutes: 10)) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        ).timeout(const Duration(seconds: 12));
      }
      _lat = pos.latitude;
      _lng = pos.longitude;
      ApiService.geoLat = _lat;
      ApiService.geoLng = _lng;
      return true;
    } catch (_) {
      if (ApiService.geoLat != null && ApiService.geoLng != null) {
        _lat = ApiService.geoLat;
        _lng = ApiService.geoLng;
        return true;
      }
      return false;
    }
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _problem = null;
    });
    if (!await _locate()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _problem = 'location';
      });
      return;
    }
    final r = await ListingService.instance.near(lat: _lat!, lng: _lng!, q: _q.text, persona: _persona, radiusKm: _radius);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r == null) {
        _problem = 'network';
      } else {
        _results = r;
      }
    });
  }

  void _onType(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, 'Near you'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: TextField(
            controller: _q,
            onChanged: _onType,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: TextStyle(color: Neon.textHi, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Dentist, family lawyer, saree shop…',
              hintStyle: TextStyle(color: Neon.textDim),
              prefixIcon: Icon(Icons.search_rounded, color: Neon.textLo),
              filled: true,
              fillColor: Neon.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Neon.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Neon.line)),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (id, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _persona == id,
                    showCheckmark: false,
                    selectedColor: Neon.violet.withValues(alpha: 0.16),
                    onSelected: (_) {
                      setState(() => _persona = id);
                      _search();
                    },
                  ),
                ),
              PopupMenuButton<int>(
                tooltip: 'Distance',
                initialValue: _radius,
                onSelected: (v) {
                  setState(() => _radius = v);
                  _search();
                },
                itemBuilder: (_) => [for (final r in const [3, 5, 15, 30, 50]) PopupMenuItem(value: r, child: Text('Within $r km'))],
                child: Chip(
                  avatar: Icon(Icons.radar_rounded, size: 17, color: Neon.textLo),
                  label: Text('$_radius km'),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _body(results)),
      ]),
    );
  }

  Widget _body(List<ProCard>? results) {
    if (_problem == 'location') {
      return NeonEmptyState(
        icon: Icons.location_off_rounded,
        title: 'Location is off',
        body: 'Allow location to see doctors, advocates and businesses near you.',
        actionLabel: 'Try again',
        actionIcon: Icons.my_location_rounded,
        onAction: () async {
          if (await Geolocator.checkPermission() == LocationPermission.deniedForever) {
            await Geolocator.openAppSettings();
          }
          _search();
        },
      );
    }
    if (_problem == 'network' && results == null) {
      return NeonErrorState(message: "Couldn't search right now.", onRetry: _search);
    }
    if (results == null) return const Center(child: NeonLoader());
    if (results.isEmpty) {
      return NeonEmptyState(
        icon: Icons.storefront_rounded,
        title: _loading ? 'Searching…' : 'No one listed nearby yet',
        body: 'Only professionals on MyAssistant who published their page appear here. Try a wider distance or "All".',
        actionLabel: _radius < 50 ? 'Search within 50 km' : null,
        actionIcon: Icons.zoom_out_map_rounded,
        onAction: _radius < 50
            ? () {
                setState(() => _radius = 50);
                _search();
              }
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 32 + MediaQuery.paddingOf(context).bottom),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ProTile(card: results[i], onOpen: () => _open(results[i])),
      ),
    );
  }

  void _open(ProCard c) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProDetailScreen(slug: c.slug, preview: c)));
}

IconData _personaIcon(String p) => switch (p) {
      'doctor' => Icons.medical_services_rounded,
      'advocate' => Icons.gavel_rounded,
      _ => Icons.storefront_rounded,
    };

Color _personaTint(String p) => switch (p) {
      'doctor' => Neon.accentE,
      'advocate' => Neon.accentF,
      _ => Neon.accentD,
    };

class _Avatar extends StatelessWidget {
  const _Avatar({required this.card, this.size = 56});
  final ProCard card;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = _personaTint(card.persona);
    final fallback = Container(
      color: tint.withValues(alpha: 0.15),
      child: Icon(_personaIcon(card.persona), color: tint, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: SizedBox(
        width: size,
        height: size,
        child: card.photoUrl == null
            ? fallback
            : Image.network(card.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
      ),
    );
  }
}

void _call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

void _directions(ProCard c) => launchUrl(
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lng}'),
    mode: LaunchMode.externalApplication);

String? _wa(String n) {
  final d = n.replaceAll(RegExp(r'\D'), '');
  if (d.length == 10) return '91$d';
  if (d.length == 11 && d.startsWith('0')) return '91${d.substring(1)}';
  return d.length >= 11 ? d : null;
}

class _ProTile extends StatelessWidget {
  const _ProTile({required this.card, required this.onOpen});
  final ProCard card;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final post = card.posts.isEmpty ? null : card.posts.first;
    return Material(
      color: Neon.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Neon.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Avatar(card: card),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Neon.textHi, fontSize: 16, fontWeight: FontWeight.w800)),
                  if (card.subtitle.isNotEmpty)
                    Text(card.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Neon.textLo, fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(
                    [distanceLabel(card.distanceKm), if (card.where.isNotEmpty) card.where].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(color: _personaTint(card.persona), fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ]),
            if (post != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (post.isOffer ? Neon.warning : Neon.violet).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${post.isOffer ? 'Offer: ' : ''}${post.title.isNotEmpty ? post.title : post.body}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Neon.textHi, fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(children: [
              if (card.phone.isNotEmpty)
                TextButton.icon(onPressed: () => _call(card.phone), icon: const Icon(Icons.call_rounded, size: 18), label: const Text('Call')),
              if (card.lat != null)
                TextButton.icon(onPressed: () => _directions(card), icon: const Icon(Icons.directions_rounded, size: 18), label: const Text('Directions')),
              const Spacer(),
              if (card.acceptsRequests)
                TextButton(onPressed: onOpen, child: const Text('Book')),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// One professional in full: details, posts, and "Request a booking".
class ProDetailScreen extends StatefulWidget {
  const ProDetailScreen({super.key, required this.slug, this.preview});
  final String slug;
  final ProCard? preview;

  @override
  State<ProDetailScreen> createState() => _ProDetailScreenState();
}

class _ProDetailScreenState extends State<ProDetailScreen> {
  ProCard? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = widget.preview;
    _load();
  }

  Future<void> _load() async {
    final c = await ListingService.instance.open(widget.slug);
    if (!mounted) return;
    setState(() {
      _c = c ?? _c;
      _failed = c == null && widget.preview == null;
    });
  }

  Future<void> _book() async {
    final c = _c;
    if (c == null) return;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BookSheet(card: c),
      ),
    );
    if (sent == true && mounted) {
      AppFeedback.toast('Request sent — ${c.displayName} will call you to confirm.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, c?.title ?? ''),
      body: _failed
          ? NeonErrorState(message: "Couldn't open this page.", onRetry: _load)
          : c == null
              ? const Center(child: NeonLoader())
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    Row(children: [
                      _Avatar(card: c, size: 76),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.title, style: TextStyle(color: Neon.textHi, fontSize: 21, fontWeight: FontWeight.w800, height: 1.15)),
                          if (c.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(c.subtitle, style: TextStyle(color: Neon.textLo, fontSize: 14)),
                          ],
                          if (c.distanceKm != null) ...[
                            const SizedBox(height: 3),
                            Text('${distanceLabel(c.distanceKm)} away',
                                style: TextStyle(color: _personaTint(c.persona), fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      if (c.phone.isNotEmpty)
                        Expanded(child: FilledButton.icon(onPressed: () => _call(c.phone), icon: const Icon(Icons.call_rounded, size: 18), label: const Text('Call'))),
                      if (_wa(c.whatsapp) != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => launchUrl(Uri.parse('https://wa.me/${_wa(c.whatsapp)}'), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                      ],
                      if (c.lat != null) ...[
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton.icon(onPressed: () => _directions(c), icon: const Icon(Icons.directions_rounded, size: 18), label: const Text('Go'))),
                      ],
                    ]),
                    if (c.acceptsRequests) ...[
                      const SizedBox(height: 10),
                      ApplePrimaryButton(label: 'Request a booking', icon: Icons.event_available_rounded, onPressed: _book),
                    ],
                    if (c.posts.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _label('Updates'),
                      GroupedCard(dividerInset: 16, children: [
                        for (final p in c.posts)
                          ListTile(
                            leading: Icon(p.isOffer ? Icons.local_offer_rounded : Icons.campaign_rounded, color: p.isOffer ? Neon.warning : Neon.violet),
                            title: Text(p.title.isNotEmpty ? p.title : p.body, style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w700)),
                            subtitle: p.title.isNotEmpty && p.body.isNotEmpty ? Text(p.body, style: TextStyle(color: Neon.textLo)) : null,
                          ),
                      ]),
                    ],
                    if (c.about.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _label('About'),
                      Text(c.about, style: TextStyle(color: Neon.textHi, fontSize: 14.5, height: 1.45)),
                    ],
                    const SizedBox(height: 18),
                    _label('Details'),
                    GroupedCard(dividerInset: 16, children: [
                      if (c.placeName.isNotEmpty && c.persona != 'business') _fact(Icons.storefront_rounded, 'Practice at', c.placeName),
                      if (c.qualification.isNotEmpty) _fact(Icons.school_rounded, 'Qualification', c.qualification),
                      if (c.regNo.isNotEmpty) _fact(Icons.verified_user_rounded, c.persona == 'advocate' ? 'Enrolment no.' : 'Reg. no.', c.regNo),
                      if (c.hours.isNotEmpty) _fact(Icons.schedule_rounded, 'Timings', c.hours),
                      if (c.fee > 0 && c.persona == 'doctor') _fact(Icons.currency_rupee_rounded, 'Consultation', '₹${c.fee.round()}'),
                      if (c.languages.isNotEmpty) _fact(Icons.translate_rounded, 'Languages', c.languages),
                      _fact(Icons.place_rounded, 'Address', [c.address, c.where].where((s) => s.isNotEmpty).join(', ')),
                    ]),
                    if (c.services.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _label(c.persona == 'advocate' ? 'Areas of practice' : 'Services'),
                      Wrap(spacing: 8, runSpacing: 8, children: [for (final s in c.services) Chip(label: Text(s))]),
                    ],
                    if (c.url.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: c.url));
                          if (context.mounted) AppFeedback.copied(context, 'Link copied');
                        },
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('Copy link to this page'),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t.toUpperCase(), style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
      );

  Widget _fact(IconData icon, String k, String v) => ListTile(
        dense: true,
        leading: Icon(icon, color: Neon.textLo, size: 20),
        title: Text(k, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
        subtitle: Text(v, style: TextStyle(color: Neon.textHi, fontSize: 14.5)),
      );
}

class _BookSheet extends StatefulWidget {
  const _BookSheet({required this.card});
  final ProCard card;
  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  late final _name = TextEditingController(text: AuthService.instance.user?.name ?? '');
  late final _phone = TextEditingController(text: AuthService.instance.user?.phone ?? '');
  final _pref = TextEditingController();
  final _msg = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _pref, _msg]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ok => _name.text.trim().isNotEmpty && _phone.text.replaceAll(RegExp(r'\D'), '').length >= 8;

  Future<void> _send() async {
    if (!_ok || _busy) return;
    setState(() => _busy = true);
    final ok = await ListingService.instance.requestBooking(widget.card.slug,
        name: _name.text.trim(), phone: _phone.text.trim(), preferred: _pref.text.trim(), message: _msg.text.trim());
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      AppFeedback.toast("Couldn't send. Please call instead.");
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
        Text('Request a booking', style: TextStyle(color: Neon.textHi, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${widget.card.displayName} will call you to confirm a time. Your number goes only to them.',
            style: TextStyle(color: Neon.textLo, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Your name')),
        const SizedBox(height: 10),
        TextField(controller: _phone, keyboardType: TextInputType.phone, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final p in const ['Today', 'Tomorrow morning', 'Tomorrow evening', 'This weekend'])
            ActionChip(label: Text(p), onPressed: () => setState(() => _pref.text = p)),
        ]),
        const SizedBox(height: 8),
        TextField(controller: _pref, decoration: const InputDecoration(labelText: 'Preferred day / time')),
        const SizedBox(height: 10),
        TextField(controller: _msg, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Message (optional)')),
        const SizedBox(height: 18),
        ApplePrimaryButton(label: _busy ? 'Sending…' : 'Send request', onPressed: _ok && !_busy ? _send : null),
      ]),
    );
  }
}
