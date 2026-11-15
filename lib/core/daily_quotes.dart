/// The daily line on the Home page.
///
/// His spec, 2026-09-18: "in the homepage and in the bottom i need
/// inspirational quotes". Revised 2026-09-21: "instead of inspirational
/// quotes give motivation quotes."
///
/// The difference is not decorative. An inspirational line is something
/// to agree with — "a calm mind gets more done" — and you nod at it and
/// scroll past. A motivational line asks for something: start, finish,
/// decide, send it, do the hard one first. These are written to be read
/// at 8 a.m. by somebody who has a day in front of them and is putting
/// it off.
///
/// Still local and deterministic: rotates once per day, no network, no
/// repeat on consecutive days.
class DailyQuotes {
  static const _lines = <String>[
    'Begin with the most demanding task. The remainder of the day becomes easier.',
    'Begin before you feel prepared. Preparedness follows from beginning.',
    'One hour of genuine work outweighs a day spent preparing to work.',
    'The task repeatedly deferred is the task to complete now.',
    'Complete one task today, however small.',
    'Deliver it. Good work delivered outweighs perfect work withheld.',
    'Decide now. A decision made frees the attention a pending one occupies.',
    'Motivation is not required. The first five minutes are.',
    'Identify the call you least wish to make, and make it.',
    'Conclude one open matter before commencing another.',
    'Your future self depends on today. Provide a sound foundation.',
    'Be present today regardless of inclination. Consistency is the method.',
    'The work most often avoided is usually the work of greatest value.',
    'Decline one commitment today in order to complete another.',
    'Produce a first draft, then refine it. Nothing improves while unwritten.',
    'Two focused hours today are worth ten distracted hours tomorrow.',
    'The day is yours until others claim it. Allocate it first.',
    'Cease planning. Open the task and begin.',
    'Momentum is built, not found. Establish it before midday.',
    'Respond to the message you have been postponing.',
    'Effort compounds quietly, and then all at once.',
    'Do today what you have been reserving for tomorrow.',
    'A small task completed outweighs a large one merely imagined.',
    'Discipline is choosing what matters most over what is wanted now.',
    'Each day of delay enlarges the task. Address it while it is small.',
  ];

  static String today() {
    final days = DateTime.now().difference(DateTime(2026)).inDays;
    return _lines[days % _lines.length];
  }
}
