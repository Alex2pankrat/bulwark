class_name WavePlan
extends RefCounted
## Turns authored wave data into a deterministic spawn timeline and a UI preview.
##
## A wave is data: groups of (enemy, count, interval, start offset). Flattening it into a
## sorted timeline once makes the runtime spawner trivial (a cursor over an array) and makes
## the next-wave preview free, which is what stops special waves from feeling unfair.

const MAX_GROUPS := 8


static func wave_count(level: Dictionary) -> int:
	return (level.get("waves", []) as Array).size()


static func wave_data(level: Dictionary, wave_index: int) -> Dictionary:
	var waves: Array = level.get("waves", [])
	if wave_index < 0 or wave_index >= waves.size():
		return {}
	return waves[wave_index]


## [{at: float, enemy: String}] sorted by time. Deterministic for identical input.
static func timeline(level: Dictionary, wave_index: int) -> Array[Dictionary]:
	var wave := wave_data(level, wave_index)
	var entries: Array[Dictionary] = []
	for group in (wave.get("groups", []) as Array):
		var enemy := String(group.get("enemy", ""))
		var count := int(group.get("count", 1))
		var interval := float(group.get("interval", 0.6))
		var start := float(group.get("start", 0.0))
		for i in range(count):
			entries.append({"at": start + i * interval, "enemy": enemy})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["at"], b["at"]):
			return String(a["enemy"]) < String(b["enemy"])
		return a["at"] < b["at"])
	return entries


## Total spawn duration of the wave in seconds.
static func duration(level: Dictionary, wave_index: int) -> float:
	var entries := timeline(level, wave_index)
	if entries.is_empty():
		return 0.0
	var last := 0.0
	for entry in entries:
		last = maxf(last, float(entry["at"]))
	return last


## Aggregated preview: [{enemy, count}] in a stable order for the HUD.
static func preview(level: Dictionary, wave_index: int) -> Array[Dictionary]:
	var wave := wave_data(level, wave_index)
	var order: Array[String] = []
	var counts: Dictionary = {}
	for group in (wave.get("groups", []) as Array):
		var enemy := String(group.get("enemy", ""))
		if not counts.has(enemy):
			counts[enemy] = 0
			order.append(enemy)
		counts[enemy] = int(counts[enemy]) + int(group.get("count", 1))
	var out: Array[Dictionary] = []
	for enemy in order:
		out.append({"enemy": enemy, "count": counts[enemy]})
	return out


## Bonus gold awarded for clearing the wave (before interest).
static func clear_bonus(level: Dictionary, wave_index: int) -> int:
	var wave := wave_data(level, wave_index)
	var authored := int(wave.get("bonus", 15 + wave_index * 2))
	return roundi(authored * (1.0 + Balance.WAVE_BONUS_GROWTH * float(wave_index)))


## Waves that contain a boss, used for the "boss incoming" telegraph.
static func has_boss(level: Dictionary, wave_index: int) -> bool:
	for group in (wave_data(level, wave_index).get("groups", []) as Array):
		if String(group.get("enemy", "")) == "boss":
			return true
	return false
