class_name Balance
extends RefCounted
## All tuning numbers that are *not* content-specific live here.
##
## Design rule (from the tower-defense playbook): the player should *almost* be able to afford
## the answer to the next wave. That balance lives in three curves — enemy HP growth, player
## income and tower cost. They are deliberately gathered in one file so they can be tuned
## together and reviewed in one diff.

enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_ORDER: Array[Difficulty] = [Difficulty.EASY, Difficulty.NORMAL, Difficulty.HARD]

## Per-difficulty multipliers. `hp` scales enemy health, `gold` scales all income,
## `lives` overrides level lives when > 0, `interest` scales banked-gold interest.
const DIFFICULTY: Dictionary = {
	Difficulty.EASY: {"hp": 0.82, "gold": 1.15, "lives": 25, "interest": 0.03},
	Difficulty.NORMAL: {"hp": 1.0, "gold": 1.0, "lives": 20, "interest": 0.05},
	Difficulty.HARD: {"hp": 1.18, "gold": 0.95, "lives": 15, "interest": 0.04},
}

# --- Enemy scaling ---------------------------------------------------------------------------
## Geometrically growing HP per wave (playbook: ~1.1–1.2× per wave). Paired with a mostly
## linear income curve, this forces upgrades rather than endless tower spam.
const HP_GROWTH_PER_WAVE := 1.085
## Speed creeps up slowly. Capped so late waves do not become unreactable.
const SPEED_GROWTH_PER_WAVE := 1.006
const SPEED_GROWTH_CAP := 1.25
## Armour grows linearly: flat reduction, so rapid-fire towers must be supplemented.
const ARMOR_GROWTH_PER_WAVE := 0.14

# --- Economy ---------------------------------------------------------------------------------
const SELL_REFUND := 0.75            ## Fraction of total invested gold returned on sell.
const INTEREST_CAP := 45             ## Hard cap on banking interest (prevents snowballs).
const EARLY_CALL_GOLD_PER_SEC := 2.0 ## Bonus gold for each second skipped by calling early.
const EARLY_CALL_MIN := 3.0          ## Never award less than this for an early call.
const KILL_GOLD_GROWTH := 0.08      ## Bounty grows far slower than HP on purpose.
## Authored wave-clear bonuses also grow with the wave number, so income keeps pace with the
## "more and tougher enemies" curve instead of falling behind it.
const WAVE_BONUS_GROWTH := 0.05

# --- Damage ----------------------------------------------------------------------------------
## Damage can never be reduced below this fraction of its raw value by armour.
const MIN_DAMAGE_FRACTION := 0.12
## Splash damage at the outer edge of the radius, as a fraction of the centre value.
const SPLASH_EDGE_FRACTION := 0.45
## Chain lightning damage falloff per jump.
const CHAIN_FALLOFF := 0.72
## How much a "marked" target takes extra (railgun module).
const MARK_BONUS := 0.2

# --- Targets / flow --------------------------------------------------------------------------
const FIXED_TICK := 1.0 / 60.0       ## Simulation is frame-rate independent via delta clamping.
const MAX_DELTA := 0.1               ## Clamp huge frame spikes (mobile resume, breakpoints).
const MAX_ENEMIES := 140             ## Hard cap; protects low-end phones.
const MAX_DAMAGE_POPUPS := 24        ## Floating number budget.

# --- Star rating ----------------------------------------------------------------------------
## Stars are awarded on lives remaining, so "how cleanly did you clear it" matters:
## 1 star for clearing, +1 at 50% lives, +1 at 90% lives.
const STAR_THRESHOLDS: Array[float] = [0.5, 0.9]


static func difficulty_config(difficulty: int) -> Dictionary:
	return DIFFICULTY.get(difficulty, DIFFICULTY[Difficulty.NORMAL])


## Enemy HP for a given wave, level and difficulty.
static func enemy_hp(base_hp: float, wave: int, level_hp_mult: float, difficulty: int) -> float:
	var cfg := difficulty_config(difficulty)
	var wave_mult := pow(HP_GROWTH_PER_WAVE, max(0, wave - 1))
	return maxf(1.0, base_hp * wave_mult * level_hp_mult * float(cfg["hp"]))


## Speed multiplier for a given wave (soft cap).
static func enemy_speed_mult(wave: int) -> float:
	return minf(pow(SPEED_GROWTH_PER_WAVE, max(0, wave - 1)), SPEED_GROWTH_CAP)


## Bonus flat armour for a given wave.
static func enemy_armor_bonus(wave: int) -> float:
	return ARMOR_GROWTH_PER_WAVE * max(0, wave - 1)


## Kill bounty grows much slower than HP: leaking stays expensive, spam stays unprofitable.
static func enemy_gold(base_gold: int, wave: int, difficulty: int) -> int:
	var cfg := difficulty_config(difficulty)
	return maxi(1, roundi(base_gold * (1.0 + KILL_GOLD_GROWTH * (wave - 1)) * float(cfg["gold"])))


## Interest earned on banked gold at the end of a wave.
static func interest(gold: int, difficulty: int) -> int:
	var rate := float(difficulty_config(difficulty)["interest"])
	return mini(INTEREST_CAP, floori(gold * rate))


## Bonus gold for calling the next wave before its countdown ends.
static func early_call_bonus(seconds_left: float) -> int:
	if seconds_left <= 0.0:
		return 0
	return maxi(int(EARLY_CALL_MIN), roundi(seconds_left * EARLY_CALL_GOLD_PER_SEC))


## Stars earned for an outcome: 0 = lost, 1..3 = cleared with that many thresholds met.
static func stars(won: bool, lives_left: int, lives_total: int) -> int:
	if not won or lives_total <= 0:
		return 0
	var ratio := clampf(float(lives_left) / float(lives_total), 0.0, 1.0)
	var count := 1
	for threshold in STAR_THRESHOLDS:
		if ratio >= threshold:
			count += 1
	return mini(3, count)  # 1..3
