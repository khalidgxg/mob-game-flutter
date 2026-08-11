import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_save/mobrush_save.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'battle_game.dart';
import 'home_screen.dart';
import 'profile_service.dart';
import 'stage1_game.dart';
import 'structure_preview_game.dart';

void main() {
  runApp(const PocApp());
}

class PocApp extends StatelessWidget {
  const PocApp({super.key});

  @override
  Widget build(BuildContext context) {
    final preview = Uri.base.queryParameters['preview'];
    return MaterialApp(
      title: 'MobRush — Flutter/Flame proof of concept',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: switch (preview) {
        // Phase 3's castle/gate artwork scene, static. Kept separate from
        // the crowd performance PoC so looking at it can never perturb the
        // already-measured crowd numbers.
        'structures' => GameWidget(game: StructurePreviewGame()),
        // Phase 4's gate scene: BattleRound driven by real tap/drag input,
        // rendered through the depth-sorted crowd+structure renderer.
        'stage1' => const Stage1Screen(),
        'crowd' => const BattleScreen(),
        // The APK build has no query string to read, so on-device testing
        // needs an in-app picker instead of the web-only ?preview= links.
        'picker' => const _ScenePicker(),
        // Phase 5: HomeMenu.cs's port is the real entry point now.
        _ => const HomeScreen(),
      },
    );
  }
}

/// On-device entry point: the three PoC scenes behind one tap each, since
/// an installed APK has no URL bar to carry `?preview=...` in.
class _ScenePicker extends StatelessWidget {
  const _ScenePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'MobRush — Flutter/Flame PoC',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const Stage1Screen()),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Text('Stage 1 — playable battle (Phase 4)'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BattleScreen()),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Text('Crowd performance benchmark (Phase 0)'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GameWidget(game: StructurePreviewGame()),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Text('Castle/gate artwork (Phase 3)'),
              ),
            ),
          ],
        ),
      ),
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

/// Phase 4's playable scene: drag/tap to aim and fire the cannon at Stage
/// 1's real towers. The HUD strip is deliberately minimal — energy and
/// outcome only — full parity with `Hud.cs`'s ability buttons and wave
/// tracker is separate work this phase does not claim to finish.
///
/// Confirmed on a real Android device (arm64 APK build): the HUD renders
/// correctly. The earlier report of missing HUD text was specific to this
/// project's headless Chromium/CanvasKit/SwiftShader screenshot pipeline,
/// not a real bug — on-device, every `Positioned` sibling in the `Stack`
/// paints as expected.
///
/// What IS real, confirmed on-device too: the lane doesn't fill the
/// viewport — `GroundRenderer` only draws the lane quad itself (a fixed
/// ±24-unit depth strip), with no sky/background art behind it, so the
/// screen letterboxes to black above, below, and beside the lane. That's
/// expected for this PoC's scope — it exists to prove the simulation and
/// the depth-sorted renderer agree with each other, not to art-direct a
/// finished frame — and filling the rest of the screen is later polish
/// work, not a Phase 4 gate item.
class Stage1Screen extends StatefulWidget {
  const Stage1Screen({super.key, this.profile, this.profileService, this.stageId = 'stage_1'});

  /// When supplied (Home always supplies one), a win/lose ends the round
  /// with `GameOverScreen.cs`'s reward-and-return flow: `RewardCalculator`
  /// and `StarRating` compute the payout the same way the live game does,
  /// the profile is updated and persisted, and the result is popped back
  /// to whoever pushed this screen. Left null for the raw scene-picker
  /// entry point, which has no profile to update.
  final PlayerProfile? profile;
  final ProfileService? profileService;
  final String stageId;

  @override
  State<Stage1Screen> createState() => _Stage1ScreenState();
}

class _Stage1ScreenState extends State<Stage1Screen> {
  late final Stage1Game _game = Stage1Game()..onOutcome = _handleOutcome;

  static const _baseCoins = 50;
  static const _parSeconds = 90.0;

  Future<void> _handleOutcome(RoundOutcome outcome) async {
    final profile = widget.profile;
    RoundReward? reward;
    if (outcome == RoundOutcome.win && profile != null) {
      final stars = StarRating.evaluate(
        baseHealthFraction: _game.round.base.healthFraction,
        elapsedSeconds: _game.elapsedSeconds,
        parSeconds: _parSeconds,
      );
      final previousStars = profile.getStageStars(widget.stageId);
      final firstWinOfDay = profile.lastWinDayUtc != PlayerProfile.todayUtc();
      reward = RewardCalculator.compute(
        baseCoins: _baseCoins,
        stars: stars,
        previousStars: previousStars,
        firstWinOfDay: firstWinOfDay,
      );
      profile.currency += reward.coins;
      profile.setStageStars(widget.stageId, reward.stars);
      profile.lastWinDayUtc = PlayerProfile.todayUtc();
      await widget.profileService?.save(profile);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1523),
        title: Text(
          outcome == RoundOutcome.win ? 'VICTORY!' : 'DEFEAT',
          style: TextStyle(
            color: outcome == RoundOutcome.win ? const Color(0xFF29B863) : const Color(0xFFE0554A),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: reward == null
            ? const Text('The enemy reached your base.', style: TextStyle(color: Colors.white70))
            : Text(
                '+${reward.coins} coins  ·  ${reward.stars} ${reward.stars == 1 ? 'star' : 'stars'}'
                '${reward.firstClear ? '\nFirst clear!' : ''}',
                style: const TextStyle(color: Colors.white),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('HOME'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).maybePop(widget.profile),
            ),
          ),
          Positioned(
            top: 48,
            left: 16,
            child: StreamBuilder<void>(
              stream: Stream.periodic(const Duration(milliseconds: 200)),
              builder: (context, _) {
                if (!_game.simReady) return const SizedBox.shrink();
                final r = _game.round;
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
                        Text('FPS       ${_game.fps.toStringAsFixed(1)}'),
                        Text('sim       ${_game.simMs.toStringAsFixed(2)} ms'),
                        Text('outcome   ${r.outcome.name}'),
                        Text('ammo      ${r.cannon.reserve}/${r.cannon.ammoCapacity}'),
                        Text('energy    ${r.abilities.energy.toStringAsFixed(0)}'
                            '/${r.abilities.maxEnergy.toStringAsFixed(0)}'),
                        Text('base hp   ${r.base.currentHealth}/${r.base.maxHealth}'),
                        Text('towers    ${r.towers.where((t) => t.alive).length}'
                            '/${r.towers.length} standing'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Text(
              'Drag anywhere on the lane to aim and fire',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
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
