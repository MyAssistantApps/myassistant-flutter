import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/apple_kit.dart';
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';
import '../services/api_service.dart';
import '../services/app_feedback.dart';

/// One company the user can link (GET /accounts).
class LinkedAccount {
  LinkedAccount(this.id, Map<String, dynamic> j)
      : label = '${j['label'] ?? id}',
        available = j['available'] == true,
        linked = j['linked'] == true;
  final String id, label;
  final bool available, linked;

  static List<LinkedAccount> listFrom(Map<String, dynamic>? j) {
    final m = j?['accounts'];
    if (m is! Map) return const [];
    return [
      for (final e in m.entries)
        if (e.value is Map) LinkedAccount('${e.key}', (e.value as Map).cast<String, dynamic>()),
    ];
  }
}

/// LINKED ACCOUNTS (owner, 2026-11-21): link Uber and Swiggy once, and the
/// assistant books cabs and places orders on the user's own account. The
/// sign-in happens on the company's own page; the app never sees the
/// password. Coming back to the app refreshes the list.
class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> with WidgetsBindingObserver {
  List<LinkedAccount>? _list;
  bool _failed = false;
  String? _busy;

  static const _what = <String, (IconData, String)>{
    'uber': (Icons.local_taxi_rounded, 'Book cabs by voice on your Uber account'),
    'ola': (Icons.local_taxi_outlined, 'Book cabs by voice on your Ola account'),
    'swiggy': (Icons.restaurant_rounded, 'Order food and Instamart groceries by voice'),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the company's sign-in page: show the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final j = await ApiService.getJson('/accounts');
    if (!mounted) return;
    setState(() {
      _failed = j == null && _list == null;
      if (j != null) _list = LinkedAccount.listFrom(j);
    });
  }

  Future<void> _link(LinkedAccount a) async {
    HapticFeedback.selectionClick();
    setState(() => _busy = a.id);
    final r = await ApiService.getJson('/accounts/${a.id}/connect', timeout: const Duration(seconds: 12));
    if (!mounted) return;
    setState(() => _busy = null);
    final url = r?['url'] as String?;
    if (url == null) {
      AppFeedback.show('Unable to start linking ${a.label}. Please try again.');
      return;
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) AppFeedback.show('Unable to open the ${a.label} sign-in page.');
  }

  Future<void> _unlink(LinkedAccount a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Unlink ${a.label}?'),
        content: Text('Your assistant will no longer book or order on your ${a.label} account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Unlink')),
        ],
      ),
    );
    if (yes != true) return;
    await ApiService.deleteJson('/accounts/${a.id}');
    await _load();
    AppFeedback.show('${a.label} has been unlinked.');
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return NeonScaffold(
      appBar: appleAppBar(context, 'Linked Accounts'),
      body: list == null
          ? (_failed
              ? NeonErrorState(message: 'Unable to load your linked accounts.', onRetry: _load)
              : const Center(child: NeonLoader()))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Link an account once and your assistant books and orders on it by voice. '
                  'You sign in on the company\'s own page; MyAssistant never sees your password.',
                  style: NeonType.manrope(14, FontWeight.w500).copyWith(color: Neon.textLo, height: 1.45),
                ),
                const SizedBox(height: 18),
                GroupedCard(
                  dividerInset: 60,
                  children: [
                    for (final a in list)
                      AppleRow(
                        leading: IconTile(_what[a.id]?.$1 ?? Icons.link_rounded,
                            a.linked ? AppleColors.green : AppleColors.purple),
                        title: a.label,
                        subtitle: a.linked
                            ? 'Linked · ${_what[a.id]?.$2 ?? ''}'
                            : a.available
                                ? (_what[a.id]?.$2 ?? 'Link your account')
                                : 'Available Soon',
                        trailing: _busy == a.id
                            ? const SizedBox(width: 22, height: 22, child: NeonLoader(size: 20))
                            : a.linked
                                ? TextButton(onPressed: () => _unlink(a), child: const Text('Unlink'))
                                : a.available
                                    ? FilledButton(onPressed: () => _link(a), child: const Text('Link'))
                                    : null,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
