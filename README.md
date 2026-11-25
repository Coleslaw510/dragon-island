# Dragon Island

![Build IPA](https://github.com/Coleslaw510/dragon-island/actions/workflows/build-ipa.yml/badge.svg)

An offline, single-player creature sanctuary for iPhone and iPad. The app is built
with SwiftUI, SpriteKit and Swift, targets iOS 18, runs in landscape and keeps the
screen free of popups, promo banners, battle passes and live-ops calendars.

The `DragonIsland`, `tools` and `project.yml` paths are the game. The local
workspace also holds unrelated experiments; they are not part of this repository.

## Milestone 1 status

- 301 transparent sprites sliced from `dragon_game_assets_v3.zip` (10 dragons ×
  24 frames, island, habitats, eggs, buildings, farm stages, indicators, arena,
  icons and element badges).
- Game definitions live in JSON, not in Swift tables:
  - `DragonIsland/Resources/GameData/starter_catalog.json`
  - `DragonIsland/Resources/GameData/sprite_manifest.json`
- Landscape SpriteKit island with an animated starter island, a 7×7 isometric
  tile grid, pan and pinch-zoom camera, tap selection and a selection-frame
  sprite.
- Starter habitats, buildings and dragons are placed from the saved state.
- Local JSON save in Application Support with safe defaults and offline-time
  hooks.
- Minimal top HUD: gold, food, gems and XP, plus clean placeholders for breeding,
  hatching, battle and the dragon book.

## Requirements

- macOS with Xcode 16 or newer (iOS 18 SDK).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- Python 3.11+ with Pillow, NumPy and SciPy, only for regenerating art.

## Build the app

```bash
xcodegen generate
open DragonIsland.xcodeproj
```

Select an iPhone or iPad simulator (landscape) and run the `DragonIsland` scheme.
The project is generated from `project.yml`; do not edit the `.xcodeproj` by hand.

## Regenerate the sprite catalog

Place the source archive at `assets_input/dragon_game_assets_v3.zip`, then:

```bash
python3 -m pip install pillow numpy scipy
python3 tools/slice_assets.py
```

The script reads the archive's `manifest.json`, finds frame rectangles from an
alpha matte, removes the light background and grid rules with fractional alpha,
and writes:

- `DragonIsland/Resources/Assets.xcassets/{Dragons,World,UI}` — one imageset per
  sprite frame, plus `AppIcon`, `AccentColor` and `LaunchBackground`.
- `DragonIsland/Resources/GameData/sprite_manifest.json` — frame names, FPS and
  loop flags.
- `DragonIsland/Resources/GameData/starter_catalog.json` — elements, dragons,
  habitats, buildings and the starter layout.

`python3 tools/slice_assets.py --report` prints the detected sheet geometry
without writing files. No sprite coordinate is hand-written.

## Layout

```
DragonIsland/
  DragonIslandApp.swift      app entry point
  Models/                    Codable game + sprite models
  Services/                  catalog loading, save file, starter state
  Game/                      SpriteKit scene, grid, texture loader, node builder
  Views/                     SwiftUI host and HUD
  Resources/Assets.xcassets  sliced art
  Resources/GameData/        JSON definitions
tools/slice_assets.py        asset pipeline
tools/data/catalog_seed.json names, stats and starter layout
project.yml                  XcodeGen spec (iOS 18, landscape, iPhone + iPad)
.github/workflows/build-ipa.yml  unsigned device build and IPA artifact
```

## Code rules

- Every `.swift` file stays under 250 lines.
- Element lists, dragon definitions, habitat mappings and sprite metadata belong
  in JSON.
- Sprite coordinates come from `tools/slice_assets.py`, never from hand editing.
- `xcodebuild` runs on macOS/CI only; Linux work stops at generated Swift,
  `project.yml` and the workflow.
