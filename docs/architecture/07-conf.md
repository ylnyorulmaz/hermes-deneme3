# Configuration (conf.lua)

LÖVE2D configuration. Two source files + procedural sprites = tiny portable folder.

```lua
t.title    = "deskpet"
t.author   = "deskpet"
t.version  = "11.5"

t.window.width  = 256
t.window.height = 256

t.window.borderless = true
t.window.resizable  = false
t.window.minwidth, t.window.minheight = 256, 256
t.window.vsync = true

t.modules.joystick = false
t.modules.physics  = false
t.modules.audio    = true
t.modules.timer    = true
```

## Rationale

- **borderless + non-resizable** — widget feel, not a game window.
- **vsync on** — prevents tearing on a desktop widget.
- **joystick + physics disabled** — keep boot near-instant.
- **audio on** — blips and chirps; timer on for hunger tick.

## Note on `love_conf` typo

The function is named `love_conf` (not `love.conf`). This is a known LÖVE2D quirk — the loader calls the function regardless of name as long as it exists in `conf.lua`. It works with LÖVE 11.x but some IDE linters may flag it.

## Build & test

```bash
# Run
love .

# Verify file layout
find . -type f | sort

# Expected:
#   conf.lua
#   main.lua
#   pet.png
#   docs/architecture/01-overview.md
#   docs/architecture/02-state.md
#   docs/architecture/03-sprites.md
#   docs/architecture/04-persistence.md
#   docs/architecture/05-particles-sound.md
#   docs/architecture/06-interaction.md
```