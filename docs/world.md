# World Bible — Project JRPG

## Setting

Long ago, the land of Orsia was sustained by the **Veins** — ancient
channels said to carry the world's life force beneath the earth, feeding
villages, forests, and mountains alike. In that age the land was fertile
beyond memory and people lived long, healthy lives.

Today the Veins run far weaker across the entire continent — but no
living person remembers it any other way, so the diminished flow is
simply believed to be normal. The truth, hidden from the surface world,
is that this was never a natural decline (see "The Truth" below).

The player begins in a small village on the far edge of the continent —
one of the last villages where a Vein still flows at all. The village
well has just run dry for the first time in living memory.

*(In-game, this backstory is delivered gradually through NPC dialogue and
discovery, never as an upfront exposition dump. Early dialogue never uses
meta-terms like "the Veins" casually — NPCs speak plainly: "the well's
gone dry," "something's wrong in the cave.")*

## The Truth (revealed gradually across Part 1 and Part 2)

- **The Watchers** are an order of immortal beings who discovered,
  centuries ago, how to control the flow of the Veins. Their method:
  forcibly seal a living person inside a containment vessel — **a
  Warden** — and place one near each major Vein. A Warden acts as a
  filter: it drastically cuts the flow reaching its village and siphons
  the rest down into the Watchers' hidden underground world.
- The Veins are the source of life itself — power and wealth to the
  Watchers, who use the siphoned flow to sustain their own immortality.
  That immortality isn't a one-time gift; it requires continuous supply,
  which is why the theft has never stopped.
- To keep the surface world docile, the Watchers built and maintained a
  myth: a Warden is not a person, but a benevolent **Guardian spirit**,
  worthy of shrines and offerings. The village's well-wishing customs and
  the old stone altar outside the cave are relics of this cover story.
- Why steal gradually instead of all at once: (1) a Warden's containment
  has a throughput limit — draining a Vein too fast destroys the Warden
  and the site before the theft is complete; (2) an abrupt change would
  be noticed and provoke revolt, while a slow, generational decline goes
  unnoticed — today's belief that the current flow is "normal" is proof
  the strategy worked; (3) immortality demands constant resupply, so the
  system was designed to extract forever, not once — and as more
  villages are fully drained into desert, the shrinking number of viable
  villages left must be drained harder, an unsustainable structure now
  nearing collapse.
- The player's village is one of the last places on the continent where
  a Warden hasn't yet been fully drained.

## What Actually Happened That Night

The village's Warden had been sealed for centuries, its will and memory
all but erased — until the Watchers ordered this village's Vein drained
completely (so few undrained villages remain). A last, faint spark of the
Warden's humanity resisted that order. That resistance — not malfunction,
not corruption — was the tremor, the low cry, and the blue light the
villagers felt that night. The well running fully dry wasn't compliance;
it was a side effect of the Warden losing fine control while straining
against the command. What Rohan and Mia each separately described as a
"sad sound" was, literally, exactly that.

## Guardian Resolution — Two Outcomes

- **Combat**: the Warden's containment is destroyed outright. The village
  is permanently cut off from the Watchers' network (a "failed
  collection" from their side); the flow returns, unstable, with no one
  left to regulate it. The Warden dies having successfully resisted —
  with no one left alive to know why.
- **Dialogue**: rather than simply calming the Warden, the player's
  persistence convinces it to release its own binding. Sensing something
  in the player, it lets go — not a death, but a self-chosen release. In
  its final moment before dissolving, it leaves a fragmentary warning:
  the Watchers exist, and they live underground.

Both paths converge on the same payoff: the true, ancient volume of the
Vein bursts through the broken filter — far more water than the well
ever produced, physical proof something has been wrong for a very long
time.

## Yusuf's Real Role (supersedes any earlier "Watcher ally" framing)

Yusuf is not part of a group trying to *stop* the Veins from failing —
he is a former surface-world operative *for* the Watchers. Recruited
under the belief he was helping maintain "an old, harmless tradition,"
he eventually saw a Warden up close and realized what he'd actually been
part of. He fled, and has drifted between villages since — which is also
how he already knows the pattern repeats: nearly every village he's
passed through was already a desert.

## v1.0 Scope — "The Village Well"

The well dried up because of what's sealed within the nearby cave — see "The Truth" below for what the villagers don't know.

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

## Part 2 (structure in progress)

Yusuf's true history is now established (see "Yusuf's Real Role" above).
The full Part 2 arc — confronting Yusuf, the desert/ruins reveal, and the
final confrontation with the Watchers underground — is still being
written. This section will be filled in once that's finalized.

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
