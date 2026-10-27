# Assets — provenance and licences

Rule for this repository: **the shipped game contains only assets released under a licence
that allows commercial use without permission or payment**, and only from well-known,
widely-used packs (Kenney, Google/rsms typefaces). Everything here is CC0 1.0 or SIL OFL 1.1.

Nothing in the game requires attribution. Credits in the UI and the notices below exist
because they are good practice, not because a licence demands it.

Summary: **60 asset files, 2.3 MB** — 26 sprites (6 towers, 7 enemies, 7 props, 6 FX),
21 sound effects, 2 music tracks, 1 font, 2 icons, plus the licence texts themselves.

---

## Sprites — Kenney “Tower Defense (Top-Down)”, CC0 1.0

Pack: <https://kenney.nl/assets/tower-defense-top-down> · 2016, Kenney Vleugels · CC0 1.0.
Licence text as shipped with the pack: `assets/audio/tower-defense-top-down_LICENSE.txt`.
(Single licence file for the whole download; it covers the sprites as well as the audio the
pack ships with.)

| File | Game role | Original file in the pack |
|---|---|---|
| `sprites/towers/pulse.png` | Pulse tower (rapid fire, hits air) | `towerDefense_tile203.png` |
| `sprites/towers/cannon.png` | Cannon tower (splash, ground only) | `towerDefense_tile205.png` |
| `sprites/towers/frost.png` | Frost tower (slow field) | `towerDefense_tile180.png` |
| `sprites/towers/arc.png` | Arc tower (chain lightning) | `towerDefense_tile182.png` |
| `sprites/towers/rail.png` | Rail tower (pierce, long range) | `towerDefense_tile206.png` |
| `sprites/towers/beacon.png` | Beacon tower (support aura) | `towerDefense_tile133.png` |
| `sprites/enemies/grunt.png` | Grunt | `towerDefense_tile246.png` |
| `sprites/enemies/runner.png` | Runner | `towerDefense_tile245.png` |
| `sprites/enemies/swarm.png` | Swarm (Colossus fragments, Mender spawns) | `towerDefense_tile248.png` |
| `sprites/enemies/brute.png` | Brute (armoured) | `towerDefense_tile247.png` |
| `sprites/enemies/flyer.png` | Flyer (cuts corners) | `towerDefense_tile271.png` |
| `sprites/enemies/medic.png` | Mender (heals nearby enemies) | `towerDefense_tile249.png` |
| `sprites/enemies/boss.png` | Colossus (boss) | `towerDefense_tile250.png` |
| `sprites/props/tree_a.png` | Board decoration | `towerDefense_tile130.png` |
| `sprites/props/tree_b.png` | Board decoration | `towerDefense_tile132.png` |
| `sprites/props/bush.png` | Board decoration | `towerDefense_tile131.png` |
| `sprites/props/plant.png` | Board decoration | `towerDefense_tile134.png` |
| `sprites/props/flower.png` | Board decoration | `towerDefense_tile122.png` |
| `sprites/props/rock_a.png` | Board decoration | `towerDefense_tile135.png` |
| `sprites/props/rock_b.png` | Board decoration | `towerDefense_tile136.png` |

All from `tower-defense-top-down/PNG/Default size/` (64×64, transparent) — the modeller's
"Default size" folder, i.e. the native resolution, so nothing is upscaled.

### Effects — Kenney “Particle Pack” 1.1, CC0

