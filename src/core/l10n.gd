class_name L10n
extends RefCounted
## Tiny two-language dictionary localiser.
##
## A full i18n pipeline (gettext/CSV import) is overkill for this project and would hide the
## strings from the repository. Keeping the tables in one typed file means a translator sees
## every string in a single diff-friendly place, and `Loc` (the autoload) only has to hold the
## current language.

const EN := {
	# App / menus
	"app.title": "BULWARK",
	"app.tagline": "Hold the line.",
	"menu.play": "Play",
	"menu.levels": "Missions",
	"menu.achievements": "Achievements",
	"menu.settings": "Settings",
	"menu.credits": "Credits",
	"menu.quit": "Quit",
	"menu.continue": "Continue",
	"common.back": "Back",
	"common.close": "Close",
	"common.resume": "Resume",
	"common.restart": "Restart",
	"common.cancel": "Cancel",
	"common.on": "On",
	"common.off": "Off",
	"common.reset": "Reset",
	"common.locked": "Locked",
	"common.soon": "Coming soon",
	# HUD
	"hud.lives": "Lives",
	"hud.gold": "Gold",
	"hud.wave": "Wave",
	"hud.pause": "Pause",
	"hud.speed": "Speed",
	# Game flow
	"game.prepare": "Prepare",
	"game.calling_in": "Next wave in",
	"game.call_now": "Call wave",
	"game.wave_bonus": "Early call bonus",
	"game.victory": "Sector secured",
	"game.defeat": "Sector lost",
	"game.wave_reached": "Reached wave",
	"game.lives_left": "Lives left",
	"game.gold_earned": "Gold earned",
	"game.interest": "Interest",
	"game.boss_incoming": "Boss incoming",
	# Build / tower panel
	"build.title": "Build",
	"build.empty_cell": "Select an empty tile to build",
	"build.insufficient": "Not enough gold",
	"build.place_hint": "Tap a tile to place",
	"tower.level": "Level",
	"tower.upgrade": "Upgrade",
	"tower.sell": "Sell",
	"tower.max_level": "Max level",
	"tower.choose_module": "Choose a module",
	"tower.module_installed": "Module",
	"tower.targeting": "Priority",
	"tower.dps": "DPS",
	"tower.stat.damage": "Damage",
	"tower.stat.rate": "Rate",
	"tower.stat.range": "Range",
	"tower.stat.splash": "Splash",
	"tower.stat.chain": "Chain",
	"tower.stat.pierce": "Armour pierce",
	"tower.stat.slow": "Slow",
	"tower.stat.aura": "Aura",
	"tower.stat.targets": "Targets",
	"tower.targets.both": "Air & ground",
	"tower.targets.ground": "Ground only",
	"tower.targets.air": "Air only",
	"tower.refund": "Refund",
	# Targeting modes (short: they sit in a compact button)
	"target.first": "First",
	"target.last": "Last",
	"target.closest": "Closest",
	"target.strongest": "Strongest",
	"target.weakest": "Weakest",
	# Towers
	"tower.pulse.name": "Pulse",
	"tower.pulse.desc": "Cheap rapid fire. Hits air and ground.",
	"tower.cannon.name": "Cannon",
	"tower.cannon.desc": "Heavy shells with splash. Ground only.",
	"tower.frost.name": "Frost",
	"tower.frost.desc": "Slows everything it touches. Low damage.",
	"tower.arc.name": "Arc",
	"tower.arc.desc": "Lightning that chains between targets.",
	"tower.rail.name": "Rail",
	"tower.rail.desc": "Long range, punches through armour.",
	"tower.beacon.name": "Beacon",
	"tower.beacon.desc": "Support pylon. Boosts nearby tower fire rate.",
	# Modules
	"tower.cannon.module_a.name": "Cluster",
	"tower.cannon.module_a.desc": "Far wider blast, slightly slower.",
	"tower.cannon.module_b.name": "Bunker buster",
	"tower.cannon.module_b.desc": "More damage, ignores more armour.",
	"tower.pulse.module_a.name": "Twin feed",
	"tower.pulse.module_a.desc": "Much faster fire rate, less damage per shot.",
	"tower.pulse.module_b.name": "Piercer",
	"tower.pulse.module_b.desc": "Extra damage and armour piercing rounds.",
	"tower.frost.module_a.name": "Deep chill",
	"tower.frost.module_a.desc": "Stronger slow over a wider area.",
	"tower.frost.module_b.name": "Shard",
	"tower.frost.module_b.desc": "Trades slow strength for real damage.",
	"tower.arc.module_a.name": "Overload",
	"tower.arc.module_a.desc": "Two extra chain jumps.",
	"tower.arc.module_b.name": "Capacitor",
	"tower.arc.module_b.desc": "Hits much harder, shorter range.",
	"tower.rail.module_a.name": "Marksman",
	"tower.rail.module_a.desc": "Even longer range and faster reload.",
	"tower.rail.module_b.name": "Sabot",
	"tower.rail.module_b.desc": "Marks the target: it takes more damage.",
	"tower.beacon.module_a.name": "Tempo",
	"tower.beacon.module_a.desc": "Bigger fire-rate aura radius.",
	"tower.beacon.module_b.name": "Resonance",
	"tower.beacon.module_b.desc": "Aura also boosts tower damage.",
	# Enemies
	"enemy.grunt.name": "Grunt",
	"enemy.runner.name": "Runner",
	"enemy.swarm.name": "Swarm",
	"enemy.brute.name": "Brute",
	"enemy.flyer.name": "Flyer",
	"enemy.medic.name": "Mender",
	"enemy.boss.name": "Colossus",
	"enemy.trait.air": "Flying",
	"enemy.trait.armor": "Armoured",
	"enemy.trait.heal": "Heals",
	"enemy.trait.immune_slow": "Slow immune",
	"enemy.trait.splits": "Splits",
	# Abilities
	"ability.airstrike.name": "Airstrike",
	"ability.airstrike.desc": "Tap the board to bomb an area.",
	"ability.overclock.name": "Overclock",
	"ability.overclock.desc": "All towers fire faster for 6 seconds.",
	"ability.ready": "Ready",
	"ability.cooldown": "Charging",
	# Settings
	"settings.title": "Settings",
	"settings.audio": "Audio",
	"settings.master": "Master",
	"settings.music": "Music",
	"settings.sfx": "Effects",
	"settings.gameplay": "Gameplay",
	"settings.difficulty": "Difficulty",
	"settings.accessibility": "Accessibility",
	"settings.damage_numbers": "Damage numbers",
	"settings.screen_shake": "Screen shake",
	"settings.reduce_motion": "Reduce motion",
	"settings.grid_overlay": "Grid overlay",
	"settings.colorblind": "High-contrast markers",
	"settings.language": "Language",
	"settings.reset_progress": "Reset progress",
	"settings.reset_confirm": "Erase all stars and unlocks?",
	"settings.saved": "Saved automatically",
	"settings.performance": "Performance",
	"settings.perf_overlay": "Performance overlay",
	"settings.save_data": "Save & data",
	"settings.save_data_help": "Move progress between devices: export a .json save, or import one.",
	"settings.export_save": "Export save",
	"settings.import_save": "Import save",
	"settings.save_exported": "Save exported",
	"settings.save_imported": "Save imported",
	"settings.save_failed": "Save transfer failed",
	"settings.import_confirm": "Import this save? It replaces your current progress.",
	"difficulty.easy": "Easy",
	"difficulty.normal": "Normal",
	"difficulty.hard": "Hard",
	# Pause / result
	"pause.title": "Paused",
	"result.stars_earned": "Stars",
	"result.retry": "Retry",
	"result.next": "Next mission",
	"result.menu": "Missions",
	"result.unlocked": "Mission unlocked",
	# Achievements
	"ach.title": "Achievements",
	"ach.unlocked": "Unlocked",
	"ach.locked": "Locked",
	"ach.progress": "{0} / {1}",
	"ach.first_clear.name": "First Blood",
	"ach.first_clear.desc": "Clear your first mission.",
	"ach.three_star.name": "Perfection",
	"ach.three_star.desc": "Take three stars on any mission.",
	"ach.all_cleared.name": "Sector Secure",
	"ach.all_cleared.desc": "Clear every campaign mission.",
	"ach.tower_master.name": "Tower Master",
	"ach.tower_master.desc": "Build 15 towers in a single run.",
	"ach.no_leak.name": "Untouchable",
	"ach.no_leak.desc": "Clear a mission without losing a single life.",
	"ach.endless_10.name": "Endless Runner",
	"ach.endless_10.desc": "Reach wave 10 in Endless mode.",
	"ach.boss_slayer.name": "Boss Slayer",
	"ach.boss_slayer.desc": "Defeat a Colossus.",
	"ach.collection.name": "Collector",
	"ach.collection.desc": "Earn every star in the campaign.",
	# Missions
	"level.1.name": "First Light",
	"level.1.desc": "A single road, a handful of raiders. Learn the loop.",
	"level.2.name": "Crossroads",
	"level.2.desc": "Longer route, more armour, and the first fliers.",
	"level.3.name": "The Narrows",
	"level.3.desc": "Tight corners. No room for a lazy build.",
	"level.4.name": "The Switchback",
	"level.4.desc": "A zig-zag corridor. Every bend is a kill zone.",
	"level.5.name": "The Divide",
	"level.5.desc": "Two long legs and a knife-edge crossing.",
	"level.6.name": "The Gauntlet",
	"level.6.desc": "The longest route yet. Attrition wins here.",
	"level.7.name": "The Labyrinth",
	"level.7.desc": "Four long runs and no shortcuts. Cover every bend.",
	"level.8.name": "The Citadel",
	"level.8.desc": "The final hold. Two bosses and a road that never ends.",
	"level.endless.name": "Endless",
	"level.endless.desc": "Survival. Waves escalate forever — hold as long as you can.",
	"level.progress": "Best: wave {0}",
	# Tutorial tips
	"tip.place": "Pick a tower, then tap a cream tile to build.",
	"tip.start": "Press Call wave when you are ready — you earn gold for calling early.",
	"tip.upgrade": "Tap a built tower to upgrade it, change its targeting, or sell it.",
	"tip.air": "Fliers cut the corners. Ground-only towers cannot hit them.",
	"tip.beacon": "Beacons make every tower in range fire faster.",
	"tip.welcome": "Welcome! Build on cream tiles, then call the wave.",
	"tip.place_step": "Pick a tower, then tap a cream tile to build.",
	"tip.call_step": "Press Call wave when ready — early calls earn gold.",
	"tip.upgrade_step": "Tap a built tower to upgrade it, change its targeting, or sell it.",
	"tip.ability_step": "Airstrike and Overclock turn a bad moment around.",
	"tip.done": "You're set. Hold the line.",
	"tutorial.step": "Step {0} / {1}",
	"tutorial.skip": "Skip",
	# Placement reasons
	"ui.reason.out_of_bounds": "Outside the board",
	"ui.reason.on_path": "The road is blocked",
	"ui.reason.occupied": "Tile already has a tower",
	"ui.reason.reserved": "Cannot build on scenery",
	"ui.reason.no_gold": "Not enough gold",
	# Credits
	"credits.title": "Credits",
	"credits.code": "Code & design",
	"credits.art": "Sprites",
	"credits.audio": "Sound effects",
	"credits.music": "Music",
	"credits.font": "Font",
	"credits.engine": "Engine",
	"credits.license": "Licences",
	"credits.made_with": "Made with Godot. Free and open source.",
}

