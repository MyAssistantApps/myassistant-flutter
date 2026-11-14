import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../design/neon_widgets.dart';
import 'package:flutter/services.dart';

import '../ai/assistant_role.dart';
import '../ai/listen.dart';
import '../ai/model_port.dart';
import '../models/user_document.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../design/apple_kit.dart';
import '../design/neon_tokens.dart';
import '../features/assistant/state/assistant_engine.dart';
import '../features/assistant/state/assistant_state.dart';
import '../widgets/role_mic_orb.dart';
import 'clients_screen.dart';
import 'documents_screen.dart';
import 'clinic/clinic_screen.dart';
import 'clinic/clinic_settings_screen.dart';
import 'clinic/clinic_sheets.dart';
import 'pro/cases_screen.dart';
import 'pro/invoices_screen.dart';
import 'pro/leads_screen.dart';
import 'pro/legal_draft_screen.dart';
import 'listing/my_listing_screen.dart';
import '../services/listing_service.dart';
import '../models/clinic.dart' show rupees;
import '../services/clinic_service.dart';
import '../services/persona.dart';
import '../services/pro_photo.dart';

/// THE PROFESSIONAL ASSISTANTS (client, 2026-11-01: "in that place you can
/// add Doctor's, Advocates & Business, below write 'Assistant'").
///
/// One page per profession, built on what the app already does for each:
/// the case-file workspace (ClientsScreen), and the assistant's own tools —
/// patient dues and follow-up visits, case notes and Indian law, the record
/// book and finance. An action either opens the screen for it or asks the
/// assistant, who answers out loud (sending or paying still asks for a yes).
enum ProKind { doctor, advocate, business }

class ProAction {
  const ProAction(this.title, this.detail, this.icon,
      {this.ask, this.page, this.run, this.featured = false});

  /// Drawn as the wide card at the top of the page (the doctor's "Today at
  /// clinic", with the day's live numbers) instead of a grid tile.
  final bool featured;
  final String title;
  final String detail;
  final IconData icon;

  /// Said to the assistant.
  final String? ask;

  /// Or opened.
  final Widget Function()? page;

  /// Or run in place (a bottom sheet — "Note a payment", "Book").
  final Future<void> Function(BuildContext context)? run;
}

class ProProfile {
  const ProProfile(this.kind, this.name, this.icon, this.lead, this.actions);
  final ProKind kind;
  final String name;
  final IconData icon;
  final String lead;

  /// THE APP'S OWN COLOUR (2026-11-03): every assistant page is drawn in
  /// the theme accent, like the rest of the app — no per-profession tint.
  Color tint() => Neon.violet;
  final List<ProAction> actions;

  /// The profession's photo (assets/pro/, Pexels licence — see CREDITS.md).
  String get photo => 'assets/pro/${kind.name}.jpg';

  /// Where the photo is anchored in the hero: the advocate's (2026-11-03,
  /// supplied by the owner) is framed tight, so it keeps its very top.
  Alignment get photoAlign => kind == ProKind.advocate
      ? const Alignment(0, -1)
      : const Alignment(0, -0.7);

  /// Who the mic orb on the page talks as.
  AssistantRole get role => AssistantRole(
      "the $name Assistant",
      switch (kind) {
        ProKind.doctor => 'You help a doctor run their practice: patients\' '
            'files, notes and reports, follow-up visits, and payments and '
            'dues.',
        ProKind.advocate => 'You help an advocate in India: clients\' case '
            'files, hearings, Indian acts and sections, and drafting legal '
            'notices and letters.',
        ProKind.business => 'You help a business owner: customers and their '
            'files, income and spending, the record book, and messages to '
            'customers.',
      });