Pack: <https://kenney.nl/assets/particle-pack> · CC0 1.0 (licence text:
`assets/audio/particlePack_1.1_LICENSE.txt` — the file is shared with the audio folder
because [Kenney](https://kenney.nl) ships one licence per download).

| File | Game role | Original file |
|---|---|---|
| `sprites/fx/spark.png` | hit spark | `spark_04.png` |
| `sprites/fx/flare.png` | muzzle flash / explosion core | `flare_01.png` |
| `sprites/fx/muzzle.png` | muzzle cone | `muzzle_02.png` |
| `sprites/fx/smoke.png` | smoke puff on splash | `smoke_04.png` |
| `sprites/fx/ring.png` | shockwave rings (frost, airstrike) | `circle_05.png` |
| `sprites/fx/star.png` | ability sparkle | `star_05.png` |

Taken from `particlePack_1.1/PNG (Transparent)/`.

Sprites are used unmodified at runtime (scaled by code); the terrain, path and grid tiles are
**drawn procedurally** by `src/game/board.gd` with the palette in `src/core/palette.gd`, so no
tileset image is needed and the look stays consistent at any resolution.

## Audio — Kenney, CC0 1.0

All tracks and effects come from Kenney packs; each pack's licence ships in `assets/audio/`.

| File | Source file (pack, CC0) | Used for |
|---|---|---|
| `sfx/ui_click.ogg` | `kenney_interfacesounds/Audio/click_002` | button press |
| `sfx/ui_back.ogg` | `kenney_interfacesounds/Audio/back_001` | back / close |
| `sfx/error.ogg` | `kenney_interfacesounds/Audio/error_004` | rejected build, “not enough gold” |
| `sfx/select.ogg` | `kenney_interfacesounds/Audio/select_006` | tower selected |
| `sfx/gold.ogg` | `kenney_interfacesounds/Audio/tick_001` | bounty / bonus credited |
| `sfx/wave_start.ogg` | `kenney_interfacesounds/Audio/switch_002` | wave begins |
| `sfx/tower_upgrade.ogg` | `kenney_interfacesounds/Audio/confirmation_002` | upgrade / module installed |
| `sfx/ui_hover.ogg` | `kenney_uiaudio/Audio/rollover1` | hover / keyboard focus |
| `sfx/tower_place.ogg` | `kenney_impactsounds/Audio/impactPlate_light_000` | tower built |
| `sfx/tower_sell.ogg` | `kenney_impactsounds/Audio/impactWood_light_001` | tower sold |
| `sfx/enemy_hit.ogg` | `kenney_impactsounds/Audio/impactSoft_medium_000` | projectile impact |
| `sfx/enemy_death.ogg` | `kenney_impactsounds/Audio/impactPunch_medium_000` | enemy killed |
| `sfx/leak.ogg` | `kenney_impactsounds/Audio/impactBell_heavy_000` | enemy escaped (life lost) |
| `sfx/boss_spawn.ogg` | `kenney_impactsounds/Audio/impactMetal_heavy_000` | boss wave warning |
| `sfx/shoot_pulse.ogg` | `kenney_digitalaudio/Audio/laser1` | Pulse fire |
| `sfx/shoot_cannon.ogg` | `kenney_digitalaudio/Audio/laser4` | Cannon fire |
| `sfx/shoot_frost.ogg` | `kenney_digitalaudio/Audio/laser7` | Frost pulse |
| `sfx/shoot_arc.ogg` | `kenney_digitalaudio/Audio/laser9` | Arc discharge |
| `sfx/shoot_rail.ogg` | `kenney_digitalaudio/Audio/phaserUp3` | Rail shot |
| `sfx/victory.ogg` | `kenney_musicjingles/Audio/Steel jingles/jingles_STEEL04` | mission cleared |
| `sfx/defeat.ogg` | `kenney_musicjingles/Audio/Steel jingles/jingles_STEEL12` | out of lives |
| `music/calm.ogg` | **generated by `tools/make_music.py`** | menu / build phase |
| `music/battle.ogg` | **generated by `tools/make_music.py`** | wave in progress |

Packs used: **Interface Sounds**, **UI Audio**, **Impact Sounds**, **Digital Audio**,
**Music Jingles** — all Kenney, all CC0 1.0. Each pack's own licence text sits next to the
folders above (`assets/audio/*_LICENSE.txt`). The `.ogg` files are byte-identical copies from the packs — no re-encoding, no trimming.

Music is synthesised from scratch by `tools/make_music.py` (pure Python + `wave`, no samples,
no external dependencies), so it is original work released CC0 with the code.

## Font — Inter, SIL OFL 1.1

- `fonts/Inter.ttf` — Inter by The Inter Project Authors, <https://rsms.me/inter/>.
- Licence: `fonts/OFL-Inter.txt` (SIL Open Font License 1.1). OFL permits embedding in
  applications and reallocation as part of a larger work; the font itself may not be sold
  standalone. The font ships unmodified.
- Chosen because it covers Latin **and** Cyrillic, has a variable-weight axis and a wide
  lowercase at UI sizes — imported as a single `.ttf` with a Godot `FontVariation` for weights.

## Icons

- `icons/icon.png` — app icon (512×512) and `icons/icon_foreground.png` — Android adaptive
  foreground (432×432, 66 % safe zone). Generated by a script in `tools/` from the game's own
  palette and glyphs. CC0, so the launcher icon carries no third-party obligation.

## Things deliberately *not* used

- **No Google Fonts CDN at runtime** — the `.ttf` is embedded; the game works offline and
  makes no network requests at all.
- **No scraped/stock art, no AI-generated images, no ripped sprites.** Every bitmap traces to
  a named Kenney pack or is generated by a script in this repository.
- **No pay-what-you-want pack whose licence forbids redistribution** — CC0 has no such clause,
  which is why it was the only family of packs considered.

## Adding an asset

1. Confirm the licence is CC0 / OFL / MIT and record it here (file, pack, licence, URL).
2. Copy the licence text next to it if it is not already present.
3. Keep names semantic (`towers/frost.png`), lowercase, and re-import through Godot.
4. If the asset needs attribution, add it to `THIRD_PARTY_NOTICES.md` **and** the credits
   screen (`src/ui/credits_screen.gd`).
