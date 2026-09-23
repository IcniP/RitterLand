<h1 align="center">Ritterland</h1>

<p align="center">
  <i>A story-driven academy RPG where you play the one person who knows how the story is supposed to end.</i>
</p>

<p align="center">
  <img alt="Godot 4.5+" src="https://img.shields.io/badge/Godot-4.5%2B-478cbf?logo=godotengine&logoColor=white">
  <img alt="Dialogic 2" src="https://img.shields.io/badge/Dialogic-2.0%20alpha-6BCD69">
  <img alt="Status" src="https://img.shields.io/badge/status-in%20development-orange">
  <img alt="Genre" src="https://img.shields.io/badge/genre-academy%20RPG%20%2F%20visual%20novel-blueviolet">
</p>

<!-- Add a screenshot or GIF here: ![Gameplay](docs/screenshot.png) -->

## About

**Ritterland** is a 2D academy RPG that mixes visual-novel storytelling with grid-based tactical combat, in the spirit of an academy-setting manhwa you can actually play.

You are **Lan Schwert**, a retired competitive swordsman who wakes up inside *Ritterland*, the brutal fantasy game he spent 2,450 hours perfecting. He knows every route, every trigger, and the price the game always demands: friends die, countries vanish, nobody gets a clean ending.

He enrolls at **Tausend Sterne Academy** with a plan to stay unnoticed, rank sixty-seven out of eighty-four, and quietly keep the story's hero alive. Then he checks the rank board and the hero's name is missing.

## Genre

- Academy RPG / visual novel hybrid
- Grid-based tactical combat with simultaneous turn resolution
- Character-driven story with relationship (affinity) meters
- Fantasy, with swordplay grounded in historical European martial arts (HEMA)

## Story

The game follows the novel *Ritterland* chapter by chapter. Season 1 runs from the prologue through Chapter 15:

- Lan's exile from his mountain home and his six years alone on the road
- Entrance trials, the ceremony, and the discovery that someone has been erased from the rank list
- The first months at Tausend Sterne: sparring under Instructor Amir, a monster hunt that turns into an assassination attempt, and the Headmaster's questions about Lan's family
- A secret sparring pact in the abandoned east wing, a public duel, and a strange pill that should not exist yet
- The Alchemy Fair ambush, and the boy who learns what he is not strong enough to protect yet

The story is fixed to the novel. Your choices change how Lan talks and how the people around him feel about him. They do not change what happens.

## Features

- **Story-locked branching dialogue.** Every choice is a different way for Lan to respond (dry, sarcastic, sincere), and each one nudges an affinity meter. Rank and plot follow the novel exactly.
- **Affinity system.** Track your bond with Liesel, Enriko, Veldero, Leonora, Ilia, Florentine, Raiz and others.
- **Simultaneous tactical combat.** Queue actions for your whole party during a Planning phase, then watch them resolve together in order of speed. Actors who fall before their turn have their action cancelled.
- **Combat zones.** Fights start when a scene's dialogue ends and hand control back to the dialogue when the fight is over.
- **Custom dialogue polish.** Slow single-beat ellipses, shortened line breaks, and a flash-and-fade portrait swap, all built on Dialogic 2.
- **Cutscene glue.** A small autoload connects Dialogic signals to sprites, backgrounds and combat.

## Main Cast

| Character | Role |
|---|---|
| **Lan Schwert** | The player. A retired swordsman with a wasted gi reserve and a montante he keeps wrapped up. |
| **Enriko** | Support Department, rich, chatty, and secretly well-connected. |
| **Veldero** | Physical Department, ordinary on the surface. Seventy-four of eighty-four. |
| **Liesel** | Healer with a flat stare and the smoothest gi control in the year. |
| **Leonora von Rosendael** | Crown Princess of Britannic Arcana, rank three. |
| **Ilia (Iliako Fengari)** | Ninth in the whole academy, and a very good secret keeper. |
| **Florentine** | Gifted alchemist. |
| **Raiz Al Khalid** | Rank one, prince of Al-Tale'a. |
| **Berthram** | The Headmaster, and the Empire Sun. |
| **Amir** | Head sword instructor. |

## Gameplay Overview

1. **Explore** the academy in real time and talk to students and instructors.
2. **Dialogue** scenes play out chapter by chapter, with reply choices and affinity changes.
3. **Combat** starts from story triggers. In the Planning phase you queue moves and attacks for each party member, then Execution resolves everyone's actions by speed.
4. **Progress** through the season while your relationships grow.

## Project Status

This is an active work in progress.

| Area | State |
|---|---|
| Season 1 script (Prologue, Ch. 1 to 15) | Written as Dialogic timelines |
| Dialogue polish (line lengths, ellipses, portrait swap) | Done |
| Combat (planning and execution, party, combat zone) | Prototype |
| Cutscene and combat hand-off | Prototype with placeholder sprites |
| Character portraits and sprites | Mostly placeholder |
| Season 2 | Planned |

## Tech Stack

- **Engine:** [Godot](https://godotengine.org/) 4.5 or newer
- **Dialogue:** [Dialogic 2](https://github.com/dialogic-godot/dialogic) (alpha)
- **Language:** GDScript

## Getting Started

1. Install Godot 4.5 or newer.
2. Clone the repository:
   ```
   git clone https://github.com/IcniP/RitterLand.git
   ```
3. Open the project in Godot (`project.godot`) and let it import assets.
4. Make sure the **Dialogic** plugin is enabled under Project Settings, Plugins.
5. Run the project. To start a chapter from code:
   ```gdscript
   Cutscene.play("ch00_prologue")
   ```

## Project Structure

```
Dialog/S1/          Season 1 timelines (.dtl) and character files (.dch)
Scripts/core/       Global state, combat manager, turn manager, cutscene glue
Scripts/entities/   Player, party, enemy and NPC base classes
Scripts/ui/         Combat HUD, pause menu, input handling
Assets/             Sprites, portraits, custom textbox
scenes/             Character and enemy scenes
addons/dialogic/    Dialogic 2 plugin
```

## Credits

- Story, game design and development by [IcniP](https://github.com/IcniP).
- Dialogue system: [Dialogic 2](https://github.com/dialogic-godot/dialogic) by Jowan-Spooner, Emilio Coppola and contributors (MIT).

## License

See [LICENSE](LICENSE). Dialogic is included under its own MIT license.
