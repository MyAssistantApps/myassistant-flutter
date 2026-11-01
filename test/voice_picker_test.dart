// Owner, 2026-11-01: tapping play while a sample played went BACK — the
// disabled play button let the tap through to the row, which chose the
// voice and closed the page.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/screens/voice_picker_screen.dart';
import 'package:myassistant/services/audio/pcm_player.dart';

Uint8List wav() {
  const n = 2400;
  final b = ByteData(44 + n * 2);
  void s(int o, String v) { for (var i = 0; i < 4; i++) { b.setUint8(o + i, v.codeUnitAt(i)); } }
  s(0, 'RIFF'); b.setUint32(4, 36 + n * 2, Endian.little); s(8, 'WAVE'); s(12, 'fmt ');
  b.setUint32(16, 16, Endian.little); b.setUint16(20, 1, Endian.little); b.setUint16(22, 1, Endian.little);
  b.setUint32(24, 24000, Endian.little); b.setUint32(28, 48000, Endian.little);
  b.setUint16(32, 2, Endian.little); b.setUint16(34, 16, Endian.little);
  s(36, 'data'); b.setUint32(40, n * 2, Endian.little);
  return b.buffer.asUint8List();
}

void main() {
  const voices = [
    VoiceCatalogItem(id: 'marin', name: 'Marin', gender: 'female', accent: '', tagline: ''),
    VoiceCatalogItem(id: 'coral', name: 'Coral', gender: 'female', accent: '', tagline: ''),
  ];

  testWidgets('tapping play again stops the sample and never leaves the page', (t) async {
    final played = <String>[];
    final out = SilentOutput();
    final player = PcmPlayer(output: out);
    String? popped;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await Navigator.of(ctx).push<String>(MaterialPageRoute(
                builder: (_) => VoicePickerScreen(
                  selectedId: 'marin',
                  voices: voices,
                  player: player,
                  sampleLoader: (id) async {
                    played.add(id);
                    return wav();
                  },
                ),
              ));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Female voices'));
    await t.pumpAndSettle();

    final playCoral = find.byTooltip('Play a sample of Coral');
    await t.tap(playCoral);
    await t.pump(const Duration(milliseconds: 20));
    expect(played, ['coral']);
    expect(find.byTooltip('Stop the sample of Coral'), findsOneWidget);

    // The bug: this tap used to fall through, pick Coral and go back.
    await t.tap(find.byTooltip('Stop the sample of Coral'));
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text('Female voices'), findsOneWidget, reason: 'still on the picker');
    expect(popped, isNull, reason: 'no voice was chosen');
    expect(find.byTooltip('Play a sample of Coral'), findsOneWidget, reason: 'stopped');

    // Play one, then another: it switches, still on the page.
    await t.tap(find.byTooltip('Play a sample of Marin'));
    await t.pump(const Duration(milliseconds: 20));
    await t.tap(find.byTooltip('Play a sample of Coral'));
    await t.pump(const Duration(milliseconds: 20));
    expect(popped, isNull);
    expect(played, ['coral', 'marin', 'coral']);
    expect(find.byTooltip('Stop the sample of Coral'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));

    // Tapping the NAME still chooses the voice.
    await t.tap(find.text('Coral'));
    await t.pumpAndSettle();
    expect(popped, 'coral');
  });
}
