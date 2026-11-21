import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ai/config.dart';
import '../ai/live_voice.dart';
import '../design/accent_controller.dart';
import '../features/home/home_memory.dart';
import '../design/apple_kit.dart';
import '../design/dock_metrics.dart';
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';
import '../design/theme_controller.dart';
import '../services/voice_choice.dart';
import '../services/api_service.dart';
import '../services/assistant_identity.dart';
import 'account_section.dart';
import '../features/premium/premium_screen.dart';
import 'app_lock_section.dart';
import 'theme_colour_screen.dart';
import 'voice_picker_screen.dart';
import 'avatar_identity_screen.dart';
import 'memory_screen.dart';
import 'overlay_section.dart';
import '../services/app_feedback.dart';
import '../features/widgets/widget_picker.dart';
import '../features/home/horoscope_card.dart';
import '../services/horoscope.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  ASSISTANT SETTINGS — how the assistant sounds and looks, plus the
///  user's standing rules.
///
///  Deliberately NO name field and NO style dropdown: identity is set by
///  TALKING ("your name is Maya from now on") — the conversation is the
///  interface. Everything left on this page saves the moment it's tapped;
///  there is no Save button to forget.
/// ─────────────────────────────────────────────────────────────────────────
class AssistantSettingsScreen extends StatefulWidget {
  const AssistantSettingsScreen({super.key});

  @override
  State<AssistantSettingsScreen> createState() =>
      _AssistantSettingsScreenState();
}