  static ProProfile of(ProKind k) => switch (k) {
        ProKind.doctor => ProProfile(
            k,
            "Doctor's",
            Icons.medical_services_rounded,
            'Your patients, their visits and dues, kept for you.',
            // REAL SCREENS, NOT CANNED QUESTIONS (2026-11-13): the clinic
            // workspace — today's appointments, follow-ups and payments —
            // each a tap away; the chat and mic orb stay for everything else.
            [
              ProAction('Today at clinic', 'Appointments, who is waiting, what is due',
                  Icons.today_rounded,
                  page: () => const ClinicScreen(), featured: true),
              ProAction('Patients', 'Each patient\'s file, notes and reports',
                  Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              ProAction('Book appointment', 'Pick a patient and a free time',
                  Icons.event_available_rounded,
                  run: (c) => bookAppointment(c)),
              ProAction('Follow-up visits', 'Recalls — patients get a reminder call',
                  Icons.event_repeat_rounded,
                  page: () => const ClinicScreen(initialTab: 1)),
              ProAction('Dues pending',
                  'Patients with payments still due', Icons.payments_rounded,
                  page: () => const ClinicScreen(initialTab: 2)),
              ProAction('Note a payment', 'Record what a patient paid',
                  Icons.receipt_long_rounded,
                  run: (c) => recordPayment(c)),
              // With "Today at clinic" as the wide card on top, this makes
              // six grid tiles — an even two-up grid, no orphan.
              ProAction('Clinic settings', 'Timings, fee, registration no.',
                  Icons.tune_rounded,
                  page: () => const ClinicSettingsScreen()),
            ],
          ),
        ProKind.advocate => ProProfile(
            k,
            "Advocate's",
            Icons.gavel_rounded,
            'Your cases, hearings and the law, at hand.',
            // THE ADVOCATE'S CHAMBERS (owner, 2026-11-14): real tools, like
            // the doctor's clinic — case diary, drafting, fees, bookings.
            [
              ProAction('Today in chambers', 'Hearings, consultations, fees due',
                  Icons.today_rounded,
                  page: () => const ClinicScreen(), featured: true),
              ProAction('Cases & hearings', 'Court, case no., next date',
                  Icons.gavel_rounded,
                  page: () => const CasesScreen()),
              ProAction('Clients', 'Each client\'s file, notes and papers',
                  Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              ProAction('Draft a document', 'Notice, affidavit, agreement → PDF',
                  Icons.edit_note_rounded,
                  page: () => const LegalDraftScreen()),
              ProAction('Book consultation', 'Pick a client and a free slot',
                  Icons.event_available_rounded,
                  run: (c) => bookAppointment(c)),
              ProAction('Fees pending', 'Who owes you, settle in a tap',
                  Icons.payments_rounded,
                  page: () => const ClinicScreen(initialTab: 2)),
              ProAction('Bill a fee', 'Fee invoice with a payment link',
                  Icons.receipt_long_rounded,
                  page: () => const InvoiceEditorScreen()),
            ],
          ),
        ProKind.business => ProProfile(
            k,
            'Business',
            Icons.business_center_rounded,
            'Your deals, clients, meetings and money — handled.',
            // THE EXECUTIVE DESK (owner, 2026-11-14: for top business
            // leaders): deals, invoices, receivables and meetings.
            [
              ProAction('Today at a glance', 'Meetings, follow-ups, receivables',
                  Icons.today_rounded,
                  page: () => const ClinicScreen(), featured: true),
              ProAction('Leads & deals', 'Pipeline and who to call next',
                  Icons.trending_up_rounded,
                  page: () => const LeadsScreen()),
              ProAction('Clients', 'Each client\'s file, notes and documents',
                  Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              ProAction('New invoice / quote', 'GST-ready PDF + payment link',
                  Icons.request_quote_rounded,
                  page: () => const InvoiceEditorScreen()),
              ProAction('Invoices & quotes', 'Paid, unpaid, payment links',
                  Icons.receipt_long_rounded,
                  page: () => const InvoicesScreen()),
              ProAction('Receivables', 'Who owes you, settle in a tap',
                  Icons.account_balance_wallet_rounded,
                  page: () => const ClinicScreen(initialTab: 2)),
              ProAction('Schedule meeting', 'Pick a client and a free slot',
                  Icons.event_available_rounded,
                  run: (c) => bookAppointment(c)),
            ],
          ),
      };
}

class ProAssistantScreen extends StatefulWidget {
  const ProAssistantScreen({super.key, required this.kind});
  final ProKind kind;

  @override
  State<ProAssistantScreen> createState() => _ProAssistantScreenState();
}

class _ProAssistantScreenState extends State<ProAssistantScreen> {
  ProKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    // The featured card shows the doctor's live day.
    if (Persona.proKind == kind.name) {
      ClinicService.instance.refresh(force: true);
    }
  }

  void _run(BuildContext context, ProAction a) {
    HapticFeedback.selectionClick();
    final run = a.run;
    if (run != null) {
      run(context);
      return;
    }
    final page = a.page;
    if (page != null) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => page()));
      return;
    }
    final ask = a.ask;
    if (ask == null) return;
    // A chat opens here, the question already asked (owner, 2026-11-02).
    _chat(context, first: ask);
  }

  /// Camera or gallery → saved to My documents → a NEW chat with this
  /// assistant, the photo at the top and the assistant asking what to do
  /// with it (owner, 2026-11-03).
  Future<void> _photo(BuildContext context) async {
    HapticFeedback.selectionClick();
    final doc = await uploadMyDocument(context, photosOnly: true);
    if (doc == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            ProChatScreen(profile: ProProfile.of(kind), photo: doc)));
  }

  void _chat(BuildContext context, {String? first}) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            ProChatScreen(profile: ProProfile.of(kind), first: first)));
  }

  /// YOUR OWN PHOTO (owner, 2026-11-14): take one, pick one, or go back to
  /// the default. Shown only to the professional whose assistant this is.
  Future<void> _editPhoto(BuildContext context) async {
    HapticFeedback.selectionClick();
    final custom = await ProPhoto.current(kind.name) != null;
    if (!context.mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Neon.textDim.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Your photo on this page',
                  style: NeonType.manrope(17, FontWeight.w800)
                      .copyWith(color: Neon.textHi)),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_rounded, color: Neon.violet),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: Neon.violet),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (custom)
              ListTile(
                leading: Icon(Icons.restart_alt_rounded, color: Neon.textLo),
                title: const Text('Use the default photo'),
                onTap: () => Navigator.pop(ctx, 'reset'),
              ),
          ]),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'reset') {
      await ProPhoto.reset(kind.name);
      AppFeedback.toast('Back to the default photo.');
      return;
    }
    final ok = await ProPhoto.pick(kind.name, camera: choice == 'camera');
    if (ok) AppFeedback.toast('Your photo is set.');
  }

  @override
  Widget build(BuildContext context) {
    final p = ProProfile.of(kind);
    final tint = p.tint();
    final top = MediaQuery.paddingOf(context).top;
    // Only the professional whose assistant this is may change its photo.
    final mine = Persona.proKind == kind.name;
    final featured = p.actions.where((a) => a.featured).toList();
    final grid = p.actions.where((a) => !a.featured).toList();
    // The hero shows the face whole: tall enough that the name and the
    // lead sit on the shoulders, below the chin, never over the face.
    final heroHeight =
        (MediaQuery.sizeOf(context).height * 0.46).clamp(340.0, 420.0);
    return Scaffold(
      backgroundColor: Neon.bg,
      body: CustomScrollView(
        slivers: [
          // THE HERO: the profession's photo (or the professional's own),
          // fading into the page, with the name and what it does over it.
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: heroHeight,
            backgroundColor: Neon.bg,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35)),
                child: const BackButton(color: Colors.white),
              ),
            ),
            actions: [
              if (mine)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
                  child: Tooltip(
                    message: 'Change photo',
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _editPhoto(context),
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.edit_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: LayoutBuilder(builder: (context, box) {
              // The small title shows only once the hero has scrolled away.
              final open = box.maxHeight > kToolbarHeight + top + 40;
              // How open the hero is, 1 = fully. The name, lead and orb
              // ride up with the hero's bottom edge and fade out as it
              // closes, instead of being sliced by it.
              final t = ((box.maxHeight - kToolbarHeight - top) /
                      (heroHeight - kToolbarHeight))
                  .clamp(0.0, 1.0);
              final textOpacity = ((t - 0.55) / 0.35).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    stretchModes: const [StretchMode.zoomBackground],
                    expandedTitleScale: 1,
                    titlePadding: const EdgeInsetsDirectional.only(
                        start: 64, bottom: 16, end: 16),
                    title: open
                        ? null
                        : Text('${p.name} Assistant',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(17, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProPhotoImage(profile: p),
                        // Clear over the face (the top ~55%), then into the
                        // page's own ground where the words sit; a light
                        // dark band at the very top keeps the back and edit
                        // buttons legible.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, 0.22, 0.55, 0.8, 1],
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.transparent,
                                Neon.bg.withValues(alpha: 0.88),
                                Neon.bg,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (textOpacity > 0)
                    Positioned(
                      left: 20,
                      right: 16,
                      bottom: 14,
                      child: Opacity(
                        opacity: textOpacity,
                        child: IgnorePointer(
                          ignoring: textOpacity < 0.5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                      tint.withValues(alpha: 0.22),
                                      Neon.surface),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: tint.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(p.icon, size: 14, color: tint),
                                    const SizedBox(width: 6),
                                    Text('ASSISTANT',
                                        style: NeonType.manrope(
                                                11, FontWeight.w800)
                                            .copyWith(
                                                color: Neon.textHi,
                                                letterSpacing: 1.4)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: NeonType.manrope(
                                                    34, FontWeight.w800)
                                                .copyWith(
                                                    color: Neon.textHi,
                                                    letterSpacing: -0.6,
                                                    height: 1.05)),
                                        const SizedBox(height: 6),
                                        Text(p.lead,
                                            style: NeonType.manrope(
                                                    15, FontWeight.w600)
                                                .copyWith(
                                                    color: Neon.textLo,
                                                    height: 1.35)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _PhotoButton(
                                      tint: tint, onTap: () => _photo(context)),
                                  const SizedBox(width: 12),
                                  RoleMicOrb(
                                      role: p.role, tint: tint, size: 56),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          // TODAY FIRST (2026-11-14): the featured action as one wide card
          // with the day's live numbers, then the rest as an even grid.
          if (featured.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _FeaturedCard(
                  action: featured.first,
                  tint: tint,
                  showClinicDay: Persona.proKind == kind.name,
                  onTap: () => _run(context, featured.first),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                    featured.isNotEmpty ? 'QUICK ACTIONS' : 'WHAT I CAN DO',
                    style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
              ),
            ),
          ),
          // Two even tiles a row: same height everywhere, so the grid reads
          // as one set instead of a staircase of cards.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              itemCount: grid.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 128,
              ),
              itemBuilder: (_, i) => _ActionCard(
                  action: grid[i],
                  tint: tint,
                  onTap: () => _run(context, grid[i])),
            ),
          ),
          // YOUR PUBLIC PAGE (2026-11-14): be found nearby and on Google.
          // Only on the professional's OWN page (the server gates it too).
          if (Persona.proKind == kind.name)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: PublicPageCard(tint: tint, kind: kind),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 24, 16, 24 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverToBoxAdapter(
              child: _AskCard(
                profile: p,
                tint: tint,
                onOpen: ({String? first}) => _chat(context, first: first),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The profession's photo — or the professional's own, once they set one
/// (ProPhoto). Used by the page's hero and the Home banner alike.
class ProPhotoImage extends StatelessWidget {
  const ProPhotoImage({super.key, required this.profile, this.alignment});
  final ProProfile profile;

  /// Defaults to the stock photo's framing; an own photo is centred a
  /// little high, where a face usually is.
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ProPhoto.version,
      builder: (_, v, __) => FutureBuilder<File?>(
        key: ValueKey(v),
        future: ProPhoto.current(profile.kind.name),
        builder: (_, snap) {
          final own = snap.data;
          if (own != null) {
            return Image.file(own,
                fit: BoxFit.cover,
                alignment: alignment ?? const Alignment(0, -0.35),
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true);
          }
          return Image.asset(profile.photo,
              fit: BoxFit.cover,
              alignment: alignment ?? profile.photoAlign,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true);
        },
      ),
    );
  }
}

/// The camera beside the mic orb: the same size and the same caption
/// line, so the two read as a pair.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.tint, required this.onTap});
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a photo — take one or choose from gallery',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: documentUploading,
              builder: (_, busy, __) => Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Neon.glassFill,
                  border: Border.all(
                      color: tint.withValues(alpha: 0.7), width: 1.4),
                  boxShadow: Neon.halo(tint, strength: 0.5),
                ),
                child: busy
                    ? const Center(
                        child: NeonLoader.inline(semanticLabel: 'Uploading'))
                    : Icon(Icons.photo_camera_rounded,
                        color: Neon.textHi, size: 24),
              ),
            ),
            const SizedBox(height: 4),
            Text('Add photo',
                style: TextStyle(
                    color: Neon.textHi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// The page's lead card: the featured action, wide, with — for a doctor —
/// today's live numbers (patients to see, follow-ups, money pending).
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.action,
    required this.tint,
    required this.showClinicDay,
    required this.onTap,
  });
  final ProAction action;
  final Color tint;
  final bool showClinicDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(22);
    return Semantics(
      button: true,
      label: '${action.title}. ${action.detail}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                      tint.withValues(alpha: 0.30), Neon.glassFill.colors.first),
                  Color.alphaBlend(
                      tint.withValues(alpha: 0.08), Neon.glassFill.colors.last),
                ],
              ),
              border: Border.all(color: tint.withValues(alpha: 0.45)),
              boxShadow: Neon.halo(tint, strength: 0.35),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [
                        Color.lerp(tint, Colors.white, 0.15)!,
                        tint,
                      ]),
                    ),
                    child: Icon(action.icon, color: Colors.white, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action.title,
                            style: NeonType.manrope(18, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                        const SizedBox(height: 2),
                        Text(action.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Neon.textLo, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded,
                      color: Neon.textHi, size: 20),
                ]),
                if (showClinicDay) ...[
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: ClinicService.instance,
                    builder: (_, __) {
                      final t = ClinicService.instance.today;
                      final money = t == null ? '–' : rupees(t.duesTotal);
                      final owed = (t?.duesTotal ?? 0) > 0;
                      // Each profession's three numbers that matter today.
                      final stats = switch (Persona.value) {
                        'advocate' => [
                            _Stat(t?.hearingsToday.length.toString() ?? '–', 'hearings today', tint,
                                alert: (t?.hearingsToday.isNotEmpty ?? false)),
                            _Stat(t?.hearingsWeek.length.toString() ?? '–', 'this week', tint),
                            _Stat(money, 'fees due', tint, alert: owed),
                          ],
                        'business' => [
                            _Stat(t?.openAppointments.length.toString() ?? '–', 'meetings', tint),
                            _Stat(t?.leadsDue.length.toString() ?? '–', 'follow-ups', tint,
                                alert: (t?.leadsDue.isNotEmpty ?? false)),
                            _Stat(money, 'receivable', tint, alert: owed),
                          ],
                        _ => [
                            _Stat(t?.openAppointments.length.toString() ?? '–', 'to see', tint),
                            _Stat(
                                t == null
                                    ? '–'
                                    : (t.followUps.today.length + t.followUps.overdue.length).toString(),
                                'follow-ups',
                                tint,
                                alert: (t?.followUps.overdue.isNotEmpty ?? false)),
                            _Stat(money, 'pending', tint, alert: owed),
                          ],
                      };
                      return Row(children: [
                        stats[0],
                        const SizedBox(width: 8),
                        stats[1],
                        const SizedBox(width: 8),
                        stats[2],
                      ]);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.tint, {this.alert = false});
  final String value;
  final String label;
  final Color tint;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: Neon.isDark ? 0.22 : 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: NeonType.manrope(18, FontWeight.w800).copyWith(
                      color: alert ? Neon.warning : Neon.textHi)),
            ),
            Text(label,
                style: TextStyle(color: Neon.textLo, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

/// One thing the assistant does: an even tile — the icon in a rounded
/// square, the name and one line; an arrow when it opens something, a chat
/// bubble only when it hands a question to the assistant.
class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.action, required this.tint, required this.onTap});
  final ProAction action;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = action;
    final asks = a.page == null && a.run == null;
    final r = BorderRadius.circular(20);
    return Semantics(
      button: true,
      label: '${a.title}. ${a.detail}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(tint.withValues(alpha: 0.10),
                      Neon.glassFill.colors.first),
                  Neon.glassFill.colors.last,
                ],
              ),
              border: Border.all(color: Neon.glassEdge.first),
              boxShadow: Neon.glassShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: tint.withValues(alpha: 0.18),
                      ),
                      child: Icon(a.icon, color: tint, size: 20),
                    ),
                    const Spacer(),
                    Icon(
                        asks
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.arrow_forward_rounded,
                        color: Neon.textDim,
                        size: 17),
                  ],
                ),
                const Spacer(),
                Text(a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeonType.manrope(14.5, FontWeight.w800)
                        .copyWith(color: Neon.textHi, height: 1.2)),
                const SizedBox(height: 2),
                Text(a.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Neon.textLo, fontSize: 12, height: 1.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ASK YOUR ASSISTANT (2026-11-14, replacing the plain "Chat with…" bar):
/// the assistant's face with an online dot, a message box that opens the
/// chat, and a few one-tap questions for this profession.
class _AskCard extends StatelessWidget {
  const _AskCard(
      {required this.profile, required this.tint, required this.onOpen});
  final ProProfile profile;
  final Color tint;
  final void Function({String? first}) onOpen;

  List<(IconData, String, String)> get _prompts => switch (profile.kind) {
        ProKind.doctor => const [
            (Icons.today_rounded, "Who's due today?",
                'Which patients are due today, and who is overdue?'),
            (Icons.note_add_rounded, 'Add a note',
                'I want to add a note to a patient\'s file.'),
            (Icons.payments_rounded, 'Who owes me?',
                'Which of my patients have dues pending?'),
          ],
        ProKind.advocate => const [
            (Icons.event_note_rounded, 'Hearings this week',
                'What hearings do I have coming up this week?'),
            (Icons.summarize_rounded, 'Summarise a case',
                'Summarise one of my client\'s case files for me.'),
            (Icons.gavel_rounded, 'Explain a judgment',
                'Explain a court judgment to me in simple words.'),
          ],
        ProKind.business => const [
            (Icons.today_rounded, 'My day',
                'Brief me on my day: meetings, follow-ups due and money to collect.'),
            (Icons.payments_rounded, 'Who owes me?',
                'Which customers still owe me money?'),
            (Icons.trending_up_rounded, 'Pipeline summary',
                'Summarise my open deals: value, stage and who to call next.'),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(24);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                tint.withValues(alpha: 0.16), Neon.glassFill.colors.first),
            Neon.glassFill.colors.last,
          ],
        ),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
        boxShadow: Neon.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            // The assistant's face, with the "available" dot.
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tint, width: 2),
                ),
                child: ClipOval(child: ProPhotoImage(profile: profile)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Neon.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Neon.surface, width: 2),
                  ),
                ),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask your assistant',
                      style: NeonType.manrope(17, FontWeight.w800)
                          .copyWith(color: Neon.textHi)),
                  const SizedBox(height: 2),
                  Text('Type or talk — it knows your ${switch (profile.kind) {
                    ProKind.doctor => 'patients',
                    ProKind.advocate => 'cases',
                    ProKind.business => 'clients',
                  }}.',
                      style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // A message box that opens the chat — the familiar way to start.
          Semantics(
            button: true,
            label: 'Chat with the ${profile.name} Assistant',
            excludeSemantics: true,
            child: Material(
              color: Colors.black.withValues(alpha: Neon.isDark ? 0.25 : 0.05),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onOpen(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                  child: Row(children: [
                    Expanded(
                      child: Text('Message ${profile.name} Assistant…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Neon.textDim, fontSize: 14.5)),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          Color.lerp(Neon.accentFill, Colors.white, 0.12)!,
                          Neon.accentFill,
                        ]),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, label, ask) in _prompts)
                ActionChip(
                  avatar: Icon(icon, size: 16, color: tint),
                  label: Text(label),
                  labelStyle: TextStyle(
                      color: Neon.textHi,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                  backgroundColor: tint.withValues(alpha: 0.12),
                  side: BorderSide(color: tint.withValues(alpha: 0.35)),
                  shape: const StadiumBorder(),
                  onPressed: () => onOpen(first: ask),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// THE ASSISTANT'S CHAT, ON THE PAGE (owner, 2026-11-02: "when I click it
/// comes to the Home page; instead a new chat should open there and work
/// end to end"). A typed conversation with the assistant — the same brain,
/// tools and confirmations as everywhere else (AssistantEngine.
/// sendTypedMessage) — shown as bubbles from when this chat opened. The
/// first message is the action's question; the owner types the rest.
class ProChatScreen extends StatefulWidget {
  const ProChatScreen(
      {super.key, required this.profile, this.first, this.photo});
  final ProProfile profile;
  final String? first;

  /// A photo the user just added: the chat opens on it, asking what to do.
  final UserDocument? photo;

  @override
  State<ProChatScreen> createState() => _ProChatScreenState();
}

class _ProChatScreenState extends State<ProChatScreen> {
  final _engine = AssistantEngine.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final int _from = _engine.transcript.length;
  bool _sending = false;

  /// VOICE TYPING (2026-11-03): the mic in the message box writes what is
  /// said into it, live; nothing is sent until the user taps send. The
  /// same listener as the rest of the app (on-device recogniser first).
  VoiceListener? _listener;
  VoiceListener get _voice =>
      _listener ??= VoiceListener.standard(ModelPorts.cloud());
  bool _dictating = false;
  final _level = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _engine.addListener(_changed);
    _photo = widget.photo;
    final first = widget.first;
    if (first != null && first.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(first));
    }
  }

  @override
  void dispose() {
    _engine.removeListener(_changed);
    unawaited(_listener?.cancel().catchError((_) {}));
    _level.dispose();
    _inputFocus.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  /// Tap to start: what is said is added after whatever is already typed.
  /// Tap again to stop early; a pause in speech also ends it.
  Future<void> _toggleDictation() async {
    if (_dictating) {
      HapticFeedback.selectionClick();
      await _voice.stop();
      return;
    }
    HapticFeedback.mediumImpact();
    final before = _input.text.trimRight();
    final lead = before.isEmpty ? '' : '$before ';
    void show(String words) {
      final t = '$lead${words.trim()}';
      _input.value = TextEditingValue(
          text: t, selection: TextSelection.collapsed(offset: t.length));
    }

    setState(() => _dictating = true);
    var failed = '';
    try {
      // Dictation, not a command: longer pauses are allowed mid-thought.
      await for (final e in _voice.listen(
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(milliseconds: 2500))) {
        if (!mounted) break;
        switch (e) {
          case HearPartial(:final text):
            show(text);
          case HearFinal(:final text):
            if (text.trim().isNotEmpty) show(text);
          case HearLevel(:final level):
            _level.value = level;
          case HearError(:final code):
            failed = code;
          case HearEndOfSpeech():
            break;
        }
      }
    } catch (e) {
      failed = '$e';
    }
    if (!mounted) return;
    _level.value = 0;
    setState(() => _dictating = false);
    if (failed.isNotEmpty) {
      AppFeedback.toast(failed == 'permission'
          ? 'Allow the microphone to use voice typing.'
          : "Couldn't hear that — try again, or type it.");
    }
  }

  /// The photo this chat is about (shown at the top, with the assistant's
  /// question under it).
  UserDocument? _photo;

  /// True until the user has said something about [_photo]: their first
  /// message carries its title, which is how the assistant finds it.
  bool _photoPending = true;
  final _inputFocus = FocusNode();

  Future<void> _send(String text) async {
    var t = text.trim();
    if (t.isEmpty || _sending) return;
    final photo = _photo;
    if (photo != null && _photoPending) {
      t = 'About the photo I just added ("${photo.title}"): $t';
      _photoPending = false;
    }
    if (_dictating) unawaited(_voice.cancel().catchError((_) {}));
    HapticFeedback.selectionClick();
    _input.clear();
    setState(() => _sending = true);
    try {
      await _engine.sendTypedMessage(t);
    } catch (_) {
      // The engine puts its own error line in the conversation.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Saves a photo or file, then starts the question about it — the title
  /// is how the assistant finds the document among the user's saved ones.
  Future<void> _attach() async {
    final doc = await uploadMyDocument(context);
    if (doc == null || !mounted) return;
    setState(() {
      _photo = doc;
      _photoPending = true;
    });
    _inputFocus.requestFocus();
  }

  List<TranscriptEntry> get _lines {
    final all = _engine.transcript;
    final from = _from.clamp(0, all.length);
    return [
      for (final e in all.sublist(from))
        if (e.role != TranscriptRole.system && e.text.trim().isNotEmpty) e
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final tint = p.tint();
    final lines = _lines;
    final working = _sending || _engine.phase.busy;
    final doing = _engine.activityLabel.value;
    final ask = _engine.pendingConfirmation;
    return NeonScaffold(
      appBar: appleAppBar(context, '${p.name} Assistant'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: lines.isEmpty && !working && _photo == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p.icon, color: tint, size: 40),
                            const SizedBox(height: 12),
                            Text('Ask anything about your work.',
                                textAlign: TextAlign.center,
                                style: NeonType.manrope(16, FontWeight.w700)
                                    .copyWith(color: Neon.textHi)),
                            const SizedBox(height: 4),
                            Text(p.lead,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Neon.textLo)),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      children: [
                        if (_photo != null) ..._photoHeader(_photo!),
                        for (final e in lines) _bubble(e, tint),
                        if (working)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Row(
                              children: [
                                const NeonLoader.inline(
                                    size: 14, semanticLabel: 'Working'),
                                const SizedBox(width: 10),
                                Text(doing ?? 'Working on it…',
                                    style: TextStyle(
                                        color: Neon.textLo,
                                        fontSize: NeonType.footnote)),
                              ],
                            ),
                          ),
                        if (ask != null)
                          _confirmCard(
                              ask.question ?? 'Shall I go ahead?', tint),
                      ],
                    ),
            ),
            _composer(tint),
          ],
        ),
      ),
    );
  }

  /// The photo, as the user's own message, and the assistant asking what
  /// to do with it — the start of a chat about a picture.
  List<Widget> _photoHeader(UserDocument d) => [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.62,
                maxHeight: 260),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Neon.accentFill, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: d.mime.startsWith('image/')
                  ? Image.network(ApiService.documentFileUrl(d.id),
                      headers: ApiService.imageHeaders,
                      fit: BoxFit.cover,
                      cacheWidth: 700)
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(d.title,
                          style: TextStyle(color: Neon.textHi))),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.8),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              color: Neon.surface,
              border: Border.all(color: Neon.glassEdge.first),
            ),
            child: Text(
                'Got your photo. What would you like me to do with it? '
                'Ask me to read it, explain it, or file it.',
                style: TextStyle(
                    color: Neon.textHi,
                    fontSize: NeonType.rowTitle,
                    height: 1.45)),
          ),
        ),
      ];

  Widget _bubble(TranscriptEntry e, Color tint) {
    final mine = e.role == TranscriptRole.user;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          // Light premium (2026-11-02): yours in solid violet, the
          // assistant's on a raised card — both themes.
          color: mine ? Neon.accentFill : Neon.surface,
          border: mine ? null : Border.all(color: Neon.glassEdge.first),
          boxShadow: mine ? null : Neon.halo(Neon.violet, strength: 0.5),
        ),
        child: SelectableText(
          e.text,
          style: TextStyle(
              color: mine ? Colors.white : Neon.textHi,
              fontSize: NeonType.rowTitle,
              height: 1.45),
        ),
      ),
    );
  }

  Widget _confirmCard(String question, Color tint) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Neon.surface,
          border: Border.all(color: Neon.violet.withValues(alpha: 0.35)),
          boxShadow: Neon.halo(Neon.violet, strength: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question,
                style: NeonType.manrope(15, FontWeight.w700)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => _engine.confirm(false),
                    child: const Text('No')),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: () => _engine.confirm(true),
                    child: const Text('Yes, go ahead')),
              ],
            ),
          ],
        ),
      );

  /// The mic inside the message box: violet when idle, a pulsing stop
  /// while it is writing down what is said.
  Widget _dictateButton() => ValueListenableBuilder<double>(
        valueListenable: _level,
        builder: (_, level, __) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            key: const ValueKey('pro-chat-dictate'),
            tooltip: _dictating ? 'Stop voice typing' : 'Voice typing',
            onPressed: _sending ? null : _toggleDictation,
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dictating
                    ? Neon.accentFill
                    : Neon.violet.withValues(alpha: 0.12),
                boxShadow: _dictating
                    ? [
                        BoxShadow(
                            color: Neon.accentFill.withValues(alpha: 0.55),
                            blurRadius: 6 + 18 * level,
                            spreadRadius: 1 + 5 * level)
                      ]
                    : null,
              ),
              child: Icon(
                  _dictating ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 20,
                  color: _dictating ? Colors.white : Neon.violet),
            ),
          ),
        ),
      );

  /// Raised round controls on the page (light premium, 2026-11-02).
  BoxDecoration get _raised => BoxDecoration(
        shape: BoxShape.circle,
        color: Neon.surface,
        border: Border.all(color: Neon.glassEdge.first),
        boxShadow: Neon.halo(Neon.violet, strength: 0.6),
      );

  Widget _composer(Color tint) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // A photo or file to ask about (owner, 2026-11-02): saved to My
            // documents, then the question box names it for the assistant.
            DecoratedBox(
              decoration: _raised,
              child: ValueListenableBuilder<bool>(
                valueListenable: documentUploading,
                builder: (context, busy, _) => IconButton(
                  tooltip: busy ? 'Uploading' : 'Attach a photo or file',
                  constraints:
                      const BoxConstraints.tightFor(width: 50, height: 50),
                  onPressed: busy ? null : _attach,
                  icon: busy
                      ? const NeonLoader.inline(semanticLabel: 'Uploading')
                      : Icon(Icons.attach_file_rounded, color: Neon.violet),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Neon.surface,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Neon.glassEdge.first),
                  boxShadow: Neon.halo(Neon.violet, strength: 0.6),
                ),
                child: TextField(
                  key: const ValueKey('pro-chat-input'),
                  controller: _input,
                  focusNode: _inputFocus,
                  // A chat opened on a photo waits for the user's words.
                  autofocus: widget.photo != null,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  style: TextStyle(
                      color: Neon.textHi, fontSize: NeonType.rowTitle),
                  decoration: InputDecoration(
                    hintText: _dictating ? 'Listening…' : 'Type or speak',
                    hintStyle: TextStyle(color: Neon.textDim),
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(18, 14, 4, 14),
                    suffixIcon: _dictateButton(),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.5),
                  radius: 1.1,
                  colors: [
                    Color.lerp(Neon.accentFill, Colors.white, 0.10)!,
                    Color.lerp(Neon.accentFill, Colors.black, 0.18)!,
                  ],
                ),
                boxShadow: Neon.halo(Neon.violet, strength: 0.9),
              ),
              child: IconButton(
                tooltip: 'Send',
                constraints:
                    const BoxConstraints.tightFor(width: 50, height: 50),
                onPressed: () => _send(_input.text),
                icon:
                    const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      );
}

