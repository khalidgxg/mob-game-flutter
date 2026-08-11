import 'package:flutter/material.dart';
import 'package:mobrush_save/mobrush_save.dart';

import 'main.dart' show Stage1Screen;
import 'profile_service.dart';

/// Simplified port of `CampaignMapScreen.cs`. The C# version scrolls one
/// continuous hand-authored atlas image per three-stage group with node
/// positions read off `CampaignAtlasDefinition`'s normalized anchors; no
/// campaign atlas art has been baked for Flutter yet, so this is a plain
/// scrollable list of stage cards instead — same information (lock state,
/// stars, launch), honestly simpler presentation. Swapping in the real
/// atlas later is exactly the `Stack` + `Align(FractionalOffset)` port the
/// migration plan already calls for; nothing here blocks that.
///
/// Only Stage 1 has real authored battle content in this app (see
/// `stage1_content.dart`) — every node launches the same `Stage1Screen`,
/// which is honest about being Stage 1 in its own HUD. Stage 2/3 nodes are
/// shown to prove the progression list works end to end, not because their
/// battles are actually distinct yet.
class CampaignMapScreen extends StatefulWidget {
  const CampaignMapScreen({super.key, required this.profile, required this.profileService});

  final PlayerProfile profile;
  final ProfileService profileService;

  @override
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen> {
  static const _bgNavy = Color(0xFF000B20);
  static const _cardDark = Color(0xFF05112A);
  static const _gold = Color(0xFFFFD133);
  static const _primaryBlue = Color(0xFF0859E6);
  static const _locked = Color(0xFF1A2438);
  static const _textDim = Color(0xFF94A9D9);

  static const _totalStages = 3;

  late PlayerProfile _profile = widget.profile;

  int get _highestUnlocked {
    for (var i = 1; i <= _totalStages; i++) {
      if (_profile.getStageStars('stage_$i') <= 0 && i > 1) return i;
    }
    return _profile.stageStars.where((e) => e.stars > 0).length + 1;
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _highestUnlocked.clamp(1, _totalStages);
    return Scaffold(
      backgroundColor: _bgNavy,
      appBar: AppBar(
        backgroundColor: _bgNavy,
        title: const Text('CAMPAIGN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_profile),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _totalStages,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final stageNum = i + 1;
          final stageId = 'stage_$stageNum';
          final stars = _profile.getStageStars(stageId);
          final isUnlocked = stageNum <= unlocked;
          return _StageNode(
            stageNum: stageNum,
            stars: stars,
            unlocked: isUnlocked,
            onTap: isUnlocked ? () => _launch(stageId) : null,
            cardDark: _cardDark,
            gold: _gold,
            primaryBlue: _primaryBlue,
            locked: _locked,
            textDim: _textDim,
          );
        },
      ),
    );
  }

  Future<void> _launch(String stageId) async {
    final result = await Navigator.of(context).push<PlayerProfile>(
      MaterialPageRoute(
        builder: (_) => Stage1Screen(
          profile: _profile,
          profileService: widget.profileService,
          stageId: stageId,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _profile = result);
  }
}

class _StageNode extends StatelessWidget {
  const _StageNode({
    required this.stageNum,
    required this.stars,
    required this.unlocked,
    required this.onTap,
    required this.cardDark,
    required this.gold,
    required this.primaryBlue,
    required this.locked,
    required this.textDim,
  });

  final int stageNum;
  final int stars;
  final bool unlocked;
  final VoidCallback? onTap;
  final Color cardDark, gold, primaryBlue, locked, textDim;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unlocked ? cardDark : locked,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked ? primaryBlue.withValues(alpha: 0.6) : Colors.white12,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: unlocked ? primaryBlue : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: unlocked
                    ? Text('$stageNum',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))
                    : const Icon(Icons.lock, color: Colors.white38, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STAGE $stageNum',
                    style: TextStyle(
                      color: unlocked ? Colors.white : textDim,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      3,
                      (i) => Icon(Icons.star,
                          size: 16, color: i < stars ? gold : Colors.white24),
                    ),
                  ),
                ],
              ),
            ),
            if (unlocked) const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
