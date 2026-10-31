// Small value types shared by the lib/ai modules.
import 'dart:typed_data';

/// One line of conversation, as the server's memory and the model see it.
/// [role] is 'user' or 'model'.
class ChatTurn {
  const ChatTurn(this.role, this.text);

  final String role;
  final String text;

  bool get isUser => role != 'model';

  static ChatTurn? fromJson(Object? j) {
    if (j is! Map) return null;
    final text = j['text'];
    if (text is! String || text.trim().isEmpty) return null;
    final role = j['role'] == 'model' || j['role'] == 'assistant' ? 'model' : 'user';
    return ChatTurn(role, text);
  }

  Map<String, Object?> toJson() => {'role': role, 'text': text};

  @override
  bool operator ==(Object other) =>
      other is ChatTurn && other.role == role && other.text == text;

  @override
  int get hashCode => Object.hash(role, text);

  @override
  String toString() => '$role: $text';
}

/// Something the user attached to a turn: a photo, a PDF, a voice note, a
/// clip. [bytes] go to the cloud model; [path] is read into them when the
/// turn is sent.
class AiAttachment {
  const AiAttachment({
    required this.kind,
    required this.mimeType,
    this.bytes,
    this.path,
  });

  /// 'image' | 'pdf' | 'audio' | 'video'.
  final String kind;
  final String mimeType;
  final Uint8List? bytes;
  final String? path;

  bool get isImage => kind == 'image';

  /// What /ai/context is told about it (never the bytes).
  Map<String, String> toJson() => {'kind': kind, 'mime': mimeType};

  /// Kind from a MIME type: image/*, application/pdf, audio/*, video/*.
  static String kindOf(String mimeType) {
    final m = mimeType.toLowerCase();
    if (m.startsWith('image/')) return 'image';
    if (m.startsWith('audio/')) return 'audio';
    if (m.startsWith('video/')) return 'video';
    return 'pdf';
  }
}

/// A web page a grounded (Google Search) answer came from.
class SourceLink {
  const SourceLink({required this.uri, this.title});

  final String uri;
  final String? title;

  @override
  bool operator ==(Object other) => other is SourceLink && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => title == null ? uri : '$title <$uri>';
}

/// A tool the server offers this turn: its name, what it does and its
/// parameters as a JSON Schema object (converted in json_schema.dart).
class AiToolSpec {
  const AiToolSpec({
    required this.name,
    this.description = '',
    this.parameters = const {},
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  static AiToolSpec? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = j['name'];
    if (name is! String || name.isEmpty) return null;
    final params = j['parameters'];
    return AiToolSpec(
      name: name,
      description: j['description'] is String ? j['description'] as String : '',
      parameters: params is Map ? Map<String, dynamic>.from(params) : const {},
    );
  }
}

/// WHO HAS CONTROL OF A TURN (2026-10-31): the server's manager agent hands
/// each turn to specialist agents (backend agents/manager.js) and says
/// which, so the owner can see it — "Manager → Shopping and money".
class AgentControl {
  const AgentControl({
    this.via = 'skip',
    this.agents = const [],
    this.toolAgent = const {},
    this.addressed,
  });

  /// How the manager decided: rules, model, carry, none, late or skip.
  final String via;

  /// The specialists, most important first: (id, label).
  final List<({String id, String label})> agents;

  /// Tool name -> the specialist id that owns it this turn.
  final Map<String, String> toolAgent;

  /// The agent the owner asked to speak to ("call your manager"), who
  /// answers this turn in person.
  final ({String id, String label})? addressed;

  /// The same, with [id] among the specialists (a Live turn adds each one
  /// as the model reaches for its tools).
  AgentControl withAgent(String id) => agents.any((a) => a.id == id)
      ? this
      : AgentControl(
          via: via,
          agents: [...agents, (id: id, label: agentLabels[id] ?? id)],
          toolAgent: toolAgent,
          addressed: addressed,
        );

  /// The manager stayed out of it (a shortcut, a note from the app).
  bool get skipped => via == 'skip';

  /// "Manager → Shopping and money + Communication", or "Manager".
  String get summary =>
      agents.isEmpty ? 'Manager' : 'Manager → ${agents.map((a) => a.label).join(' + ')}';

  /// The specialist label running [tool], when one owns it.
  String? labelFor(String tool) {
    final id = toolAgent[tool];
    if (id == null) return null;
    for (final a in agents) {
      if (a.id == id) return a.label;
    }
    return null;
  }

  static AgentControl? fromJson(Object? j) {
    if (j is! Map) return null;
    final agents = <({String id, String label})>[
      if (j['agents'] is List)
        for (final a in j['agents'] as List)
          if (a is Map && a['id'] is String && a['label'] is String)
            (id: a['id'] as String, label: a['label'] as String),
    ];
    final owners = <String, String>{
      if (j['toolAgent'] is Map)
        for (final e in (j['toolAgent'] as Map).entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
    };
    final a = j['addressed'];
    return AgentControl(
      via: j['via'] is String ? j['via'] as String : 'skip',
      agents: agents,
      toolAgent: owners,
      addressed: a is Map && a['id'] is String && a['label'] is String
          ? (id: a['id'] as String, label: a['label'] as String)
          : null,
    );
  }
}

/// One turn's hand-off as the owner sees it: who has control, which
/// specialist runs now (its label), which have finished (ids), and
/// whether the reply is out.
///
/// [persona]: the agent answering in person ("Manager"), when the owner
/// asked for one — the name on screen for that turn.
typedef AgentTurn = ({
  AgentControl control,
  String? running,
  Set<String> done,
  bool over,
  String? persona,
});

/// The agents' names, by the server's ids (backend agents/manager.js).
const agentLabels = <String, String>{
  'manager': 'Manager',
  'comms': 'Communication',
  'planner': 'Planning',
  'info': 'Information',
  'commerce': 'Shopping and money',
  'creative': 'Creative',
  'device': 'Phone control',
  'memory': 'Memory',
  'records': 'Records',
  'design': 'Design',
};

/// The short name for a label, where a long one would not fit (the orb).
String agentShortName(String label) => const {
      'Communication': 'Comms',
      'Information': 'Info',
      'Shopping and money': 'Shopping',
      'Phone control': 'Phone',
    }[label] ??
    label;
