import 'api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  WORKSPACE — the dashboard for every profession without a Pro workspace
///  (engineers, teachers, CAs, drivers, students, homemakers…). Mirrors the
///  backend's src/workspace/ (GET /workspace, PUT /workspace/routines/:id,
///  POST /workspace/plan). Parsing is defensive: an older server without
///  /workspace answers null and the screen says so.
/// ─────────────────────────────────────────────────────────────────────────

class DayBlock {
  final String start;
  final String end;
  final String title;
  final String kind; // focus | meeting | admin | break | task | personal
  const DayBlock(this.start, this.end, this.title, this.kind);

  factory DayBlock.fromJson(Map<String, dynamic> j) => DayBlock(
        j['start'] as String? ?? '',
        j['end'] as String? ?? '',
        j['title'] as String? ?? '',
        j['kind'] as String? ?? 'task',
      );

  /// Minutes since midnight of [start] / [end] (for "now" and lengths).
  int get startMin => _mins(start);
  int get endMin => _mins(end);
  static int _mins(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }
}

class PackRoutine {
  final String id;
  final String title;
  final String detail;
  final String time; // the pack's default "HH:MM"
  final String repeat; // daily | weekly | monthly
  final int? weekday; // 0 = Sunday
  final int? monthDay;
  const PackRoutine(this.id, this.title, this.detail, this.time, this.repeat,
      {this.weekday, this.monthDay});

  factory PackRoutine.fromJson(Map<String, dynamic> j) => PackRoutine(
        j['id'] as String? ?? '',
        j['title'] as String? ?? '',
        j['detail'] as String? ?? '',
        j['time'] as String? ?? '09:00',
        j['repeat'] as String? ?? 'daily',
        weekday: (j['weekday'] as num?)?.toInt(),
        monthDay: (j['monthDay'] as num?)?.toInt(),
      );

  static const _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  /// "Every day", "Every Friday", "Monthly on the 25th".
  String get when => switch (repeat) {
        'weekly' => 'Every ${_days[(weekday ?? 1).clamp(0, 6)]}',
        'monthly' => 'Monthly on the ${_ordinal(monthDay ?? 1)}',
        _ => 'Every day',
      };

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }
}

class PackAction {
  final String label;
  final String icon; // Material icon name, mapped in the screen
  final String ask;
  const PackAction(this.label, this.icon, this.ask);
  factory PackAction.fromJson(Map<String, dynamic> j) => PackAction(
      j['label'] as String? ?? '', j['icon'] as String? ?? '', j['ask'] as String? ?? '');
}

class WorkspacePack {
  final String id;
  final String title;
  final String tagline;
  final int focus;
  final List<DayBlock> day;
  final List<PackRoutine> routines;
  final List<PackAction> actions;
  const WorkspacePack({
    required this.id,
    required this.title,
    required this.tagline,
    required this.focus,
    required this.day,
    required this.routines,
    required this.actions,
  });

  factory WorkspacePack.fromJson(Map<String, dynamic> j) => WorkspacePack(
        id: j['id'] as String? ?? 'general',
        title: j['title'] as String? ?? 'Workspace',
        tagline: j['tagline'] as String? ?? '',
        focus: (j['focus'] as num?)?.toInt() ?? 60,
        day: _list(j['day'], DayBlock.fromJson),
        routines: _list(j['routines'], PackRoutine.fromJson),
        actions: _list(j['actions'], PackAction.fromJson),
      );
}

class RoutineState {
  final String id;
  final bool on;
  final String time;
  final int? nextAt;
  const RoutineState(this.id, this.on, this.time, this.nextAt);
  factory RoutineState.fromJson(Map<String, dynamic> j) => RoutineState(
        j['id'] as String? ?? '',
        j['on'] == true,
        j['time'] as String? ?? '',
        (j['nextAt'] as num?)?.toInt(),
      );
}

class TodayReminder {
  final int id;
  final String text;
  final int at;
  const TodayReminder(this.id, this.text, this.at);
}

class TodayPromise {
  final int id;
  final String text;
  final String owedTo;
  final int? dueAt;
  const TodayPromise(this.id, this.text, this.owedTo, this.dueAt);
}

class Priority {
  final int id;
  final String title;
  final bool done;
  const Priority(this.id, this.title, this.done);
}

