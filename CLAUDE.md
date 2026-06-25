# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.6 roguelike ("Prueba-Roguelike") written in GDScript, targeting mobile (Android export). Pixel-art 2D game with procedurally generated cave dungeons (Drunkard's Walk algorithm), 4-directional player character, enemies (Chort, Goblin), collectibles, and a tutorial system. The project language is Spanish — signals, variables, docs, and commit messages use Spanish.

## Running the Project

Open `project.godot` in Godot 4.6 editor. Main scene entry point: `Stages/Main/MainBueno.tscn`. No build system or CLI test runner — all testing is done by running the game in the editor.

## Architecture

Detailed architecture docs live in `Common/Docs/` — read those before making structural changes:
- `architecture.md` — State machine, directional animation system, interaction system, node communication rules
- `context.md` — Directory conventions, autoloads, physics layers, naming rules
- `data_and_save.md` — Procedural cave generation (Drunkard's Walk), room system, spawn system, data/persistence patterns

### Key Patterns

**State Machine (FSM):** `Common/StateMachine/` — `StateMachine` node injects cached components (InputComponent, VelocityComponent, HealthComponent, NavigationComponent) into all child `State` nodes at `_ready()`. States request transitions via `transitioned.emit(self, "StateName", {args})`. Never use `emit_signal()`.

**Directional Animations:** Player uses 4-direction spritesheets (down/right/up/left as rows). `player.gd._ready()` generates named animations (`idle_down`, `walk_right`, etc.) from AtlasTexture at runtime. States call `play_directional_anim("base_name")` which auto-appends the direction suffix, with fallback to non-directional name for enemies. Direction tracked via `InputComponent.last_direction`.

**Component System:** Entity behavior is split into reusable components in `Entities/Scripts/Character/`:
- `InputComponent` (base, exposes `last_direction`) → `PlayerInputComponent` (reads `Input`, updates direction) / `EnemyInputComponent` (derives from player position)
- `VelocityComponent`, `HealthComponent`, `NavigationComponent`
- `HitBox` / `HurtBox` for combat collision

**Procedural Generation:** `Stages/Layouts/Cave/start_cave.gd` generates cave maps using Drunkard's Walk. Creates grid of `RoomLayout` instances (`Layout1.tscn`) with configurable room types (Start, Boss, Easy, Medium, Hard, Puzzle, Rest). Each room auto-configures doors (open/closed) based on grid neighbors and injects appropriate `SpawnCategory` enemy pools.

**Interaction System:** Interactable objects (chests, doors) never read `Input` directly. They register themselves as `player.current_interactable` via Area2D signals, and the player calls `interact()` when the action input fires.

**Scene Transitions:** Always go through `GameManager.load_scene(path)`, which wraps `change_scene_to_file()`.

### Autoloads (Singletons)

| Name | Script | Purpose |
|------|--------|---------|
| `GameManager` | `Utilities/game_manager.gd` | Coin state + scene transitions |
| `SoundManager` | `Utilities/sound_manager.gd` | Fire-and-forget SFX playback |
| `TutorialManager` | `Utilities/TutorialManager.gd` | Tutorial step tracking + UI signals |

Access directly by name (e.g., `GameManager.add_coins(1)`). Never instantiate manually.

### Physics Layers

1=environment, 2=hurtbox, 3=hitbox, 4=enemies, 5=collectibles, 6=hitbox_player, 7=player, 8=interactive

## Conventions

- `snake_case` for scripts/variables, `PascalCase` for class names and node names
- Godot 4 signal syntax only: `signal_name.emit(args)` — never `emit_signal()`
- Only `PlayerInputComponent` and `EnemyInputComponent` read from `Input`
- Balance values (HP, speed) go in `@export` properties on components, not hardcoded in scripts
- New enemies: create scene in `Entities/Enemies/NewEnemy/` following `Chort.tscn` structure (CharacterBody2D + StateMachine + components), add to a `SpawnCategory` resource
- New interactables: implement `interact()`, register via Area2D body_entered/exited signals following `chest.gd` pattern
