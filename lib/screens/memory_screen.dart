import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/apple_kit.dart';
import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';

/// One remembered line (backend GET /profile/memories).
class _Memory {
  _Memory(this.id, this.fact, this.kind, this.at, this.faded);
  final int id;
  final String fact;
  final String kind; // preference | goal | semantic
  final DateTime? at;

  /// Still recalled when asked, no longer in every answer.
  final bool faded;
}

/// A standing rule (backend GET /profile/instructions).
class _Rule {
  _Rule(this.id, this.text);
  final int id;
  final String text;
}

/// ─────────────────────────────────────────────────────────────────────────
///  WHAT I REMEMBER (2026-10-19, owner: "a section for memory … see and
///  review the information that the agent knows about the user"). The
///  same lines the assistant is given about the user, grouped as it uses
///  them — how they like things done, their goals, facts about them — and
///  the standing rules. Any one can be removed; the assistant stops using
///  it at once.
/// ─────────────────────────────────────────────────────────────────────────
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<_Memory> _memories = const [];
  List<_Rule> _rules = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final results = await Future.wait([
      ApiService.getJson('/profile/memories', timeout: const Duration(seconds: 15)),
      ApiService.getJson('/profile/instructions', timeout: const Duration(seconds: 15)),
    ]);
    if (!mounted) return;
    final m = results[0];
    final r = results[1];
    setState(() {
      _loading = false;
      _failed = m == null;
      _memories = [
        for (final e in (m?['memories'] as List? ?? const []))
          if (e is Map && e['fact'] is String && (e['fact'] as String).trim().isNotEmpty)
            _Memory(
              (e['id'] as num?)?.toInt() ?? 0,
              (e['fact'] as String).trim(),
              e['kind'] as String? ?? 'semantic',
              _date(e['createdAt']),
              e['faded'] == true,
            ),
      ];
      _rules = [
        for (final e in (r?['instructions'] as List? ?? const []))
          if (e is Map && e['instruction'] is String)
            _Rule((e['id'] as num?)?.toInt() ?? 0, (e['instruction'] as String).trim()),
      ];
    });
  }

  static DateTime? _date(Object? v) {
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v < 1e12 ? (v * 1000).toInt() : v.toInt());
    if (v is String) {
      final n = num.tryParse(v);
      if (n != null) return _date(n);
      return DateTime.tryParse(v)?.toLocal();
    }
    return null;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String _when(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final day = '${d.day} ${_months[d.month - 1]}';
    return d.year == now.year ? 'Learned $day' : 'Learned $day ${d.year}';
  }

  Future<bool> _confirm(String what) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget this?'),
        content: Text('"$what"\n\nThe assistant will stop using it. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Forget', style: TextStyle(color: Neon.errorInk))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _forget(_Memory m) async {
    if (!await _confirm(m.fact)) return;
    HapticFeedback.lightImpact();
    final before = _memories;
    setState(() => _memories = [for (final x in _memories) if (x.id != m.id) x]);
    final r = await ApiService.deleteJson('/profile/memories/${m.id}');
    if (!mounted) return;
    if (r == null) {
      setState(() => _memories = before);
      AppFeedback.show("Couldn't remove it. Check your connection.",
          context: context, tone: FeedbackTone.error);
    } else {
      AppFeedback.show('Forgotten.', context: context, tone: FeedbackTone.success);
    }
  }

  Future<void> _removeRule(_Rule rule) async {
    if (!await _confirm(rule.text)) return;
    HapticFeedback.lightImpact();
    final before = _rules;
    setState(() => _rules = [for (final x in _rules) if (x.id != rule.id) x]);
    final r = await ApiService.deleteJson('/profile/instructions/${rule.id}');
    if (!mounted) return;
    if (r == null) {
      setState(() => _rules = before);
      AppFeedback.show("Couldn't remove it. Check your connection.",
          context: context, tone: FeedbackTone.error);
    } else {
      AppFeedback.show('Rule removed.', context: context, tone: FeedbackTone.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Memory'),
      body: SafeArea(
        top: false,
        child: _loading
            ? const NeonLoader.page(semanticLabel: 'Loading what I remember')
            : _failed
                ? NeonErrorState(message: "Couldn't load your memory", onRetry: _load)
                : RefreshIndicator(onRefresh: _load, child: _list()),
      ),
    );
  }

  Widget _list() {
    final prefs = _memories.where((m) => m.kind == 'preference').toList();
    final goals = _memories.where((m) => m.kind == 'goal').toList();
    final facts = _memories.where((m) => m.kind != 'preference' && m.kind != 'goal').toList();
    final total = _memories.length + _rules.length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
          child: Text(
            total == 0
                ? 'Nothing yet. Tell the assistant about yourself — "I am vegetarian", '
                    '"remember my sister lives in Pune" — and it will show here.'
                : 'What the assistant has learned about you from your conversations. '
                    'Tap any item to remove it. To add or correct something, just tell it.',
            style: TextStyle(color: Neon.textLo, fontSize: 14, height: 1.4),
          ),
        ),
        if (total == 0)
          const NeonEmptyState(
            icon: Icons.psychology_alt_rounded,
            title: 'No memories yet',
          ),
        _group('How you like things', Icons.tune_rounded, AppleColors.purple, prefs),
        _group('Your goals', Icons.flag_rounded, AppleColors.green, goals),
        _group('About you', Icons.person_rounded, AppleColors.blue, facts),
        if (_rules.isNotEmpty) ...[
          const GroupLabel('Standing rules'),
          GroupedCard(
            dividerInset: 60,
            children: [
              for (final r in _rules)
                AppleRow(
                  leading: IconTile(Icons.rule_rounded, AppleColors.orange),
                  title: r.text,
                  titleMaxLines: 4,
                  trailing: Icon(Icons.close_rounded, color: Neon.textDim, size: 18),
                  onTap: () => _removeRule(r),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _group(String label, IconData icon, Color tint, List<_Memory> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel('$label · ${items.length}'),
        GroupedCard(
          dividerInset: 60,
          children: [
            for (final m in items)
              AppleRow(
                leading: IconTile(icon, tint),
                title: m.fact,
                titleMaxLines: 4,
                subtitle: [
                  _when(m.at),
                  if (m.faded) 'Not used lately',
                ].where((s) => s.isNotEmpty).join(' · '),
                trailing: Icon(Icons.close_rounded, color: Neon.textDim, size: 18),
                onTap: () => _forget(m),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
