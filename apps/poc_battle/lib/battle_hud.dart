import 'package:flutter/material.dart';
import 'package:mobrush_save/mobrush_save.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'stage1_game.dart';
import 'ui_theme.dart';

/// Port of `Hud.cs` (914 lines of hand-built `RectTransform` UI) as ordinary
/// Flutter widgets laid over the Flame `GameWidget`, the same hybrid this
/// whole app is built on. Ports the real elements: pause button + modal
/// (Resume/Restart/Map/Home), mission card, coin/gem resources, the
/// vertical energy meter, the three ability buttons (Freeze/Fireball/
/// Lightning) with real charge counts wired to `BattleAbilities.tryUse`,
/// the force band (`player vs enemy` live counts), ammo + base-health
/// chips, and the BATTLE/RUSH button — `TryRush` ported to
/// `BattleRound.tryRush` for this HUD to call.
///
/// Not ported: the wave dot tracker (`Hud.cs`'s `WaveIndex`/`WaveCount`
/// comes from `StageDefinition.battle.waveCount`, authored data that isn't
/// in the `content.json` export this app reads — showing a fake number
/// would be worse than not showing one), the multi-character squad-card
/// row (`LoadoutManager.CharacterRoster` — this app only ever has one
/// playable character, "Recruit"), and `PositionCannonMeters`' exact
/// screen-tracked ammo/health chip placement (fixed position here instead
/// of following the cannon's projected screen point).
class BattleHud extends StatefulWidget {
  const BattleHud({
    super.key,
    required this.game,
    required this.profile,
    required this.onRestart,
    required this.onOpenMap,
    required this.onGoHome,
  });

  final Stage1Game game;
  final PlayerProfile? profile;
  final VoidCallback onRestart;
  final VoidCallback onOpenMap;
  final VoidCallback onGoHome;

  @override
  State<BattleHud> createState() => _BattleHudState();
}

class _BattleHudState extends State<BattleHud> {
  static const _blueLight = MobRushTheme.blueLight;
  static const _gold = MobRushTheme.gold;
  static const _goldLight = MobRushTheme.goldBright;
  static const _red = MobRushTheme.red;

  String? _hint;
  Color _hintColor = Colors.white;

