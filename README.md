# Project JRPG

A small 2D top-down JRPG built in Godot 4.7, developed as a solo learning
project to understand and implement core CS concepts — particularly
**state management** — from scratch.

## Why this project

I got into playing open-world RPGs since childhood, and what pulled me in
wasn't just the combat or graphics but how the world seemed to *remember*
what I did and react to it. NPCs referenced past choices, areas changed
based on progress. I wanted to understand how that actually works under
the hood, which is part of what led me to study CS.

In high school I built a visual novel with branching choices in Ren'Py,
but never implemented a system that accumulated state across choices —
that was a skill gap, not a tool limitation. This project is a direct
attempt to close that gap by designing a state system myself.

The full world/story design is documented in [docs/world.md](docs/world.md).

## Goals

This is not meant to be a polished commercial game. The goal is a small,
**finished** project that demonstrates:
- A self-designed state management system (Autoload singleton + signal-based
  flag system)
- NPC dialogue that reacts to accumulated player state
- Branching choices and multiple endings
- A minimal turn-based combat system tied to optional side quests

## Tech stack

- **Engine:** Godot 4.7 (GDScript)
- **Assets:** Pixel Crawler - Free Pack (CC0, itch.io); a licensed GUI
  pack for UI styling (see Assets section below)
- **AI tooling:** Claude Code used as an implementation/debugging assistant.
  All architectural decisions (state structure, signal design, system
  scope) are made by me first; Claude Code implements based on those
  decisions.

## Assets

This project uses a licensed GUI asset pack for UI styling that cannot be
redistributed. It is excluded from this repository via `.gitignore`. See
the Screenshots section below for how the interface actually looks.

## Progress

- [x] 4-directional player movement + locked camera
- [x] Sprite animation (walk/idle, 4 directions) with pixel-art filtering
- [x] Scene/map transitions (village/forest/cave)
- [x] State management system (Autoload, flag-based, signal-driven)
- [x] NPC dialogue reacting to state (4 NPCs, branching + gossip system)
- [x] Branching choices with two decisive story flags
- [x] 3 ending paths (good/neutral/bad)
- [x] Title screen and opening cutscene
- [x] Minimal turn-based combat (encounters, HP, defeat penalty)
- [x] Side quests gating access to the main story's climax
- [ ] Save/load system (in progress)
- [ ] Additional playable classes (stretch goal, not started)

## Screenshots

_(added once save/load and remaining UI polish are done)_

## Scope notes

Kept intentionally small: 3 zones, 4 core NPCs, one fully implemented
combat loop tied to two side quests. This is a portfolio piece meant to
be finished and explainable, not a full commercial RPG. Ideas beyond this
scope (additional classes, larger side content) are tracked as a
post-v1.0 roadmap in [docs/world.md](docs/world.md) rather than added
mid-development.
