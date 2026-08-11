import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'battle_game.dart';
import 'structure_preview_game.dart';

void main() {
  runApp(const PocApp());
}

class PocApp extends StatelessWidget {
  const PocApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ?preview=structures shows Phase 3's castle/gate artwork scene instead
    // of the crowd performance PoC — a separate screen on purpose, so
    // looking at it can never perturb the already-measured crowd numbers.
    final showStructures = Uri.base.queryParameters['preview'] == 'structures';
    return MaterialApp(
      title: 'MobRush — Flutter/Flame proof of concept',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: showStructures
          ? GameWidget(game: StructurePreviewGame())
          : const BattleScreen(),
    );
  }
}

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  /// Starting unit count, overridable as `?units=700` so a benchmark harness
  /// can sweep the range without touching the slider.
  static int get _initialCount {
    final raw = Uri.base.queryParameters['units'];
    final parsed = raw == null ? null : int.tryParse(raw);
    return (parsed ?? 350).clamp(50, 4000);
  }

  static bool get _frozen => Uri.base.queryParameters['frozen'] == '1';

  late final BattleGame _game =
      BattleGame(targetMobs: _initialCount, frozen: _frozen);
  int _count = _initialCount;

  @override
  Widget build(BuildContext context) {
    // The whole point of the hybrid: the battle is a Flame surface, and every
    // piece of UI on top of it is an ordinary Flutter widget. The HUD, the
    // shop, the campaign map — all of that is built with the framework's own
    // layout system rather than by hand-positioning RectTransforms, which is
    // what `UiKit.cs` spends 674 lines doing.
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          const _Telemetry(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Controls(
              count: _count,
              onChanged: (v) {
                setState(() => _count = v);
                _game.setMobCount(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Telemetry extends StatefulWidget {
  const _Telemetry();

  @override
  State<_Telemetry> createState() => _TelemetryState();
}

class _TelemetryState extends State<_Telemetry> {
  @override
  Widget build(BuildContext context) {
    final game = context.findAncestorStateOfType<_BattleScreenState>()!._game;
    return Positioned(
      top: 48,
      left: 16,
      child: StreamBuilder<void>(
        stream: Stream.periodic(const Duration(milliseconds: 250)),
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FPS        ${game.fps.toStringAsFixed(1)}'),
                  Text('frame      ${game.frameMs.toStringAsFixed(2)} ms'),
                  Text('simulation ${game.simMs.toStringAsFixed(2)} ms'),
                  Text('drawn      ${game.drawn}  (1 batched call)'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      color: Colors.black.withValues(alpha: 0.55),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Units: $count',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: count.toDouble(),
            min: 50,
            max: 4000,
            divisions: 39,
            label: '$count',
            onChanged: (v) => onChanged(v.round()),
          ),
          const Text(
            'GameConfig.maxMobs in the Unity build is 350',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