  void _showHint(String text, Color color) {
    setState(() {
      _hint = text;
      _hintColor = color;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _hint == text) setState(() => _hint = null);
    });
  }

  void _tryBattleAction() {
    final game = widget.game;
    if (!game.battleStarted) {
      game.startBattle();
      _showHint('BATTLE STARTED', _goldLight);
      return;
    }
    final result = game.tryRush();
    _showHint(result, result == 'RUSH DEPLOYED' ? _goldLight : const Color(0xFFFF7057));
  }

  void _tryAbility(Ability ability) {
    final result = widget.game.tryAbility(ability);
    final ok = result != 'NO VALID TARGET' && result != 'START THE BATTLE FIRST';
    _showHint(result, ok ? _goldLight : const Color(0xFFFF7057));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: Stream.periodic(const Duration(milliseconds: 150)),
      builder: (context, _) {
        if (!widget.game.simReady) return const SizedBox.shrink();
        final round = widget.game.round;
        return Stack(
          children: [
            Positioned(top: 12, left: 12, child: _pauseButton()),
            Positioned(top: 12, left: 74, child: _missionCard()),
            Positioned(top: 12, right: 12, child: _resourcesCard()),
            Positioned(
              left: 12,
              top: 0,
              bottom: 130,
              child: Center(child: _energyMeter(round)),
            ),
            Positioned(
              right: 12,
              top: 0,
              bottom: 130,
              child: Center(child: _abilityRail(round)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _commandDeck(round),
            ),
            if (_hint != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 132,
                child: Center(
                  child: Text(
                    _hint!,
                    style: TextStyle(
                      color: _hintColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _pauseButton() {
    return _framed(
      onTap: _openPauseModal,
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(Icons.pause, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _missionCard() {
    return _framed(
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MISSION', style: TextStyle(color: Color(0xFFB8C8FF), fontSize: 10, fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('Defeat the\nEnemy Castle', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _resourcesCard() {
    final profile = widget.profile;
    return _framed(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/home/icons/icon_coin.png', width: 18, height: 18),
            const SizedBox(width: 6),
            Text('${profile?.currency ?? 0}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 12),
            Image.asset('assets/home/icons/icon_gem.png', width: 18, height: 18),
            const SizedBox(width: 6),
            Text('${profile?.gems ?? 0}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _energyMeter(BattleRound round) {
    final ratio = (round.abilities.energy / round.abilities.maxEnergy).clamp(0.0, 1.0);
    return Container(
      width: 40,
      height: 180,
      decoration: BoxDecoration(
        gradient: MobRushTheme.glassFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MobRushTheme.goldEdge, width: 2),
        boxShadow: const [MobRushTheme.dropShadow],
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: ratio,
                widthFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: _blueLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            round.abilities.energy.toStringAsFixed(0),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _abilityRail(BattleRound round) {
    Widget button(Ability ability, String label, Color color) {
      final charges = round.abilities.chargesFor(ability);
      return GestureDetector(
        onTap: charges > 0 ? () => _tryAbility(ability) : null,
        child: Opacity(
          opacity: charges > 0 ? 1 : 0.4,
          child: Container(
            width: 64,
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: MobRushTheme.glassFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                MobRushTheme.dropShadow,
                if (charges > 0) BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  switch (ability) {
                    Ability.freeze => Icons.ac_unit,
                    Ability.fireball => Icons.local_fire_department,
                    Ability.lightning => Icons.bolt,
                  },
                  color: color,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text('x$charges', style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Ability.freeze, 'FREEZE', _blueLight),
        button(Ability.fireball, 'FIRE', const Color(0xFFFF5720)),
        button(Ability.lightning, 'BOLT', const Color(0xFF43ABFF)),
      ],
    );
  }

  Widget _commandDeck(BattleRound round) {
    return Container(
      decoration: const BoxDecoration(
        gradient: MobRushTheme.glassFill,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: MobRushTheme.goldEdge, width: 2)),
        boxShadow: [MobRushTheme.dropShadow],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: MobRushTheme.glassFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.groups, color: Color(0xFF4DA6FF), size: 22),
                const SizedBox(width: 8),
                Text('${round.livePlayerMobCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const Spacer(),
                const Text('VS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${round.liveEnemyMobCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                const Icon(Icons.groups, color: Color(0xFFFF5A50), size: 22),
                const SizedBox(width: 14),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ammoChip(round),
              const SizedBox(width: 10),
              _baseHealthChip(round),
              const Spacer(),
              _battleButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ammoChip(BattleRound round) {
    return _statChip(
      icon: Icons.circle,
      iconColor: _gold,
      text: '${round.cannon.reserve}/${round.cannon.ammoCapacity}',
    );
  }

  Widget _baseHealthChip(BattleRound round) {
    return _statChip(
      icon: Icons.favorite,
      iconColor: const Color(0xFF29D06B),
      text: '${round.base.currentHealth}',
    );
  }

  Widget _statChip({required IconData icon, required Color iconColor, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: MobRushTheme.glassFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _battleButton() {
    final game = widget.game;
    final label = !game.battleStarted ? 'BATTLE' : 'RUSH  ${game.rushUnitCount}';
    return GestureDetector(
      onTap: _tryBattleAction,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Colors.black87, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _framed({required Widget child, VoidCallback? onTap}) {
    return GlassPanel(onTap: onTap, radius: 10, child: child);
  }

  void _openPauseModal() {
    widget.game.pauseEngine();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => AlertDialog(
        backgroundColor: MobRushTheme.bgDeep,
        title: const Text('BATTLE PAUSED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pauseAction('RESUME', const Color(0xFF1FA854), () {
              widget.game.resumeEngine();
              Navigator.of(context).pop();
            }),
            const SizedBox(height: 10),
            _pauseAction('RESTART', _blueLight, () {
              widget.game.resumeEngine();
              Navigator.of(context).pop();
              widget.onRestart();
            }),
            const SizedBox(height: 10),
            _pauseAction('MAP', MobRushTheme.bgNavy, () {
              widget.game.resumeEngine();
              Navigator.of(context).pop();
              widget.onOpenMap();
            }),
            const SizedBox(height: 10),
            _pauseAction('MAIN MENU', _red, () {
              widget.game.resumeEngine();
              Navigator.of(context).pop();
              widget.onGoHome();
            }),
          ],
        ),
      ),
    );
  }

  Widget _pauseAction(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