class _AssistantSettingsScreenState extends State<AssistantSettingsScreen> {
  String _voice = 'gleam';
  List<dynamic> _rules = [];
  final _newRule = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(Horoscope.load());
  }

  @override
  void dispose() {
    _newRule.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await LiveVoicePrefs.load();
    // Side by side, not one after another: the tab opened on sequential
    // round-trips.
    final results = await Future.wait([
      ApiService.getJson('/profile/full'),
      ApiService.getJson('/profile/instructions'),
    ]);
    final p = results[0];
    final r = results[1];
    if (!mounted) return;
    setState(() {
      _loading = false;
      final a = (p?['assistant'] as Map?) ?? {};
      final offered = AiConfigStore.instance.current.live.voices
          .map((v) => v.toLowerCase())
          .toSet();
      final chosen = LiveVoicePrefs.chosenVoice?.trim().toLowerCase();
      final profileVoice = (a['voice'] as String?)?.trim().toLowerCase();
      final configured =
          AiConfigStore.instance.current.live.voice.toLowerCase();
      _voice = [
        chosen,
        profileVoice,
        configured,
      ].whereType<String>().firstWhere(
            (v) => offered.contains(v),
            orElse: () => configured.isNotEmpty ? configured : 'marin',
          );
      _rules = (r?['instructions'] as List?) ?? [];
    });
  }

  String _voiceName(String id) {
    if (id.isEmpty) return 'Default';
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }

  Future<void> _pickVoice(String v) async {
    HapticFeedback.selectionClick();
    final prev = _voice;
    setState(() => _voice = v);
    // Saved on the phone and the server; the next conversation is in it.
    final why = await VoiceChoice.save(v);
    if (!mounted) return;
    if (why != null) {
      setState(() => _voice = prev);
      // The server explains a mismatch in a sentence the user can act on
      // — show THAT, not a generic failure.
      AppFeedback.show(why, context: context, tone: FeedbackTone.error);
      return;
    }
  }

  Future<void> _addRule() async {
    final t = _newRule.text.trim();
    if (t.isEmpty) return;
    await ApiService.sendJson('/profile/instructions',
        method: 'POST', body: {'instruction': t});
    _newRule.clear();
    await _load();
  }

  Future<void> _removeRule(int id) async {
    await ApiService.sendJson('/profile/instructions/$id', method: 'DELETE');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    // As the You TAB it wears the same large title as Hub and Chat — a
    // small centred "Assistant" bar under a tab labelled "You" read as a
    // different screen from the one tapped. Pushed on its own (from
    // Diagnostics) it keeps a normal app bar with a back arrow.
    final pushed = ModalRoute.of(context)?.canPop ?? false;
    // UNDER THE SAME SKY (2026-09-30): as the You tab it is clear, so the
    // shell's sky shows through as it does on Hub (a flat Neon.bg hid it
    // on this one tab); pushed, it brings its own (NeonScaffold).
    final body = SafeArea(
      top: !pushed,
      bottom: false,
      child: _loading
          ? const NeonLoader.page(semanticLabel: 'Loading your settings')
          : ListView(
              // Clears the dock and the mic on every phone.
              padding: EdgeInsets.fromLTRB(
                  16, pushed ? 8 : 18, 16, Dock.clearance(context)),
              children: [
                if (!pushed) const LargeTitle('You'),
                // Identity lives in the conversation, and the page says so.
                // Live: renaming by voice updates this card too.
                // The one lit card on the page (2026-09-30): who the
                // assistant is, in the brand's own light; every group
                // below is a calm rim.
                ValueListenableBuilder<String>(
                  valueListenable: AssistantIdentity.notifier,
                  builder: (_, n, __) => GlowCard(
                    halo: 0.5,
                    child: AppleRow(
                      leading: IconTile(
                          Icons.auto_awesome_rounded, AppleColors.purple),
                      title: n,
                      subtitle: 'To rename your assistant, say "your name is '
                          'Maya from now on".',
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // PREMIUM (2026-11-12): plans, the free trial and credits.
                GroupedCard(
                  dividerInset: 60,
                  children: [
                    AppleRow(
                      leading: IconTile(
                          Icons.workspace_premium_rounded, AppleColors.purple),
                      title: 'MyAssistant Premium',
                      subtitle: 'Try Pro free for 14 days',
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: Neon.textDim, size: 20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PremiumScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // MEMORY (2026-10-19): what the assistant has learned about
                // them, to review and remove.
                const GroupLabel('Memory'),
                GroupedCard(
                  dividerInset: 60,
                  children: [
                    AppleRow(
                      leading: IconTile(
                          Icons.psychology_rounded, AppleColors.indigo),
                      title: 'Stored Memories',
                      subtitle: 'What your assistant knows about you',
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: Neon.textDim, size: 20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const MemoryScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // OVER OTHER APPS (2026-10-19): notification pop-ups and the
                // floating mic.
                const OverlaySection(),

                const GroupLabel('Appearance'),
                ValueListenableBuilder<ThemeMode3>(
                  valueListenable: ThemeController.mode,
                  builder: (_, mode, __) => GroupedCard(
                    dividerInset: 60,
                    children: [
                      // LIGHT / DARK (2026-11-03): one switch, applied at
                      // once and remembered. Adaptive was removed.
                      AppleRow(
                        leading: IconTile(
                            mode == ThemeMode3.dark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            AppleColors.indigo),
                        title: 'Dark Mode',
                        subtitle: mode == ThemeMode3.dark
                            ? 'On · dark appearance'
                            : 'Off · light appearance',
                        trailing: Switch(
                          value: mode == ThemeMode3.dark,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            ThemeController.setMode(
                                v ? ThemeMode3.dark : ThemeMode3.light);
                          },
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ThemeController.toggle();
                        },
                      ),
                      // In the Appearance card (2026-09-24): it floated
                      // 10 dp under it as a card with no label of its own.
                      AppleRow(
                        leading:
                            IconTile(Icons.palette_rounded, AppleColors.purple),
                        title: 'Theme Colour',
                        subtitle: 'Applied to the orb, microphone, and highlights',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<Color>(
                              valueListenable: AccentController.seed,
                              builder: (_, seed, __) => Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: Neon.tile(seed),
                                  border: Border.all(color: Neon.line),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded,
                                color: Neon.textDim, size: 20),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ThemeColourScreen()),
                        ),
                      ),
                      // TODAY'S HOROSCOPE (owner, 2026-11-15): the sign Home reads.
                      ValueListenableBuilder<ZodiacSign?>(
                        valueListenable: Horoscope.current,
                        builder: (_, sign, __) => AppleRow(
                          leading: IconTile(
                              Icons.auto_awesome_rounded, AppleColors.indigo),
                          title: 'Zodiac Sign',
                          subtitle: sign == null
                              ? 'Select a sign for your daily horoscope'
                              : '${sign.symbol} ${sign.name} · ${sign.dates}',
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: Neon.textDim, size: 20),
                          onTap: () => pickZodiacSign(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Home's headlines (2026-09-30): a card of two when there is
                // room under what is personal; the card's ✕ turns it off.
                const GroupLabel('Home'),
                ValueListenableBuilder<bool>(
                  valueListenable: HomeMemory.instance.newsOn,
                  builder: (_, on, __) => GroupedCard(
                    dividerInset: 60,
                    children: [
                      AppleRow(
                        leading:
                            IconTile(Icons.newspaper_rounded, AppleColors.blue),
                        title: 'News on Home',
                        subtitle:
                            'Two headlines from your preferred topic, space permitting',
                        trailing: Switch(
                          value: on,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            HomeMemory.instance.setNewsOn(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ONE VOICE CARD (2026-09-24). "ASSISTANT VOICE" sat over a
                // row called "Assistant voice", and "RECOGNISE MY VOICE"
                // over "Voice ID": a label per row, each repeating it.
                const GroupLabel('Voice'),
                GroupedCard(
                  dividerInset: 60,
                  children: [
                    AppleRow(
                      leading:
                          IconTile(Icons.graphic_eq_rounded, AppleColors.teal),
                      title: 'Assistant Voice',
                      subtitle: 'Preview and choose a voice',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _voiceName(_voice),
                            style: TextStyle(
                                color: Neon.textLo,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded,
                              color: Neon.textDim, size: 20),
                        ],
                      ),
                      onTap: () async {
                        final picked = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => VoicePickerScreen(
                              selectedId: _voice,
                            ),
                          ),
                        );
                        if (picked != null && mounted) await _pickVoice(picked);
                      },
                    ),
                    // "Live captions" was here: a switch nothing read
                    // (captions always show in the voice overlay),
                    // describing a conversation screen that no longer
                    // exists.
                    // "Voice ID" and "Respond only to my voice" were here
                    // (2026-09-29). Since the phone's own speech recogniser
                    // hears the owner, no audio reaches a voiceprint check,
                    // so the promise "answers only you" was no longer true.
                    // The voiceprint service and its 28 MB model were
                    // removed on 2026-10-01 (nothing streamed audio to it).
                  ],
                ),
                const SizedBox(height: 24),

                const GroupLabel('Your Avatar Identity'),
                GroupedCard(
                  dividerInset: 60,
                  children: [
                    AppleRow(
                      leading: IconTile(
                          Icons.video_camera_front_rounded, AppleColors.green),
                      title: 'Send Messages as You',
                      subtitle: 'Your face and voice on messages you send, '
                          'with your consent.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AvatarIdentityScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const GroupLabel('Standing Rules'),
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    'Permanent instructions the assistant follows before every '
                    'decision, e.g. "Always ask before sending messages", '
                    '"Address me by my first name". You can also state these in '
                    'conversation.',
                    // textLo: textDim fell under 4.5:1 on the ambient wash.
                    style: TextStyle(
                        color: Neon.textLo, fontSize: NeonType.footnote),
                  ),
                ),
                if (_rules.isNotEmpty) ...[
                  GroupedCard(
                    children: [
                      for (final r in _rules)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                          child: Row(children: [
                            Expanded(
                                child: Text(r['instruction'] ?? '',
                                    style: TextStyle(color: Neon.textLo))),
                            IconButton(
                              tooltip: 'Remove Rule',
                              icon: Icon(Icons.close_rounded,
                                  size: 18, color: Neon.textDim),
                              onPressed: () => _removeRule(r['id'] as int),
                            ),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _newRule,
                      style: TextStyle(color: Neon.textHi),
                      decoration: _dec('Add a Rule', 'Always…'),
                      onSubmitted: (_) => _addRule(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                      tooltip: 'Add Rule',
                      onPressed: _addRule,
                      icon: Icon(Icons.add_circle_rounded, color: Neon.violet)),
                ]),
                const SizedBox(height: 24),

                const AppLockSection(),
                const SizedBox(height: 24),

                const AccountSection(),
                const SizedBox(height: 24),

                // HOME-SCREEN WIDGETS (2026-11-08): the picker the app
                // offers once on opening, for whoever said "Not now".
                const GroupLabel('Home Screen'),
                GroupedCard(
                  dividerInset: 60,
                  children: [
                    AppleRow(
                      leading: IconTile(Icons.widgets_rounded, AppleColors.purple),
                      title: 'Home-Screen Widgets',
                      subtitle: 'Ask Bar, My Day, Shortcuts, and Orb',
                      onTap: () => showWidgetPicker(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const GroupLabel('About & Legal'),
                GroupedCard(
                  children: [
                    _legalRow('Privacy Policy', '/legal/privacy'),
                    _legalRow('Terms & Conditions', '/legal/terms'),
                  ],
                ),
              ],
            ),
    );
    if (pushed) {
      return NeonScaffold(appBar: appleAppBar(context, 'Settings'), body: body);
    }
    return Scaffold(backgroundColor: Colors.transparent, body: body);
  }

  Widget _legalRow(String label, String path) => AppleRow(
        title: label,
        trailing:
            Icon(Icons.open_in_new_rounded, size: 16, color: Neon.textDim),
        onTap: () => launchUrl(Uri.parse('${ApiService.baseUrl}$path'),
            mode: LaunchMode.externalApplication),
      );

  InputDecoration _dec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Neon.textLo),
        hintStyle: TextStyle(color: Neon.textDim),
        filled: true,
        fillColor: Neon.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      );
}
