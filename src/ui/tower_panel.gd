class_name TowerPanel
extends PanelContainer
## The selected-tower inspector: stats, upgrade, targeting priority, modules and sell.
##
## Replaces the build bar in the same slot instead of floating over the board, so on a phone
## nothing covers the tiles the player is looking at.

signal upgrade_pressed()
signal sell_pressed()
signal targeting_pressed()
signal module_pressed(module_id: String)
signal closed()

var _sprite: TextureRect
var _name: Label
var _level_pips: HBoxContainer
var _dps: Label
var _stats: Label
var _tags: Label
var _next: Label
var _upgrade_button: Button
var _sell_button: Button
var _target_button: Button
var _module_row: HBoxContainer
var _module_title: Label
var _tower: Tower


func _ready() -> void:
	theme_type_variation = "HudPanel"
	_build()


func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# --- header -----------------------------------------------------------------------------
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(30, 30)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	header.add_child(_sprite)

	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	header.add_child(name_box)
	_name = UIKit.label("", "HeadingLabel")
	name_box.add_child(_name)
	_level_pips = HBoxContainer.new()
	_level_pips.add_theme_constant_override("separation", 4)
	name_box.add_child(_level_pips)

	header.add_child(UIKit.spacer(true))
	_dps = UIKit.label("", "NumberLabel")
	header.add_child(_dps)

	var close := UIKit.icon_button("close", Palette.TEXT_MUTED, func() -> void: closed.emit(), 34)
	header.add_child(close)

	# --- stats line ---------------------------------------------------------------------------
	_stats = UIKit.label("", "SmallLabel")
	root.add_child(_stats)
	_next = UIKit.label("", "TinyLabel")
	root.add_child(_next)
	_tags = UIKit.label("", "TinyLabel")
	root.add_child(_tags)

	# --- actions ------------------------------------------------------------------------------
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	_upgrade_button = UIKit.button("", "PrimaryButton", func() -> void: upgrade_pressed.emit())
	_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_upgrade_button)

	_target_button = UIKit.button("", "", func() -> void: targeting_pressed.emit())
	_target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_target_button)

	_sell_button = UIKit.button("", "GhostButton", func() -> void: sell_pressed.emit())
	_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_sell_button)

	# --- modules ------------------------------------------------------------------------------
	_module_title = UIKit.label("", "TinyLabel")
	root.add_child(_module_title)
	_module_row = HBoxContainer.new()
	_module_row.add_theme_constant_override("separation", 8)
	root.add_child(_module_row)


