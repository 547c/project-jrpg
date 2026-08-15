# World Bible — Project JRPG

## Setting

Long ago, the land was sustained by the **Veins** — ancient waterways said to
carry the world's life force beneath the earth, feeding villages, forests,
and mountains alike. Centuries ago, the Veins began failing in scattered
places across the continent, and regions dependent on them slowly withered
or twisted into strange states.

The player begins in a small village on the far edge of this decline —
remote enough that it had been spared, until now. The village well has
just run dry for the first time.

*(In-game, this backstory is delivered once, briefly, in an opening text
cutscene. During actual gameplay, NPCs and text never use terms like "the
Veins" — they speak plainly: "the well's gone dry," "something's wrong in
the cave.")*

## v1.0 Scope — "The Village Well"

The well dried up because the **Guardian** sealed within the nearby cave —
an ancient being left behind to protect the local vein — has been
weakened or corrupted, and is now unintentionally blocking the flow.

### Core NPCs (state-tracked)

| NPC | Role | Ties to |
|---|---|---|
| Elara (Elder) | Knowledge/guidance, frames the mystery | Narrative pacing, ending flavor text |
| Rohan (Hunter) | Forest guide, opinionated about the Guardian | Choice 1 flavor, no ending impact |
| Yusuf (Traveling Merchant) | Info broker, subtly more than he seems | Choice 1 hint-giver, **v2 setup** |
| Mia (Child) | Sole witness, frightened, hiding what she saw | Choice 2, direct ending impact |

### Decisive Choices (drive the ending)

1. **Guardian resolution** — defeat it in combat, or calm/purify it through dialogue
   → flag: `resolved_guardian_peacefully`
2. **Mia's trust** — pressure her for answers, or wait and let her come forward
   → flag: `earned_mia_trust`

### Endings (3)

- **Good** — both flags true: Guardian purified, Mia's trust earned. Well
  fully restored, village warms to the player.
- **Neutral** — one flag true: partial resolution, well restored but
  something feels incomplete.
- **Bad** — both flags false: Guardian destroyed, Mia never opens up. Well
  stays broken; village grows wary of the player.

### Dialogue design

Every NPC has frequent light branching dialogue (2 response options,
affects only the next line — no state tracking). The two decisive choices
above are visually distinguished in the dialogue UI (different border/
color) so the player recognizes them as consequential.

## Threads left open for later (not implemented in v1.0)

- **The Watchers** — a scattered group working to keep the Veins from
  failing entirely. Yusuf is implied to be connected to them, though this
  is never confirmed in v1.0.
- **Other failing regions** — rumors of places far worse off than this
  village, hinting at a larger world beyond the current 3 zones.
- **Why the Veins are failing** — an unanswered mystery, intended to span
  future updates.

## Post-v1.0 Playtest Decision

After v1.0 (village/forest/cave, 4 NPCs, guardian event, 3
endings) is complete, playtest the full experience once
before deciding on scope. If combat, quests, or additional
NPCs are still wanted after playtesting, add them as a
"v1.5" layer on top of the existing structure — inserted
between existing story beats, not replacing them — starting
with the smallest possible version (1 class, 1-2 enemy types,
1-2 side quests) and expanding only after confirming it works.

## v1.5 addition — Kasim (Weapon Merchant)

Added alongside the v1.5 combat/equipment layer anticipated above (not a
core/state-tracked NPC — no ending impact, sells gear only).

- **Identity**: a hooded figure reusing the monster pack's Skeleton Crew
  "Rogue" sprite rather than a dedicated NPC one (every human NPC sprite
  was already spoken for). The dialogue leans into this on purpose —
  Kasim neither confirms nor denies being a monster when asked directly
  ("That's... not something to ask. Maybe someday, if the time comes.").
- **Placement**: stationed inside the village tavern.
- **Role**: sells all 9 pieces of equipment in the game — sword, staff,
  and shield, each in wood/bone/gold tier.
- **Dialogue structure**: shop entry ("What do you sell?"), self-intro
  ("Who are you?" — identity stays deliberately unresolved either way),
  and affinity-gated (50+) small talk about running a shop in such a
  remote village. Uses the same affinity system as the core NPCs.
- **Not yet implemented**: at max affinity, Kasim is meant to gift the
  player a weapon. Only the reverse (player → Kasim gift) exists so far.

## Part 2 — "Traces in the Sand" (added, no longer deferred to v2)

After the well is restored and reported to Elara, Yusuf reveals his true
affiliation: he belongs to the **Watchers**, a scattered group tracking
the failing Veins across the continent. This village's crisis was a small
signal — a desert settlement across the sea is dying much faster.

### New location: The Desert (reached by boat)

A small dock is added near the village's coastline. Taking the boat
leads to a desert region — a settlement being consumed by the same
force that dried the well, but far more advanced.

### New NPCs (2)

- **A Watcher companion** (Yusuf's colleague) — guides the player to the
  desert, reveals more about the Watchers' purpose and methods.
- **A desert settlement leader/survivor** — desperate, represents the
  human cost of the Veins failing; asks the player for help.

### Part 2 decisive choice

**Reveal the truth to the world, or keep it secret with the Watchers.**

- The Watchers argue secrecy prevents panic.
- The desert survivors argue the truth is needed so others can prepare.

This choice shapes a second layer of ending beyond the original three,
building on (not replacing) the Part 1 outcome.

### Part 2 goal

Investigate ancient ruins in the desert for clues to why the Veins are
failing. The full answer is deliberately left unresolved — consistent
with the original design note that this mystery spans future updates —
but the player learns enough to make the Part 2 decisive choice.

## Affinity system (added, replaces simple binary flags for ongoing NPC relationships)

Each core NPC (Elara, Rohan, Yusuf, Mia, plus the two new Part 2 NPCs)
has an `affinity` value (0-100, starts at 30). Regular dialogue choices
shift it by small amounts (±2-3); decisive story choices shift it by
larger amounts (±15-20). Thresholds (0-29 / 30-59 / 60-79 / 80-100)
unlock different dialogue tone and, at higher tiers, backstory the NPC
wouldn't otherwise share:

- Elara: at high affinity, shares an old record inherited from the
  previous elder about how past Vein failures were handled.
- Rohan: at high affinity, admits he suspects the orcs are victims of
  the same phenomenon, not simple aggressors.
- Yusuf: affinity gates how much of his Watcher identity and mission he
  reveals before the Part 2 reveal.
- Mia: at high affinity, reveals she's had recurring dreams connected to
  the Veins, predating the well incident.
