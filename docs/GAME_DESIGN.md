# Game design

This document is the *why* behind the numbers in `data/` and `src/core/balance.gd`. If you
change a curve, change it here too — the next person (possibly you, in six months) needs to
know which intent the number serves.

## Design pillars

1. **Readable at a glance.** Flat colours, one accent per tower family, enemies sized by threat.
   Nothing on the board is decoration only — trees and rocks mark cells you cannot build on.
2. **Decisions between waves, execution during them.** You *can* use abilities mid-wave, but the
   interesting choices (which tower, where, upgrade or wide?) happen in the build phase.
3. **No dead options.** Every tower is the best answer to something. Every module is a real
   trade, never a straight upgrade. Selling returns 75 %, so a mistake is a setback, not a loss.
4. **Short sessions.** A mission is 15 waves, 8–14 minutes. Mobile-first pacing: you can stop at
   any wave boundary without losing progress.
5. **Fair, telegraphed difficulty.** The next wave's composition is shown before you commit.
   Nothing spawns off-screen, nothing is invisible, no random crits.

## The economy is the game

The whole difficulty curve reduces to three numbers fighting each other:

| Curve | Value | Effect on play |
|---|---|---|
| Enemy HP per wave | **×1.085** compounding | a fixed defence stops working around wave 8 |
| Kill bounty per wave | **×1.08** linear | income grows, but *slower* than HP → you must upgrade, not just add towers |
| Wave-clear bonus | authored, ×1.05 linear | guarantees a visible payday even on a bad wave |

Supporting rules that keep it honest:

- **Interest** on banked gold, capped at 45 — rewards restraint without letting a passive player
  snowball. Difficulty presets scale the rate (Easy 3 %, Normal 5 %, Hard 4 %).
- **Early call** pays `2 gold × seconds skipped` (min 3). Turtle-play is not punished with a
  timer, it simply earns less.
- **Leak cost = a life *and* the bounty**, so a badly placed tower bleeds twice.
- **Armour grows +0.14 per wave**, while the min-damage floor is 12 % of raw damage. Rapid-fire
  towers degrade gracefully instead of becoming useless.
- **Speed creeps ×1.006/wave** with a ×1.25 cap, so late waves feel urgent but never unfair.

The result the harness enforces: a scripted competent player wins all three missions on Normal
with 12–14 of 20 lives remaining. Comfortable, not trivial — a real player who builds well
finishes with ~18 lives and 3 stars.

## Towers

Every tower answers a different question; none is a generic "more damage" upgrade.

| Tower | Cost | Damage type | Damage | Rate | Range | Special | Weak to |
|---|---:|---|---:|---:|---:|---|---|
| **Pulse** | 55 | kinetic | 9 | 2.4/s | 2.5 | cheapest tower, hits air, no armour pierce | armour, brutes |
| **Cannon** | 95 | explosive | 34 | 0.75/s | 2.6 | splash 0.85, ground only | fliers, single tough targets |
| **Frost** | 80 | frost | 6 | 1.1/s | 2.3 | splash 1.3, slow 45 % for 1.6 s | damage output |
| **Arc** | 110 | energy | 16 | 1.3/s | 2.4 | chains to 2 extra targets, 0.72 falloff | spread-out enemies |
| **Rail** | 150 | energy | 90 | 0.42/s | 5.5 | pierces 8 armour, huge range | swarms, fast runners |
| **Beacon** | 120 | — | — | — | 2.8 aura | +25 % fire rate and +damage aura to neighbours | itself (deals none) |

**Upgrades:** three levels each, price rising (Pulse 45/80 → Rail 130/200). The tower panel
always prints the delta for the *next* level ("→ Damage +5 · Rate +0.2 · Range +0.2") so no
purchase is blind.

**Modules** unlock at level 3 and are mutually exclusive — this is where builds diverge:

| Tower | Module A | Module B |
|---|---|---|
| Pulse | **Twin feed** — rate ×1.6, damage ×0.72 | **Piercer** — damage ×1.45, +5 pierce |
| Cannon | **Cluster** — splash ×1.8, rate ×0.85 | **Bunker buster** — damage ×1.5, +8 pierce |
| Frost | **Deep chill** — slow ×1.5, splash ×1.25 | **Shard** — damage ×4, slow ×0.6 |
| Arc | **Overload** — +2 chain jumps | **Capacitor** — damage ×1.7, range ×0.85 |
| Rail | **Marksman** — range ×1.25, rate ×1.25 | **Sabot** — marks the target (+25 % taken) |
| Beacon | **Tempo** — aura rate ×1.4, radius ×1.15 | **Resonance** — aura also grants +20 % damage |