func refresh(tower: Tower, gold: int) -> void:
	_tower = tower
	var stats := tower.stats
	var def := tower.def
	_sprite.texture = load("res://assets/sprites/towers/%s.png" % String(def.get("sprite", "")))
	_name.text = Loc.t(String(def.get("name_key", "")))

	for child in _level_pips.get_children():
		child.queue_free()
	for i in range(TowerStats.MAX_LEVEL):
		var filled := i < tower.level
		var pip := Glyph.of("star" if filled else "minus", 11,
			Palette.GOLD if filled else Palette.TEXT_DIM)
		_level_pips.add_child(pip)
	if tower.module != "":
		var module_def: Dictionary = TowerStats.modules(def).get(tower.module, {})
		var tag := UIKit.label("· " + Loc.t(String(module_def.get("name_key", ""))), "TinyLabel")
		tag.add_theme_color_override("font_color", Palette.ACCENT)
		_level_pips.add_child(tag)

	_dps.text = "%d %s" % [roundi(TowerStats.dps(stats)), Loc.t("tower.dps")]
	_dps.add_theme_color_override("font_color", Palette.ACCENT if not tower.is_aura() else Palette.HEAL)

	if tower.is_aura():
		_stats.text = "%s +%d%% · %s %d" % [
			Loc.t("tower.stat.aura"), roundi(float(stats.get("aura_rate", 0.0)) * 100.0),
			Loc.t("tower.stat.range"), roundi(float(stats.get("aura_range", 0.0))),
		]
	else:
		_stats.text = "%s %d · %s %.1f/s · %s %.1f" % [
			Loc.t("tower.stat.damage"), roundi(float(stats.get("damage", 0.0))),
			Loc.t("tower.stat.rate"), float(stats.get("fire_rate", 0.0)),
			Loc.t("tower.stat.range"), float(stats.get("range", 0.0)),
		]
	_tags.text = _describe_tags(stats)
	_next.text = _describe_next(tower)

	# Upgrade / max level
	if tower.can_upgrade():
		var cost := tower.upgrade_cost()
		_upgrade_button.text = "%s  ·  %d" % [Loc.t("tower.upgrade"), cost]
		_upgrade_button.disabled = gold < cost
	else:
		_upgrade_button.text = Loc.t("tower.max_level")
		_upgrade_button.disabled = true

	_target_button.text = "%s: %s" % [Loc.t("tower.targeting"), Loc.t(Targeting.mode_key(tower.targeting_mode))]
	_sell_button.text = "%s  +%d" % [Loc.t("tower.sell"), tower.sell_value()]

	# Modules: only offered at max level, and only once.
	var options := tower.available_modules()
	_module_title.visible = not options.is_empty()
	_module_row.visible = not options.is_empty()
	for child in _module_row.get_children():
		child.queue_free()
	if not options.is_empty():
		_module_title.text = Loc.t("tower.choose_module")
		for module_id in options.keys():
			var module_def: Dictionary = options[module_id]
			var label := "%s · %d\n%s" % [
				Loc.t(String(module_def.get("name_key", ""))),
				int(module_def.get("cost", 0)),
				Loc.t(String(module_def.get("desc_key", ""))),
			]
			var button := UIKit.button(label, "ChipButton",
				func() -> void: module_pressed.emit(String(module_id)))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 56
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 13)
			_module_row.add_child(button)


## "Next: +dmg · +rate" — the player should never have to guess what an upgrade buys.
func _describe_next(tower: Tower) -> String:
	if not tower.can_upgrade():
		return ""
	var current := tower.stats
	var next_stats := TowerStats.resolve(tower.def, tower.level + 1, tower.module)
	var deltas: Array[String] = []
	var dmg_delta := float(next_stats["damage"]) - float(current["damage"])
	var rate_delta := float(next_stats["fire_rate"]) - float(current["fire_rate"])
	var range_delta := float(next_stats["range"]) - float(current["range"])
	if absf(dmg_delta) > 0.01:
		deltas.append("%s %+d" % [Loc.t("tower.stat.damage"), roundi(dmg_delta)])
	if absf(rate_delta) > 0.01:
		deltas.append("%s %+.1f" % [Loc.t("tower.stat.rate"), rate_delta])
	if absf(range_delta) > 0.01:
		deltas.append("%s %+.1f" % [Loc.t("tower.stat.range"), range_delta])
	if deltas.is_empty():
		return ""
	return "→ " + " · ".join(deltas)


func _describe_tags(stats: Dictionary) -> String:
	var parts: Array[String] = []
	if bool(stats.get("targets_air", true)) and bool(stats.get("targets_ground", true)):
		parts.append(Loc.t("tower.targets.both"))
	elif bool(stats.get("targets_air", false)):
		parts.append(Loc.t("tower.targets.air"))
	else:
		parts.append(Loc.t("tower.targets.ground"))
	if float(stats.get("splash", 0.0)) > 0.0:
		parts.append("%s %.1f" % [Loc.t("tower.stat.splash"), float(stats["splash"])])
	if float(stats.get("chain", 0.0)) >= 1.0:
		parts.append("%s %d" % [Loc.t("tower.stat.chain"), int(stats["chain"])])
	if float(stats.get("pierce", 0.0)) > 0.0:
		parts.append("%s %d" % [Loc.t("tower.stat.pierce"), roundi(float(stats["pierce"]))])
	if float(stats.get("slow_factor", 0.0)) > 0.0:
		parts.append("%s %d%%" % [Loc.t("tower.stat.slow"), roundi(float(stats["slow_factor"]) * 100.0)])
	return " · ".join(parts)


func current_tower() -> Tower:
	return _tower
