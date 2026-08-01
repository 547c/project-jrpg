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

## v2 Roadmap (planned, not started) — "Traces of the Watcher"

- New zone(s) beyond the current three.
- Yusuf's true affiliation with the Watchers is revealed.
- The player's ending state from v1.0 (which flags were set) carries over
  and affects how Yusuf and the village react at the start of v2 — this is
  the actual motivating use case for save/load, which was optional in v1.0.
- New NPCs, a new decisive choice, and a larger-stakes event tied to
  another region's decline.
