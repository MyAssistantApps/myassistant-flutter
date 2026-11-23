import 'package:flutter/foundation.dart';

/// WHO IS TALKING (owner, 2026-11-02: "in front of that Doctor's text I
/// need a mic orb that talks as a Doctor's Assistant — do the same for the
/// others"). While one of the professional assistants' pages is open, its
/// mic orb sets the role; the same brain, tools and voice then answer as
/// that assistant. Null is the everyday assistant.
@immutable
class AssistantRole {
  const AssistantRole(this.name, this.brief,
      {this.tools = const [], this.voice, this.voiceStyle});

  /// How the assistant introduces itself ("the Doctor's Assistant").
  final String name;

  /// What it looks after, in a sentence.
  final String brief;

  /// The server tools its work needs (2026-11-23). Sent with every context
  /// request (roleTools): a fast-voice session takes its tools once, when
  /// it opens, and without these "Ramesh paid 500" or "how is my career this
  /// month" reached a session that had no such tool.
  final List<String> tools;

  /// The voice it speaks in — one of the server's ten (Guruji: cedar, a
  /// natural male voice) — in the fast voice and in every spoken reply.
  /// Null: the owner's own pick.
  final String? voice;

  /// How it speaks ("deep, calm and unhurried …"): told to the fast voice,
  /// and a <tone: …> note on each sentence the speech model reads (at most
  /// 120 characters, the server's limit for that note).
  final String? voiceStyle;

  /// [fallback] unless the current role has a voice of its own.
  static String voiceOr(String fallback) {
    final v = current.value?.voice?.trim();
    return v == null || v.isEmpty ? fallback : v;
  }

  /// [sentence] with the current role's speaking style as a <tone: …> note,
  /// unless it already carries one (the model's own marking wins).
  static String toned(String sentence) {
    final s = current.value?.voiceStyle?.trim();
    if (s == null || s.isEmpty) return sentence;
    if (RegExp(r'^\s*<tone:', caseSensitive: false).hasMatch(sentence)) return sentence;
    return '<tone: $s> $sentence';
  }

  static final ValueNotifier<AssistantRole?> current = ValueNotifier(null);

  /// [system] with the current role's instruction added (unchanged when
  /// there is none).
  static String apply(String system) {
    final r = current.value;
    if (r == null) return system;
    final voice = (r.voiceStyle ?? '').trim();
    return '$system\n\nYOUR ROLE IN THIS CONVERSATION: you are ${r.name}. '
        '${r.brief} Stay in this role: introduce yourself as ${r.name} if '
        'asked, keep to this work, and use your tools for the owner\'s '
        'records in it.${voice.isEmpty ? '' : ' Your voice: speak $voice.'}';
  }

  @override
  bool operator ==(Object other) =>
      other is AssistantRole &&
      other.name == name &&
      other.brief == brief &&
      listEquals(other.tools, tools) &&
      other.voice == voice &&
      other.voiceStyle == voiceStyle;

  @override
  int get hashCode =>
      Object.hash(name, brief, Object.hashAll(tools), voice, voiceStyle);
}
