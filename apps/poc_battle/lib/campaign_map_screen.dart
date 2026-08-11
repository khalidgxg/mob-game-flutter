import 'package:flutter/material.dart';
import 'package:mobrush_save/mobrush_save.dart';

import 'main.dart' show Stage1Screen;
import 'profile_service.dart';

/// Port of `CampaignMapScreen.cs`, now against the real illustrated atlas
/// (`Assets/Resources/Campaign/Atlases/CampaignAtlas_01.png`, found by
/// searching mobGame's `Resources` tree more thoroughly than the first
/// pass — it exists, this repo just hadn't copied it in yet). Node anchors
/// are hand-read off the three castles actually painted into the atlas
/// (forest/bottom = Stage 1, bamboo/middle = Stage 2, desert/top = Stage 3)
/// since `CampaignAtlasDefinition`'s authored normalized anchors aren't in
/// an exported/readable form here — an approximation grounded in the real
/// art, not the invented layout the very first version of this screen used.
///
/// Only Stage 1 has real authored battle content in this app (see
/// `game_content.dart`) — every node launches the same `Stage1Screen`,
/// which is honest about being Stage 1 in its own HUD. Stage 2/3 nodes are
/// shown to prove the progression works end to end, not because their
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

  static const _totalStages = 3;

  // Normalized (fractionX, fractionY) of each stage's castle in
  // campaign_atlas.jpg, read off the image directly (top-left origin).
  static const _nodeAnchors = [
    Offset(0.77, 0.707), // Stage 1 — forest castle, bottom
    Offset(0.80, 0.427), // Stage 2 — bamboo/jungle castle, middle
    Offset(0.70, 0.088), // Stage 3 — desert castle, top
  ];

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          const imageAspect = 700 / 1358; // campaign_atlas.jpg's own aspect
          final width = constraints.maxWidth;
          final height = width / imageAspect;
          return SingleChildScrollView(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Image.asset('assets/campaign/campaign_atlas.jpg',
                      width: width, height: height, fit: BoxFit.cover),
                  for (var i = 0; i < _totalStages; i++)
                    Positioned(
                      left: _nodeAnchors[i].dx * width - 34,
                      top: _nodeAnchors[i].dy * height - 34,
                      child: _StageNode(
                        stageNum: i + 1,
                        stars: _profile.getStageStars('stage_${i + 1}'),
                        unlocked: i + 1 <= unlocked,
                        onTap: i + 1 <= unlocked ? () => _launch('stage_${i + 1}') : null,
                      ),
                    ),
                ],
              ),
            ),
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
  });

  final int stageNum;
  final int stars;
  final bool unlocked;
  final VoidCallback? onTap;

  static const _gold = Color(0xFFFFD133);

  @override
  Widget build(BuildContext context) {
    final badge = stars > 0
        ? 'assets/campaign/CampaignNodeComplete_v1.png'
        : unlocked
            ? 'assets/campaign/CampaignNodeCurrent_v1.png'
            : 'assets/campaign/CampaignNodeLocked_v1.png';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(width: 68, height: 68, child: Image.asset(badge, fit: BoxFit.contain)),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text('STAGE $stageNum',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                if (unlocked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (i) => Icon(Icons.star,
                          size: 10, color: i < stars ? _gold : Colors.white24),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
