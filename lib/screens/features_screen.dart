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
      ('Photo Cards & Greeting Cards', "A real photo with your words and signature; say 'show me another one' until it is right"),
      ('Event Posters', 'A poster for a party, pooja or launch, with the date and venue included'),
      ('Pictures & Short Videos', "'Draw a lion in neon', 'make a video of…': created on request"),
      ('Photo Edits', 'Restore an old photo, retouch a portrait or try a new look on yourself (Style Studio)'),
      ('Real Files', 'A PPT, a PDF report, a Word document, an Excel sheet, a letter or your resume'),
      ('Written Pieces', 'A speech, a script, a plan or an email draft, displayed on screen and ready for use'),
      ('Video Notes in Your Voice', "Record once in You, then say 'send a video note to X saying…'"),
      ('Shortcuts & Standing Rules', "A single word that performs several actions; rules your assistant always follows"),
      ('Card & Document Scanning', 'A business card becomes a contact; a scan is filed under a client or patient'),
    ]),
    ('YOUR DAY', [
      ('Reminders by Phone Call', "'Remind me at 9': your assistant calls you at 9 and reads the reminder"),
      ('Alarms, Timers, Calendar', 'Set, change or cancel by voice; a calendar with holidays and festivals'),
      ('Daily Brief', "'What's my day', a spoken morning brief, 'play my day', plan my day"),
      ('Focus & Habits', "A focus timer, Today's 3 and habit tracking"),
      ('Weather & Going Out', "'Do I need an umbrella', hour-by-hour rain forecasts and advice before you leave"),
      ('Places & Directions', "'Chemist near me' on the map, directions, where am I, saved addresses"),
      ('Shopping List', "'Add this' from any conversation; tick off, share or order from Blinkit and more"),
      ('Kitchen', 'Recipes from available ingredients, cook mode and pantry'),
      ('News & Markets', 'Headlines as cards, stories read aloud and live stocks'),
      ('Money', 'EMI, loan and surplus planning; currency conversion; flight fare monitoring'),
      ('Horoscope', 'Your horoscope, on request'),
    ]),
    ('PHONE & PEOPLE', [
      ('Calls on Your Behalf', "Dial anyone, or say 'call Ravi and tell him I'm late': your assistant speaks for you and retries on request"),
      ('A Suitable Voice', "A female or male voice; firm for outstanding amounts, warm for greetings, gentle for difficult news, or say 'be firm'"),
      ('Calls in Six Languages', 'English, Hindi, Kannada, Malayalam, Tamil and Telugu; the assistant follows the language of the other person'),
      ('Call Outcomes', "Commitments made are noted for you; recordings are available in Calls; 'connect me' transfers the call to you"),
      ('Wake-Up Calls', "'Call me at 5 and wake me up': the calls continue until you answer"),
      ('Calls on Any App', 'WhatsApp, Telegram and Signal calls by name'),
      ('Missed Calls & Call Notes', "'Any missed calls?'; recorded calls are analysed, so you may ask what Ravi said"),
      ('Messages', 'To another user through their assistant, by WhatsApp (you tap Send) or by plain SMS'),
      ('Email', 'Reads, replies to and sends your mail; bills by email'),
      ('People Memory', "Facts, notes, dates and addresses about people, such as 'what's Ravi's address'"),
      ('Nearby Places', "'Find a good restaurant near me': real places, shown on the map"),
      ('Interpreter', 'Live interpretation between two languages'),
      ('Phone Control', 'Flashlight, volume, Bluetooth, brightness, silent mode and any settings page'),
      ('Apps', 'Open, install or remove any app; open a profile; display a picture of any person or subject'),
      ('Errands', 'Order food, book a ride, book movie tickets or pay by UPI; passed to the relevant app for your confirmation'),
      ('The Web', 'Search, have a page read aloud, or save a PDF or map from the web'),
    ]),
    ('WORK', [
      ('Meetings', 'Record a meeting for minutes, decisions, action items and a PDF; a preparation card before the next'),
      ('Arrange a Meeting', 'Your assistant calls the other person and agrees a time'),
      ('Clients & Patients', 'Outstanding amounts, payments, recalls and their files, sent on your instruction'),
      ('Record Books', "Dictated figures and tallies, such as 'what's my total'"),
      ('Indian Law', 'Statutes, case law, rules and procedures: quoted, never invented'),
      ('Research', 'In-depth research on a topic; web search for current information'),
      ('Notion & Connected Tools', 'Search, read, add and create pages; your own tool servers'),
    ]),
    ('THE ASSISTANT', [
      ('Live Voice Conversation', 'English, Kannada, Hindi, Tamil, Telugu, Malayalam and more; you may interrupt at any time'),
      ('Typed Chat & Photos', 'Type instead, or ask about a photo, the camera view or a screenshot'),
      ('Memory', "'What did I just ask', 'what did you do', 'remember that'"),
      ('Personalisation', 'Its name, voice and gender, theme colour, app lock and privacy switches'),
      ('Automatic Updates', 'New versions are installed automatically'),
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
