# Crowd sprite export drop-in

This folder is where the real bake from Unity goes.

1. In `mobGame`, run **MobRush ▸ Bake Crowd Sprite Atlas (Flutter PoC)**.
   It writes `Assets/Resources/CrowdSpriteExport/atlas.png` and `atlas.json`.
2. Copy both files into this folder, next to this README.
3. `flutter pub get` (picks up the new asset), then `flutter run`.

`CharacterAtlas.load()` in `lib/sprite_atlas.dart` looks for `atlas.png` +
`atlas.json` here first. If they are not present, the app falls back to the
procedural placeholder figures automatically — nothing else needs to change
to switch between the two.
