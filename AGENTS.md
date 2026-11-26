# Dragon Island repository guide

## What this is

Offline single-player iOS game (Swift + SpriteKit + SwiftUI), iOS 18 minimum,
landscape only, iPhone and iPad. The active app lives in `DragonIsland/`.
Other folders (`server.py`, `nfl-stats`, `OpenHandsClient`,
`dc-legacy-private-server`) are unrelated experiments.

## Hard rules

- Keep every `.swift` file under 250 lines. Check with
  `wc -l DragonIsland/**/*.swift DragonIsland/*.swift`.
- Game definitions, element lists, habitat mappings and sprite metadata live in
  JSON under `DragonIsland/Resources/GameData/` or `tools/data/`.
- Never hand-write sprite coordinates. `tools/slice_assets.py` derives every
  frame from the source sheets using `manifest.json` plus alpha projection.
- Do not run `xcodebuild` in the Linux workspace. Validate Swift by review and
  let GitHub Actions build on macOS.
- UI stays uncluttered: no popup spam, promo banners, battle passes or
  live-ops calendars.

## Common commands

```bash
# Slice art + rebuild JSON (needs assets_input/dragon_game_assets_v3.zip)
python3 tools/slice_assets.py
python3 tools/slice_assets.py --report     # geometry only

# Inspect project spec / workflow syntax
python3 -c "import yaml; yaml.safe_load(open('project.yml'))"

# On macOS only
xcodegen generate
xcodebuild -project DragonIsland.xcodeproj -scheme DragonIsland \
  -sdk iphonesimulator -configuration Debug build
```

## Asset pipeline notes

- Source sheets are 4 rows × 6 columns for dragons: idle, walk, fly, action.
- `build_matte` keeps soft alpha near solid art and drops wide painted shadows,
  then un-blends colour to avoid a light halo.
- `strip_grid_lines` removes 1–3 px rules; animation crops are inset by 3 px so
  a cell rule never becomes a frame edge stripe.
- Every animation frame shares one canvas per dragon so SpriteKit texture swaps
  do not jitter.
- JSON output is deterministic; rerunning the script should produce the same
  names and order. `--keep` preserves existing imageset folders.

## iOS conventions

- `GameStateStore` is the single source of truth; it saves atomically to
  Application Support (`DragonIsland/island_save.json`) and reseeds on schema
  mismatch while keeping a `*.corrupt.json` backup.
- `IslandScene` owns the `SKCameraNode` and all touch handling. `IslandGrid`
  converts between tiles and isometric points. `IslandWorldBuilder` only turns
  save records into nodes.
- Sprite names follow `dragon_<id>_<state>_<frame>`, `habitat_<element>`,
  `building_<name>`, `farm_<stage>`, `indicator_<name>`, `icon_<name>`,
  `badge_<element>`, `island_starter_<n>`.
- `SpriteSheetLoader` reads `sprite_manifest.json`; if you add art, update the
  manifest and loader lookups together.
- Battle maths is pure in `Game/BattleEngine.swift`; `Game/BattleSession.swift`
  drives turns and payout. Every balance number (team size, element modifiers,
  cooldowns, XP and gold/food) lives in `Resources/GameData/battle_rules.json`.
- `TopHudView` opens `BattleView`; a win calls
  `GameStateStore.applyBattleRewards` and saves through the store.

## CI

`.github/workflows/build-ipa.yml` uses `macos-latest`, installs XcodeGen, builds
an unsigned Release app and uploads `DragonIsland-unsigned.ipa`. Signed-archive
steps and the required secrets are documented in comments at the bottom.
