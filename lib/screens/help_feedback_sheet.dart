import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../design/neon_tokens.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';
import '../widgets/glow_cta.dart';

/// HELP & FEEDBACK (product audit 2026-11-21): users had no way to report a
/// problem or say which build they run. What they write goes to the same
/// Feedback inbox the admin panel shows (POST /feedback), with the build.
class HelpFeedbackSheet extends StatefulWidget {
  const HelpFeedbackSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Neon.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const HelpFeedbackSheet(),
      );

  @override
  State<HelpFeedbackSheet> createState() => _HelpFeedbackSheetState();
}

class _HelpFeedbackSheetState extends State<HelpFeedbackSheet> {
  final _text = TextEditingController();
  String _kind = 'bug';
  bool _busy = false;
  String _version = '';
  int _build = 0;

  static const _kinds = [
    ('bug', 'Report a Problem', Icons.bug_report_rounded),
    ('feature', 'Suggest an Idea', Icons.lightbulb_rounded),
    ('praise', 'Something Works Well', Icons.favorite_rounded),
  ];

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (!mounted) return;
      setState(() {
        _version = i.version;
        _build = int.tryParse(i.buildNumber) ?? 0;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final words = _text.text.trim();
    if (words.length < 4) {
      AppFeedback.show('Please describe it in a few words.', context: context);
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final r = await ApiService.postJson('/feedback', {
      'kind': _kind,
      'summary': words.length > 280 ? '${words.substring(0, 277)}...' : words,
      'details': words,
      'appBuild': _build,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) {
      AppFeedback.show('Unable to send your feedback. Please try again.', context: context);
      return;
    }
    Navigator.of(context).pop();
    AppFeedback.show('Thank you. Your feedback has been sent to the team.');
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Neon.textLo.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [Neon.violet, Neon.accentC],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: Neon.violet.withValues(alpha: 0.35), blurRadius: 16),
                    ],
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Help & Feedback',
                        style: NeonType.manrope(19, FontWeight.w800).copyWith(color: Neon.textHi)),
                    const SizedBox(height: 2),
                    Text('The team reads every message.',
                        style: NeonType.manrope(13, FontWeight.w500).copyWith(color: Neon.textLo)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in _kinds)
                  ChoiceChip(
                    selected: _kind == k.$1,
                    onSelected: (_) => setState(() => _kind = k.$1),
                    avatar: Icon(k.$3, size: 17, color: _kind == k.$1 ? Neon.violet : Neon.textLo),
                    label: Text(k.$2),
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _text,
                minLines: 4,
                maxLines: 8,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _kind == 'bug'
                      ? 'What happened, and what did you expect?'
                      : 'Tell the team what you have in mind.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
              GlowCta(
                label: 'Send Feedback',
                icon: Icons.send_rounded,
                busy: _busy,
                busyLabel: 'Sending',
                onPressed: _busy ? null : _send,
              ),
              const SizedBox(height: 12),
              if (_version.isNotEmpty)
                Text('MyAssistant $_version (build $_build)',
                    textAlign: TextAlign.center,
                    style: NeonType.manrope(12, FontWeight.w500).copyWith(color: Neon.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}
