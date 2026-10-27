# Architecture

## The one rule

> **`src/core` never touches the scene tree.**

Every gameplay rule — pathing, placement, targeting, damage, economy, wave composition,
persistence, localisation — is a plain `RefCounted` or `static` class that operates on
dictionaries and vectors. Nodes exist only to *draw* those results and to relay input. This
single constraint buys the entire test strategy: 167 assertions run headlessly in ~200 ms, no
scene has to be booted, and a balance change can be validated before it is ever rendered.

The second rule is that **content lives in `data/`, not in code.** A tower, an enemy or a wave
is a JSON entry; adding one is a data change plus two localisation strings.

## Layers

```
                 scenes/*.tscn           (5 thin scenes: they only .instantiate a script)
                       │
┌──────────────────────┴───────────────────────────────────────────────────────┐
│ src/ui        screens & widgets — Theme, layout, input, no game rules        │
│  screen.js ─ main_menu ─ level_select ─ settings_screen ─ credits_screen     │
│  hud ─ tower_panel ─ build_button ─ ability_button ─ overlay ─ ui_kit        │
│  theme_factory ─ icons ─ glyph ─ value_slider ─ toggle_switch ─ backdrop     │
├──────────────────────────────────────────────────────────────────────────────┤
│ src/game      scene-tree gameplay: entities & orchestration                  │
│  game_screen (the level controller) ─ board ─ wave_director ─ abilities      │
│  tower ─ enemy ─ projectile ─ fx                                             │
├──────────────────────────────────────────────────────────────────────────────┤
│ src/core      engine-free rules (pure data in → data out)                    │
│  game_data ─ balance ─ tower_stats ─ path_model ─ build_grid ─ targeting     │
│  damage ─ wave_plan ─ save_store ─ settings_model ─ l10n ─ palette           │
├──────────────────────────────────────────────────────────────────────────────┤
│ src/autoload  App (state, routing, pause) · Loc (strings) · Audio (buses)    │
└──────────────────────────────────────────────────────────────────────────────┘
```

Dependencies point **downwards only**. `core` knows nothing about any other layer; `game`
may read `core`; `ui` reads both but never mutates game state directly — it calls the public
API of `GameScreen` and reacts to signals.

## Files, and why each exists

| File | Lines | Responsibility |
|---|---:|---|
| `core/game_data.gd` | 165 | Loads `data/*.json` once, validates it (fail loudly, not silently), exposes typed accessors |
| `core/balance.gd` | 113 | Every global tuning curve and difficulty preset, in one reviewable place |
| `core/tower_stats.gd` | 141 | Resolves tower definition + level + module + beacon auras → final derived stats |
| `core/path_model.gd` | 84 | Waypoint walking with **leftover-distance carry** between segments; corner-cut air route |
| `core/build_grid.gd` | 166 | Marks path/reserved cells, `can_place()` returning a **reason key** rather than a bool |
| `core/targeting.gd` | 139 | Five priorities (first/last/closest/strongest/weakest) over a pre-filtered candidate list |
| `core/damage.gd` | 71 | Armour, resistances, min-damage floor, splash falloff, chain falloff, mark bonus |
| `core/wave_plan.gd` | 81 | Turns a level's wave list into spawn events + gold rewards; expansion preview |
| `core/save_store.gd` | 121 | Versioned `user://` save with atomic write, backup recovery and migration |
| `core/settings_model.gd` | 75 | Defaults, clamping and validation for the settings dictionary |
| `core/l10n.gd` | 394 | EN/RU string table + `tf()` placeholder formatting |
| `game/game_screen.gd` | 982 | The level controller: wires everything, owns the public API the tests drive |
| `game/enemy.gd` | 230 | Movement along the path, status effects, menders, splitting, leak handling |
| `game/tower.gd` | 177 | Cooldown, targeting query, fire → projectile/beam/chain, aura application |
| `game/projectile.gd` | ~110 | Homing or ballistic travel, impact, splash and chain resolution |
| `game/board.gd` | 200 | Draws terrain/path/grid procedurally, maps screen ⇄ cell, decorations |
| `game/wave_director.gd` | 140 | Countdown, early call, spawn scheduling, wave completion detection |
| `game/abilities.gd` | 104 | Airstrike + overclock: targeting cursor, cooldown timers, effects |
| `game/fx.gd` | 180 | **One node** for all transient effects, drawn in a single pass, no per-hit node churn |
| `ui/theme_factory.gd` | 205 | Builds the whole visual identity as a `Theme` in code (cached, invalidated on exit) |
| `ui/ui_kit.gd` | 176 | Shared builders: cards, chips, buttons, stat rows — keeps the screens declarative |
| `ui/hud.gd` | 346 | Top/bottom bars, status card, wave preview, speed and pause |
| `ui/tower_panel.gd` | 214 | Inspect/upgrade/module/sell panel, shows the *next* level's delta before purchase |

## The level lifecycle

