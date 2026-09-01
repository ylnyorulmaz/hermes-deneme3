# Overview

## What is deskpet?

deskpets is a Tamagotchi-style desktop widget built with [LÖVE 2D](https://love2d.org) (11.x) and Lua 5.1. It is a small, borderless, always-on-top window containing a chunky-pixel pet that the user feeds, pets, and watches. The pet's hunger decays over time and affection slowly fades — the user must interact to keep it happy.

The entire application fits in a single folder: two Lua source files (`conf.lua`, `main.lua`) plus one pixel-art image (`pet.png`, used as a fallback/fallback visual). All sprites are generated procedurally at runtime, so no sprite sheets or external assets are required at runtime.

## Running

```bash
love .
```

LÖVE reads `conf.lua` first, then enters `love.load` / `love.update` / `love.draw` / `love.mousepressed` / `love.keypressed`.

## Design goals

- **Tiny footprint** — no external assets beyond `pet.png`, all drawing is procedural.
- **Widget feel** — borderless, non-resizable window; drag to move, click to pet/feed.
- **Keychain-toy vibe** — chunky pixels, soft beeps, heartbeat-like hunger countdown.
- **Stateful** — window position and hunger are saved between sessions, with offline decay.

## File inventory

| File | Purpose |
|------|---------|
| `conf.lua` | LÖVE2D configuration (window, modules) |
| `main.lua` | All game logic (612 lines) |
| `pet.png` | Pixel-art image shipped with the project |
| `docs/architecture/*.md` | This documentation |

## High-level module map

```
main.lua
├── State (PET) & tunables (CFG, VIS)          [§0]
├── Pixel-art asset pipeline (procedural)      [§1]
├── Save / Load with offline decay             [§2]
├── Always-on-top (Windows FFI, commented)     [§3]
├── Particle system                            [§4]
├── Synthesized sound (SFX)                    [§5]
├── LÖVE callbacks                             [§6]
│   ├── love.load
│   ├── love.update
│   ├── love.draw
│   ├── love.mousepressed / mousemoved / mousereleased
│   └── love.keypressed / love.quit
├── LCD countdown + affection display          [§7]
├── Input handling (drag, feed, pet, AOT)      [§8]
└── Actions (pet_action, feed_action)          [§9]
```
