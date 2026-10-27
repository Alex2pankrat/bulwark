# Contributing

Thanks for taking a look. Bulwark is small on purpose, and the goal of these conventions is to
keep it that way.

## Getting set up

1. Godot **4.7** stable, plus the matching export templates if you want to build installers.
2. Open the folder in the editor (`godot --path .`), or just run the tests — no setup needed.
3. `GODOT=/path/to/godot tools/test.sh` must be green before and after your change.

## Ground rules

**`src/core` never touches the scene tree.** If a rule needs to be changed, change it there and
test it there. Node classes orchestrate; they do not decide.

**Content is data.** Towers, enemies and waves live in `data/*.json`, not in `if` statements.
Adding a tower should not require touching `tower.gd`.

**No hidden state.** If something matters to the simulation, it is either in the snapshot
(`GameScreen.snapshot()`) or it is presentation only. This is what makes the harnesses possible.

**Typed GDScript.** `static func foo(n: int) -> float`. Use `:=` where the type is obvious,
explicit types in signatures and dictionaries. Comments explain *why*, not *what*.

**One screen per file, one widget per file.** `src/ui/ui_kit.gd` holds shared builders; if two
screens want the same thing, it belongs there rather than being copy-pasted.

## Style specifics

- Tabs, not spaces (Godot default). Max ~100 columns.
- Sections separated by a single blank line; long functions split into well-named helpers.
- Constants in `SCREAMING_SNAKE_CASE` at the top; tuning numbers go in `core/balance.gd`, never
  inline in gameplay code.
- Strings are never hard-coded in a scene: add a key to `core/l10n.gd` for **both** languages.
  The parity test fails otherwise.
- Names: `snake_case` for functions/variables, `PascalCase` for classes, `res://` paths in
  constants.

## Changing balance

The autoplay harness is the contract: a scripted competent player must still clear all three
missions on Normal. If your change moves the difficulty, run

```bash
godot --headless --fixed-fps 480 --path . res://tests/autoplay.tscn -- --difficulty=1
```

and include the new `lives X/20` line in the PR description. If you change a curve, update
`docs/GAME_DESIGN.md` in the same commit — the table there is the design record, not decoration.

## Commits and PRs

- Conventional-ish subject lines: `feat: split beam damage`, `fix: leak costs bounty`,
  `balance: slower armour growth`, `docs: assets provenance`.
- One topic per commit. Do not reformat files you are not changing.
- Say what the player experiences, not just which file changed.
- Screenshots are welcome for UI changes; `tools/screenshot.tscn` regenerates
  `docs/screenshots/` at three aspect ratios.

## Adding assets

Only CC0 / OFL / MIT assets from well-known sources. Record the file, pack, licence and URL in
`docs/ASSETS.md`, ship the licence text next to the asset, and add an attribution line to
`THIRD_PARTY_NOTICES.md` if the licence asks for one. The build intentionally ships without
anything that requires permission to redistribute.

## Reporting bugs

Include: platform (Android/Windows/Linux/Web), mission and wave, what you expected, what
happened, and — if you can — the last few lines of the log (`adb logcat | grep godot` on
Android). Save files are at `user://bulwark_save.json`; deleting that file resets progress and
is a legitimate first fix.

## Licence

By contributing you agree your work is released under the MIT licence (see `LICENSE`).