## Locales we ship. The English table above is the source of truth for keys and source strings
## (each English value is the .po `msgid`); the actual translations live in `assets/locales/*.po`
## and are loaded as Godot `Translation` resources below.
const LOCALES: Array[String] = ["en", "ru"]

const EN_TRANSLATION_PATH := "res://assets/locales/en.po"
const RU_TRANSLATION_PATH := "res://assets/locales/ru.po"

## locale -> Translation, populated lazily on first use.
static var _translations: Dictionary = {}


static func _ensure_loaded() -> void:
	if not _translations.is_empty():
		return
	for path in [EN_TRANSLATION_PATH, RU_TRANSLATION_PATH]:
		var translation := load(path) as Translation
		if translation == null:
			push_warning("L10n: could not load translation %s" % path)
			continue
		_translations[String(translation.get_locale())] = translation


## The English source string for a key — also the .po `msgid`. Unknown keys resolve to the key
## itself, so a missing string is obvious in-game instead of silently empty.
static func source(key: String) -> String:
	return String(EN.get(key, key))


## True when `key` has a real (non-empty) translation in `language`.
static func is_translated(language: String, key: String) -> bool:
	_ensure_loaded()
	var translation: Translation = _translations.get(language) as Translation
	if translation == null:
		return false
	return not translation.get_message(StringName(source(key))).is_empty()


## Looks up `key`, falling back to English and finally to the key itself.
static func translate(language: String, key: String) -> String:
	_ensure_loaded()
	var msgid := source(key)
	if language == "en" or not _translations.has(language):
		return msgid
	var translation: Translation = _translations[language] as Translation
	if translation == null:
		return msgid
	var msg := translation.get_message(StringName(msgid))
	return String(msg) if not msg.is_empty() else msgid


static func has_key(key: String) -> bool:
	return EN.has(key)


static func all_keys() -> Array:
	return EN.keys()