```
MainMenu ──▶ LevelSelect ──▶ GameScreen(level_id, difficulty) ──▶ Overlay(win/lose)
                 ▲                    │                              │
                 └──── retry / next ◀──┴──────────────────────────────┘
```

`GameScreen` runs a small explicit state machine — `IDLE → BUILD → WAVE → RESOLVED` — and
never uses implicit flags for it. During `BUILD` the wave director counts down (`prep_time`,
shorter than the previous wave's downtime at higher difficulties); calling early pays
`2 gold × seconds skipped` (minimum 3). During `WAVE` the tower panel stays available but the
"call" button is disabled. When the last spawn of the last wave dies or leaks, the run is
`RESOLVED`, `App` records stars and best wave, and the overlay reports the numbers.

## Frame loop and determinism

- One `_process(delta)` per subsystem, each clamping `delta` to `MAX_DELTA` (100 ms) so a
  phone waking from sleep cannot teleport enemies through the board.
- Simulation order is fixed: **director → enemies → towers → projectiles → effects → HUD**.
- Cooldowns are decremented by `delta` and accumulate leftover time, so fire rate is not
  quantised to the frame rate.
- `Balance.FIXED_TICK` and the autoplay harness's `--fixed-fps 480` make the balance
  regression reproducible run-to-run; the harness is the only place frame timing is faked.
- Tower/enemy counts are capped (`MAX_ENEMIES = 140`) and FX/damage numbers are pooled, so
  worst-case late waves do not allocate.

## Input model

Named actions only (`build`, `cancel`, `pause`, `speed`, `ability_1`, `ability_2`) declared in
`project.godot`, so Android touch, mouse and gamepad share one code path. The board is a
single `Control` that maps a tap to a cell and forwards it; **every decorative panel sets
`MOUSE_FILTER_IGNORE`** (a root `Control` with the default `STOP` will silently swallow every
board tap — that bug cost an hour and is now covered by the smoke test).

## Persistence

`App` owns the state; `SaveStore` writes it.

```
user://bulwark_save.json      { "version": 2, "settings": {...}, "progress": {...} }
user://bulwark_save.bak       previous good file, used if the main one fails to parse
```

Writes go to a temp file and are then renamed over the target, so a crash mid-save cannot
corrupt progress. `SaveStore.migrate()` upgrades older versions field by field; anything
unparseable falls back to defaults and re-saves. Settings live in the same file, which keeps
"reset everything" a single delete.

## Rendering and platform notes

- **Compatibility (GLES3) renderer** on every target: one shader/feature set to verify, and it
  is the renderer that behaves best on cheap Android GPUs. No 2D MSAA (mobile), no post FX.
- Reference resolution **1280×720**, stretch `canvas_items` + `keep`: the board keeps its aspect
  at any window size, ultrawide desktop or 19.5:9 phone, and nothing is ever squashed. The
  window is `sensor landscape`, so a phone can be held either way up.
- Tower Defense tiles are 64 px but the board cell is 64 px at reference scale, so sprites are
  never upscaled.
- Audio: three buses (`Master → Music`, `Master → SFX`) with an `AudioStreamPlayer` pool — no
  node creation on every shot. All streams are preloaded and imported with Vorbis settings
  appropriate for mobile.
- The game requests **no** runtime permissions and makes **no** network calls.

## Testing strategy

| Harness | What it protects |
|---|---|
| `tests/test_core.tscn` | Rules: pathing carry-over, placement reasons, targeting order, damage maths, economy monotonicity, JSON/l10n parity (every key referenced actually exists in both languages), save round-trip + migration |
| `tests/smoke_level.tscn` | Wiring: the real level scene boots, towers can be placed on legal cells and are refused on illegal ones *with the right reason key*, selection works, 40 s of simulation runs without errors |
| `tests/autoplay.tscn` | Balance: a scripted competent player must clear all three missions on Normal, and survive to the endgame on Hard. Runs at a fixed timestep so numbers are comparable across commits |

The screenshots in `docs/screenshots/` are produced by `tools/screenshot.tscn` under
`xvfb-run` at 1280×720 and 1600×900, plus a real 844×390 phone-landscape capture from the web
build, so layout regressions are visible rather than argued about.

## Extension points

- **New tower** → `data/towers.json` + sprite + two l10n keys (the l10n parity test fails if
  either language is missing).
- **New enemy** → `data/enemies.json` + sprite + two l10n keys; special behaviour goes in
  `enemy.gd` behind a capability flag (`splits_into`, `heals_radius`, `is_air`).
- **New mission** → drop `data/levels/level_07.json` (any `level_*.json` is auto-discovered and
  ordered by filename) + `level.7.name` / `level.7.desc` in both l10n tables. Grids, paths,
  scenery and waves are all data.
- **New ability** → one entry in `abilities.gd`'s table plus an icon glyph and a HUD button;
  the cooldown/targeting machinery is generic.