**Targeting priorities** (per tower): first, last, closest, strongest, weakest. Default is
`first`; `strongest` is what you want on a Rail facing a Colossus, `closest` on a Cannon inside
a switchback.

## Enemies

| Enemy | HP | Speed | Armour | Bounty | Notes |
|---|---:|---:|---:|---:|---|
| Grunt | 55 | 1.15 | 0 | 7 | the yardstick |
| Runner | 38 | 2.30 | 0 | 6 | punishes slow-reacting defences |
| Swarm | 22 | 1.55 | 0 | 3 | +15 % explosive vulnerability; arrives in packs |
| Brute | 330 | 0.75 | 6 | 20 | 15 % kinetic resistance — needs energy or pierce |
| Flyer | 72 | 1.90 | 0 | 10 | **air**: cuts every other corner, 20 % explosive resistance |
| Mender | 150 | 1.00 | 2 | 18 | heals nearby enemies — kill it first |
| Colossus | 2000 | 0.55 | 10 | 160 | boss; 15 % explosive resistance; splits into Swarms on death |

The air route is the normal route with every other corner skipped (`_build_air_path()`), which
makes anti-air placement a genuinely different problem from ground coverage rather than "the
same towers hit everything".

## Waves and missions

Fifteen waves per mission, authored as groups with `start` offsets and spawn `interval`, so
pressure arrives in overlapping pulses rather than a single stream. Composition is the teaching
tool:

- **Waves 1–3** — grunts only. Learn placement and the economy.
- **Waves 4–5** — first runners → your towers need to actually reach the road.
- **Waves 6–7** — swarms + first brutes → explosive damage and armour both matter.
- **Waves 8–9** — first flyers → add anti-air or lose lives.
- **Waves 10–12** — menders behind brutes → focus-fire and priority targeting.
- **Wave 15** — Colossus, escort brutes, flyers behind it. Everything you learned, at once.

| Mission | Start gold | Lives | Prep | HP mult | Total spawns | Twist |
|---|---:|---:|---:|---:|---:|---|
| **01 · Outpost** | 300 | 20 | 18 s | 1.00 | 200 | a long switchback — teaches tower placement |
| **02 · Crossroads** | 320 | 20 | 16 s | 1.04 | 204 | two tight S-bends: cannons shine, rails get long sightlines |
| **03 · The Narrows** | 340 | 20 | 15 s | 1.09 | 239 | heaviest traffic, most flyers — anti-air tax is real |

Difficulty modifies HP, income and lives: **Easy** ×0.82 HP, ×1.15 gold, 25 lives, 3 % interest ·
**Normal** ×1.0/×1.0, 20 lives, 5 % · **Hard** ×1.18 HP, ×0.95 gold, 15 lives, 4 %.

## Abilities

Two active tools on cooldowns, so a bad moment has an answer that is not just "build faster":

| Ability | Cooldown | Effect |
|---|---|---|
| **Airstrike** | 34 s | tap a point: 240 explosive damage in a 2.3-cell radius (splash falls off to 45 % at the edge) |
| **Overclock** | 38 s | all towers fire at ×1.7 rate for 6 s — no targeting needed, best saved for a boss wave |

Both are optional — the mission is winnable without ever pressing them (the autoplay harness
never does), which keeps them as expression rather than a requirement.

## Feedback and game feel

Per hit: a spark burst, a hit sound, a damage number (toggleable) and a small enemy squash.
Per kill: a shrinking pop, the bounty flying toward the gold counter, an audio tick.
Per wave: a low horn on start, a fanfare on clear. Per life lost: a red edge flash and a bell.
Screen shake is trauma-squared on a camera offset and can be set to **0** in settings — the
game is fully playable with all motion off, which is also why "reduce motion" exists there.

## What was deliberately left out

- **No mazing/path-blocking.** Towers stand on buildable cells; the route is fixed. Mazing is a
  great mechanic but it makes a 14×10 board a puzzle game, and it does not read on a phone.
- **No loot boxes, no ads, no energy timers, no IAP.** The whole game is the content.
- **No procedural maps.** Three hand-tuned missions beat infinite random ones at this scale —
  and the harness can only guarantee balance for authored content.
- **No PvP or online anything.** Zero permissions, zero network calls, works offline forever.
