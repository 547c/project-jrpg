# Project JRPG

A small 2D top-down JRPG built in Godot 4.7, developed as a solo learning project to understand and implement core CS concepts — particularly state management — from scratch.

## Why this project

I got into playing open-world RPGs since childhood, and what pulled me in wasn't just the combat or graphics but t was how the world seemed to remember what I did and react to it. NPCs referenced pat choices, areas changed based on progress. I wanted to understand how that actually works under the hood, which is part of what led me to study CS. In high school I built a visual novel with branching choices in Ren'Py, but never implemented a system that accumulated state across choices — that was a skill gap, not a tool limitation. This project is a direct attempt to close that gap by designing a state system myself.

## Goals

This is not meant to be a polished commercial game. The goal is a small, finished project that demonstrates:

* A self-designed state management system (Autoload singleton + signal-based flag system)
* NPC dialogue that reacts to accumulated player state
* Branching choices and multiple endings
* A minimal turn-based combat system

## Tech stack

* Engine: Godot 4.7 (GDScript)
* Assets: Pixel Crawler - Free Pack (CC0, itch.io)
* AI tooling: Claude Code used as an implementation/debugging assistant. All architectural decisions (state structure, signal design, system scope) are made by me first; Claude Code implements based on those decisions.

## Progress

* [x] 4-directional player movement + locked camera
* [x] Sprite animation (walk/idle, 4 directions) with pixel-art filtering
* [ ] Scene/map transitions (2–3 zones)
* [ ] State management system (Autoload, flag-based, signal-driven)
* [ ] NPC dialogue reacting to state
* [ ] Branching choices
* [ ] 2–3 ending paths
* [ ] Minimal turn-based combat (1 class implemented, 2 more as W.I.P.)
* [ ] Save/load (stretch goal)

## Screenshots

(added as development progresses)

## Scope notes

Kept intentionally small: 2–3 zones, 1–2 NPCs, one fully implemented class with basic combat. This is a portfolio piece meant to be finished and explainable, not a full commercial RPG.
