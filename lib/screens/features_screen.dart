import 'package:flutter/material.dart';

import '../design/apple_kit.dart';
import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';

/// FEATURES — an honest, three-tier map of the product: what works
/// today, what is being built right now, and what is planned. Static by
/// design: it changes exactly when the app changes, so it ships with
/// each release. Update the lists below whenever a feature moves tiers
/// (his spec, 2026-09-18: "fully implemented / currently working on /
/// yet to work on").
class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  /// What works today, grouped the way people ask for it (2026-10-01).
  static const _groups = <(String, List<(String, String)>)>[
    ('MAKE', [
      ('Photo Cards & Greeting Cards', "A real photo with your message and signature — say 'Show me another design' until it is right"),
      ('Event Posters', 'Posters for a party, pooja, or launch, with date and venue'),
      ('Pictures & Short Videos', "'Draw a lion in neon style', 'Create a video of…' — generated on request"),
      ('Photo Edits', 'Restore old photos, retouch portraits, or try a new look (Style Studio)'),
      ('Documents', 'Presentations, PDF reports, Word documents, Excel sheets, letters, and resumes'),
      ('Written Pieces', 'Speeches, scripts, plans, and email drafts — ready to use'),
      ('Video Notes in Your Voice', "Record once in You, then say 'Send a video note to Ravi saying…'"),
      ('Shortcuts & Standing Rules', "One word that runs several actions; rules your assistant always follows"),
      ('Card & Document Scanning', 'Business cards become contacts; scans are filed to the right client or patient'),
    ]),
    ('YOUR DAY', [
      ('Reminders by Phone Call', "'Remind me at 9 AM' — your assistant calls you at 9 and reads the reminder"),
      ('Alarms, Timers, Calendar', 'Set, change, or cancel by voice; a calendar with holidays and festivals'),
      ('Daily Brief', "'Brief me on my day' — a spoken morning briefing and day plan"),
      ('Focus & Habits', "A focus timer, Today's 3 priorities, and habit tracking"),
      ('Weather & Going Out', "'Will it rain today?' — hourly forecasts and an alert before you leave"),
      ('Places & Directions', "'Find a pharmacy near me' — maps, directions, and saved addresses"),
      ('Shopping List', "'Add this to my shopping list' from any conversation; share or order via Blinkit and more"),
      ('Kitchen', 'Recipes from what you have, cook mode, and pantry'),
      ('News & Markets', 'Headline cards, stories read aloud, and live markets'),
      ('Money', 'EMI, loan, and savings planning; currency conversion; fare alerts'),
      ('Horoscope', 'Your horoscope, on request'),
    ]),
    ('PHONE & PEOPLE', [
      ('Calls on Your Behalf', "Say 'Call Ravi and inform him I am running late' — your assistant speaks for you and retries on request"),
      ('A Suitable Voice', "Female or male; firm for payment follow-ups, warm for greetings, gentle for difficult news"),
      ('Calls in Six Languages', 'English, Hindi, Kannada, Malayalam, Tamil, and Telugu — matching the other person'),
      ('Call Outcomes', "Commitments are noted, recordings saved in Calls; 'Connect me' transfers the call to you"),
      ('Wake-Up Calls', "'Wake me up with a call at 5 AM' — it keeps calling until you answer"),
      ('Calls on Any App', 'WhatsApp, Telegram, and Signal calls by name'),
      ('Missed Calls & Call Notes', "'Any missed calls?' — recorded calls are analysed, so you can ask what Ravi said"),
      ('Messages', 'To another user via their assistant, by WhatsApp (you tap Send), or by SMS'),
      ('Email', 'Reads, replies to, and sends your mail; Bills by Email'),
      ('People Memory', "Facts, dates, and addresses for your contacts — 'What is Ravi's address?'"),
      ('Nearby Places', "'Find a well-rated restaurant nearby' — real places on the map"),
      ('Interpreter', 'Live interpretation between two languages'),
      ('Phone Control', 'Flashlight, volume, Bluetooth, brightness, silent mode, and any settings page'),
      ('Apps', 'Open, install, or remove apps; open profiles; show a picture of any subject'),
      ('Errands', 'Order food, book rides and movie tickets, or pay by UPI — confirmed by you in the app'),
      ('The Web', 'Search, read pages aloud, or save a PDF or map'),
    ]),
    ('WORK', [
      ('Meetings', 'Minutes, decisions, action items, and a PDF; a briefing card before the next meeting'),
      ('Arrange a Meeting', 'Your assistant calls the other party and confirms a time'),
      ('Clients & Patients', 'Pending dues, payments, recalls, and records — on your instruction'),
      ('Record Books', "Dictated figures and running totals — 'What is my total?'"),
      ('Indian Law', 'Statutes, case law, rules, and procedure — cited, never invented'),
      ('Research', 'In-depth research and live web search'),
      ('Notion & Connected Tools', 'Search, read, and create pages; your own tool servers'),
    ]),
    ('THE ASSISTANT', [
      ('Live Voice Conversation', 'English, Kannada, Hindi, Tamil, Telugu, Malayalam, and more — interrupt at any time'),
      ('Typed Chat & Photos', 'Type instead, or ask about a photo, the camera view, or a screenshot'),
      ('Memory', "'What did I just ask?', 'Remember that'"),
      ('Personalisation', 'Name, voice, theme colour, app lock, and privacy controls'),
      ('Automatic Updates', 'New versions install automatically'),
    ]),
  ];

  static const _building = <(String, String)>[
    ('Video Avatar Messages', 'Your assistant delivers messages as a talking avatar'),
  ];

  static const _planned = <(String, String)>[
    ('Hands-Free Wake Word', 'Say the name of your assistant; no tap is required'),
    ('More Phones', 'The same assistant on other types of phone'),
    ('App Store Release', 'Install and update from the app store'),
  ];

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Features'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          // Each tier in its meaning's light (2026-09-30, NeonTone): live
          // is done-and-well green and the brightest; in progress amber;
          // coming soon the purple of something to discover.
          for (var g = 0; g < _groups.length; g++) ...[
            if (g > 0) const SizedBox(height: 22),
            _section(_groups[g].$1, NeonTone.success,
                Icons.check_circle_rounded, _groups[g].$2, g * 60,
                halo: g == 0 ? 0.6 : 0.4),
          ],
          const SizedBox(height: 22),
          _section('IN PROGRESS', NeonTone.warning, Icons.build_circle_rounded,
              _building, 360),
          const SizedBox(height: 22),
          _section('COMING SOON', NeonTone.discovery, Icons.schedule_rounded,
              _planned, 420),
        ],
      ),
    );
  }

  Widget _section(String title, NeonTone tone, IconData icon,
      List<(String, String)> items, int delayMs,
      {double halo = 0.3}) {
    final tint = tone.ink;
    return Reveal(
      delayMs: delayMs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: tint,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1)),
            ],
          ),
          const SizedBox(height: 10),
          GlowCard(
            tone: tone,
            halo: halo,
            rimWidth: 1.6,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 0.5, color: Neon.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: tone.rim.first,
                              shape: BoxShape.circle,
                              boxShadow:
                                  Neon.halo(tone.rim.first, strength: 0.4)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(items[i].$1,
                                  style: TextStyle(
                                      color: Neon.textHi,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(items[i].$2,
                                  style: TextStyle(
                                      color: Neon.textLo,
                                      fontSize: 13,
                                      height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
