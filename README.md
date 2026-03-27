# NEURODIVE

**A neural descent into the void.**

Retro-style terminal falling game written in pure Zig. Dodge obstacles, collect data fragments, and survive the endless descent between towering monolithic structures.

![Zig](https://img.shields.io/badge/Zig-0.15.2-f7a41d?logo=zig&logoColor=white)
![Platform](https://img.shields.io/badge/platform-macOS%20|%20Linux%20|%20Windows-000000)

```
 _   _  _____  _   _  ____    ___   ____   ___ __     __ _____
| \ | || ____|| | | ||  _ \  / _ \ |  _ \ |_ _|\ \   / /| ____|
|  \| ||  _|  | | | || |_) || | | || | | | | |  \ \ / / |  _|
| |\  || |___ | |_| ||  _ < | |_| || |_| | | |   \ V /  | |___
|_| \_||_____| \___/ |_| \_\ \___/ |____/ |___|   \_/   |_____|
```

## Gameplay

You are falling. Endlessly. Between the walls of a digital megastructure.

- **Dodge** obstacles — windows `[##]` and eyes `(o)` will sever your neural link
- **Collect** data fragments — diamonds `<>` (50 pts) and chips `$` (25 pts)
- **Survive** as long as possible — speed increases the deeper you go

## Controls

| Key | Action |
|-----|--------|
| `←` `→` | Move left / right |
| `Enter` | Start / Retry |
| `Q` | Quit |

## Requirements

- [Zig](https://ziglang.org/) 0.15.2+
- A terminal with ANSI escape code support

## Build & Run

```sh
zig build run
```

Or build first and run the binary directly:

```sh
zig build
./zig-out/bin/neurodive
```

## Features

- **Zero dependencies** — pure Zig standard library, no external packages
- **Zero allocations** — all game state lives on the stack with fixed-size arrays
- **Flicker-free rendering** — 32KB frame buffer flushed in a single write
- **30 FPS game loop** — precise delta-time frame pacing
- **Persistent highscore** — saved to `~/.neurodive_highscore`
- **Raw terminal mode** — direct termios control, no ncurses

## Architecture

```
src/
  main.zig        Entry point, 30 FPS game loop with delta-time
  game.zig        State machine (Title -> Playing -> Game Over)
  terminal.zig    Raw mode, ANSI codes, non-blocking input
  renderer.zig    Building walls, entities, HUD, screens
  world.zig       Entity pool, spawning, scrolling, collision
  player.zig      Position, movement, hitbox
  score.zig       Scoring, highscore persistence
```
