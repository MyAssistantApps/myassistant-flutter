import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/apple_kit.dart';
import '../design/neon_tokens.dart';
import '../features/assistant/state/assistant_engine.dart';
import '../widgets/neon_cards.dart';
import 'clients_screen.dart';
import 'finance_screen.dart';

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
  const ProAction(this.title, this.detail, this.icon, {this.ask, this.page});
  final String title;
  final String detail;
  final IconData icon;

  /// Said to the assistant.
  final String? ask;

  /// Or opened.
  final Widget Function()? page;
}

class ProProfile {
  const ProProfile(this.kind, this.name, this.icon, this.tint, this.lead, this.actions);
  final ProKind kind;
  final String name;
  final IconData icon;
  final Color Function() tint;
  final String lead;
  final List<ProAction> actions;

  static ProProfile of(ProKind k) => switch (k) {
        ProKind.doctor => ProProfile(
            k,
            "Doctor's",
            Icons.medical_services_rounded,
            () => Neon.cyan,
            'Your patients, their visits and dues, kept for you.',
            [
              ProAction('Patients', 'Each patient\'s file, notes and reports', Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              const ProAction('Who has dues pending?', 'Patients with payments still due', Icons.payments_rounded,
                  ask: 'Which of my patients have dues pending?'),
              const ProAction('Follow-up visits', 'Recalls coming up', Icons.event_repeat_rounded,
                  ask: 'Which patient follow-up visits are coming up?'),
              const ProAction('Note a payment', 'Record what a patient paid', Icons.receipt_long_rounded,
                  ask: 'I want to record a payment from a patient.'),
            ],
          ),
        ProKind.advocate => ProProfile(
            k,
            "Advocate's",
            Icons.gavel_rounded,
            () => Neon.violet,
            'Your cases, hearings and the law, at hand.',
            [
              ProAction('Case files', 'Each client\'s case, notes and papers', Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              const ProAction('Hearings coming up', 'From your cases and calendar', Icons.event_note_rounded,
                  ask: 'What hearings do I have coming up?'),
              const ProAction('Look up the law', 'Indian acts and sections, explained', Icons.menu_book_rounded,
                  ask: 'I want to look up a section of Indian law.'),
              const ProAction('Draft a notice', 'A legal notice or letter, written for you', Icons.edit_note_rounded,
                  ask: 'Help me draft a legal notice.'),
            ],
          ),
        ProKind.business => ProProfile(
            k,
            'Business',
            Icons.storefront_rounded,
            () => Neon.pink,
            'Your clients, money and records in one place.',
            [
              ProAction('Clients', 'Each customer\'s file, notes and documents', Icons.folder_shared_rounded,
                  page: () => const ClientsScreen()),
              ProAction('Money', 'Income, spending and what is due', Icons.account_balance_wallet_rounded,
                  page: () => const FinanceScreen()),
              const ProAction('Record book', 'Add or check an entry', Icons.menu_book_rounded,
                  ask: 'Show me the latest entries in my record book.'),
              const ProAction('Write to a customer', 'A quote, a reminder or a thank-you', Icons.mail_rounded,
                  ask: 'Help me write a message to a customer.'),
            ],
          ),
      };
}

class ProAssistantScreen extends StatelessWidget {
  const ProAssistantScreen({super.key, required this.kind});
  final ProKind kind;

  void _run(BuildContext context, ProAction a) {
    HapticFeedback.selectionClick();
    final page = a.page;
    if (page != null) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page()));
      return;
    }
    final ask = a.ask;
    if (ask == null) return;
    // Back to Home first: the voice screen is where she answers.
    Navigator.of(context).popUntil((r) => r.isFirst);
    unawaited(AssistantEngine.instance.askAssistant(ask).catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final p = ProProfile.of(kind);
    final tint = p.tint();
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, '${p.name} Assistant'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: tint.withValues(alpha: 0.16),
                  border: Border.all(color: tint.withValues(alpha: 0.45)),
                ),
                child: Icon(p.icon, color: tint, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(p.lead,
                    style: NeonType.manrope(16, FontWeight.w600).copyWith(color: Neon.textHi, height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final a in p.actions)
                  Semantics(
                    button: true,
                    label: '${a.title}. ${a.detail}',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => _run(context, a),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(a.icon, color: tint, size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title,
                                      style: NeonType.manrope(NeonType.callout, FontWeight.w700)
                                          .copyWith(color: Neon.textHi)),
                                  const SizedBox(height: 2),
                                  Text(a.detail, style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
                                ],
                              ),
                            ),
                            Icon(a.page != null ? Icons.chevron_right_rounded : Icons.graphic_eq_rounded,
                                color: Neon.textDim, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Or just ask — for example "add a note to Ramesh\'s file".',
              style: TextStyle(color: Neon.textDim, fontSize: NeonType.footnote)),
        ],
      ),
    );
  }
}
