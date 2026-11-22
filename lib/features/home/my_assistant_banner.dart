import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';
import '../../services/auth_service.dart';
import '../../services/my_photo.dart';
import '../../services/persona.dart';
import 'home_fx.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  MY ASSISTANT BANNER — Home's card for everyone without a Pro workspace
///  (owner, 2026-11-21: "Banner for everyone"). A software engineer, a
///  teacher, a student: their own photo (the professional headshot from
///  onboarding, or any photo they set) on the right, "<Profession>
///  Assistant" and what it does on the left.
///
///  Same design language as ProBannerCard, and still (owner, 2026-11-16:
///  no animation on these banners). With no photo yet, the card invites
///  one; tapping it opens their Workspace (plan, automations, actions).
/// ─────────────────────────────────────────────────────────────────────────
class MyAssistantBanner extends StatelessWidget {
  const MyAssistantBanner({super.key, required this.onOpen});

  /// Opens their Workspace (screens/workspace/workspace_screen.dart).
  final VoidCallback onOpen;

  static const _r = 22.0;

  /// "Software Engineer" → "Software Engineer's", "Sales" → "Sales'".
  static String possessive(String s) =>
      s.endsWith('s') ? "$s'" : "$s's";

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([MyPhoto.version, AuthService.instance]),
      builder: (context, _) => FutureBuilder<File?>(
        key: ValueKey(MyPhoto.version.value),
        future: MyPhoto.current(),
        builder: (context, snap) => _card(context, snap.data),
      ),
    );
  }

  Widget _card(BuildContext context, File? photo) {
    final u = AuthService.instance.user;
    final label = (u?.profession ?? '').trim().isNotEmpty
        ? u!.profession.trim()
        : Persona.value == 'personal' || Persona.value.isEmpty
            ? 'Personal'
            : Persona.titleFor(Persona.value);
    final ws = Persona.workspaces[Persona.value] ??
        Persona.workspaces['personal']!;
    final has = photo != null;
    final c = Neon.violet;
    final night = Color.alphaBlend(
        c.withValues(alpha: Neon.isDark ? 0.14 : 0.08),
        Color.lerp(Neon.bg, Colors.black, Neon.isDark ? 0.35 : 0.0)!);
    final r = BorderRadius.circular(_r);
    final title = label == 'Personal'
        ? 'Your Personal\nAssistant'
        : '${possessive(label)}\nAssistant';
    return Semantics(
      button: true,
      label: '${title.replaceAll('\n', ' ')}. ${ws.perks.first}',
      excludeSemantics: true,
      child: SizedBox(
        height: 172,
        child: CustomPaint(
          foregroundPainter: AuroraBorderPainter(
              t: const AlwaysStoppedAnimation(0.62),
              radius: _r,
              color: c,
              width: 1.4),
          child: Material(
            borderRadius: r,
            clipBehavior: Clip.antiAlias,
            color: night,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onOpen();
              },
              child: Ink(
                decoration:
                    BoxDecoration(borderRadius: r, boxShadow: Neon.glassShadow),
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        right: box.maxWidth * 0.12,
                        top: -40,
                        child: IgnorePointer(
                          child: Container(
                            width: box.maxWidth * 0.55,
                            height: box.maxWidth * 0.55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                c.withValues(alpha: 0.38),
                                c.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: box.maxWidth * 0.5,
                        child: has
                            ? ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (r) => const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  stops: [0, 0.4, 1],
                                  colors: [
                                    Colors.transparent,
                                    Colors.white,
                                    Colors.white
                                  ],
                                ).createShader(r),
                                child: Image.file(photo,
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0, -0.4),
                                    filterQuality: FilterQuality.high,
                                    gaplessPlayback: true),
                              )
                            : _placeholder(c),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 46,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                night.withValues(alpha: 0),
                                night.withValues(alpha: 0.6)
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: NeonType.manrope(21, FontWeight.w800)
                                      .copyWith(
                                          color: Neon.textHi,
                                          letterSpacing: -0.4,
                                          height: 1.1)),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                    'Plan your day, automate routines and get work done.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Neon.textLo,
                                        fontSize: 13,
                                        height: 1.3)),
                              ),
                              const _Pill(
                                label: 'Open Workspace',
                                icon: Icons.dashboard_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(Color c) => Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: 0.14),
            border: Border.all(color: c.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Icon(Icons.person_rounded, size: 46, color: c),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Color.lerp(Neon.accentFill, Colors.white, 0.18)!,
          Neon.accentFill,
        ]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Neon.accentFill.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: -4)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: NeonType.manrope(13, FontWeight.w800)
                  .copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