class DayPlan {
  final List<DayBlock> blocks;
  final String note;
  final String source; // ai | template
  const DayPlan(this.blocks, this.note, this.source);
  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        _list(j['blocks'], DayBlock.fromJson),
        j['note'] as String? ?? '',
        j['source'] as String? ?? 'template',
      );
}

class WorkspaceOverview {
  final String day;
  final String profession;
  final WorkspacePack pack;
  final Map<String, RoutineState> routines;
  final List<TodayReminder> reminders;
  final List<TodayPromise> promises;
  final List<Priority> priorities;
  final int focusMinutesToday;
  final DayPlan? plan;
  const WorkspaceOverview({
    required this.day,
    required this.profession,
    required this.pack,
    required this.routines,
    required this.reminders,
    required this.promises,
    required this.priorities,
    required this.focusMinutesToday,
    required this.plan,
  });

  int get routinesOn => routines.values.where((r) => r.on).length;

  factory WorkspaceOverview.fromJson(Map<String, dynamic> j) {
    final today = (j['today'] as Map?)?.cast<String, dynamic>() ?? const {};
    final mom = (j['momentum'] as Map?)?.cast<String, dynamic>() ?? const {};
    final focus = (mom['focus'] as Map?)?.cast<String, dynamic>() ?? const {};
    return WorkspaceOverview(
      day: j['day'] as String? ?? '',
      profession: j['profession'] as String? ?? '',
      pack: WorkspacePack.fromJson((j['pack'] as Map?)?.cast<String, dynamic>() ?? const {}),
      routines: {
        for (final r in _list(j['routines'], RoutineState.fromJson)) r.id: r,
      },
      reminders: _list(
          today['reminders'],
          (m) => TodayReminder((m['id'] as num?)?.toInt() ?? 0, m['text'] as String? ?? '',
              (m['at'] as num?)?.toInt() ?? 0)),
      promises: _list(
          today['promises'],
          (m) => TodayPromise((m['id'] as num?)?.toInt() ?? 0, m['text'] as String? ?? '',
              m['owedTo'] as String? ?? '', (m['dueAt'] as num?)?.toInt())),
      priorities: _list(
          mom['priorities'],
          (m) => Priority((m['id'] as num?)?.toInt() ?? 0, m['title'] as String? ?? '',
              m['done'] == true)),
      focusMinutesToday: (focus['todayMin'] as num?)?.toInt() ?? 0,
      plan: j['plan'] is Map ? DayPlan.fromJson((j['plan'] as Map).cast<String, dynamic>()) : null,
    );
  }
}

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) => v is List
    ? v.whereType<Map>().map((m) => f(m.cast<String, dynamic>())).toList(growable: false)
    : <T>[];

class WorkspaceService {
  WorkspaceService._();

  static Future<WorkspaceOverview?> load() async {
    final j = await ApiService.getJson('/workspace');
    if (j == null || j['pack'] is! Map) return null;
    return WorkspaceOverview.fromJson(j);
  }

  static Future<WorkspaceOverview?> setRoutine(String id, {required bool on, String? time}) async {
    final j = await ApiService.sendJson('/workspace/routines/$id',
        method: 'PUT', body: {'on': on, if (time != null) 'time': time});
    if (j == null || j['pack'] is! Map) return null;
    return WorkspaceOverview.fromJson(j);
  }

  static Future<DayPlan?> plan({bool force = false}) async {
    final j = await ApiService.sendJson('/workspace/plan',
        body: {'force': force}, timeout: const Duration(seconds: 40));
    if (j == null || j['blocks'] is! List) return null;
    return DayPlan.fromJson(j);
  }

  /// Today's 3 (backend /momentum): replaces the day's list.
  static Future<bool> setPriorities(String day, List<Priority> items) async {
    final j = await ApiService.sendJson('/momentum/priorities', method: 'PUT', body: {
      'day': day,
      'items': [
        for (final p in items) {if (p.id > 0) 'id': p.id, 'title': p.title},
      ],
    });
    return j != null && j['ok'] != false;
  }

  static Future<bool> tickPriority(int id, bool done) async {
    final j = await ApiService.sendJson('/momentum/priorities/$id',
        method: 'PATCH', body: {'done': done});
    return j != null && j['ok'] != false;
  }
}