/// YOUR PUBLIC PAGE: live or not, visits, new booking requests — one tap
/// to the page editor. Loads once when the page opens.
class PublicPageCard extends StatefulWidget {
  const PublicPageCard({super.key, required this.tint, required this.kind});
  final Color tint;
  final ProKind kind;

  @override
  State<PublicPageCard> createState() => _PublicPageCardState();
}

class _PublicPageCardState extends State<PublicPageCard> {
  @override
  void initState() {
    super.initState();
    ListingService.instance.load();
  }

  String get _place => switch (widget.kind) {
        ProKind.doctor => 'clinic',
        ProKind.advocate => 'chambers',
        ProKind.business => 'business',
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ListingService.instance.state,
      builder: (context, s, _) {
        final live = s?.listing.published == true;
        final requests = s?.newRequests ?? 0;
        final tint = live ? Neon.success : widget.tint;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => MyListingScreen(initialTab: requests > 0 ? 2 : 0)));
              ListingService.instance.load();
            },
            child: Ink(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Color.alphaBlend(tint.withValues(alpha: 0.10), Neon.surface),
                border: Border.all(color: tint.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: tint.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                  child: Icon(live ? Icons.public_rounded : Icons.campaign_rounded, color: tint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(live ? 'Your public page' : 'Put your $_place on the map',
                        style: NeonType.manrope(16, FontWeight.w800).copyWith(color: Neon.textHi)),
                    const SizedBox(height: 2),
                    Text(listingCardLine(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: requests > 0 ? Neon.warning : Neon.textLo, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (requests > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Neon.warning, borderRadius: BorderRadius.circular(999)),
                    child: Text('$requests', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                Icon(Icons.chevron_right_rounded, color: Neon.textLo),
              ]),
            ),
          ),
        );
      },
    );
  }
}
