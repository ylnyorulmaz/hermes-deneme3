# State container & tunables

## PET — the state container

`PET` is the single source of truth for the pet's state:

| Field | Range | Meaning |
|-------|-------|---------|
| `hunger` | 0–10 | 10 = full, 0 = starving. Drains 1 every 30 s. |
| `affection` | 0–10 | Raised by petting. Decays slowly over time. |
| `last_tick` | float (love.timer) | Time of last hunger drain tick. |
| `last_pet` | float | Used to determine idle / sleep transitions. |
| `last_action` | float | Any activity timeout. |
| `born_at` | float | Reserved for future "day N" / growth hook. |
| `shake_t` | float | Remaining screen-shake seconds. |
| `hop_t` | float | Remaining hop (bounce) seconds. |
| `eat_anim_t` | float | Remaining eat-animation seconds. |
| `blink_t` | float | Remaining blink-overlay seconds. |
| `blink_next` | float | Seconds until next blink fires. |
| `particles` | table of Particle | Active particle list. |
| `x`, `y` | int (px) | Window position (saved/restored). |
| `drag_off` | nil or {dx, dy} | Active drag offset. |
| `lean` | float (rad) | Current affection lean angle. |
| `lean_target` | float (rad) | Target lean (computed from cursor). |
| `save_path` | string | `"deskpet.save"`. |

## CFG — configuration constants

```lua
max_hunger   = 10
hunger_drain = 30.0   -- seconds per hunger tick
feed_gain    = 2      -- hunger added per feed
pet_aff_gain = 1      -- affection added per pet
aff_decay    = 60.0   -- seconds per affection point
idle_sleep   = 300    -- 5 minutes before idle→sleep
hop_dur      = 0.18   -- hop animation length
shake_dur    = 0.25   -- shake duration
eat_dur      = 0.7    -- eat animation length
blink_dur    = 0.12   -- blink overlay duration
```

## VIS — derived display state

All constants that describe the appearance of the pet and its LCD display:

| Field | Value | Meaning |
|-------|-------|---------|
| `width`, `height` | 256, 256 | Logical window size |
| `pet_r` | 96 | Body radius |
| `pet_cx`, `pet_cy` | 128, 140 | Body center (offset to leave room for ears) |
| `lcd_cx`, `lcd_cy`, `lcd_r` | 128, 152, 56 | LCD belly center + radius |
| `bg`, `body`, `belly`, `lcd_bg`, `lcd_fg`, `heart` | color triples | Palette |

## Forward declarations

Lua resolves locals at chunk-compile time, so the callbacks below are forward-declared so that helper functions defined later in the file can still be captured as chunk-locals rather than globals:

```lua
local draw_lcd
local pet_action, feed_action
```

## How the state flows

```
love.load ──► load_state() ──► restore PET.hunger, PET.affection, window position
                                └── apply offline hunger decay

love.update(dt)
    ├── drain hunger every CFG.hunger_drain
    ├── decay affection
    ├── advance blink timer
    ├── advance transient timers (shake, hop, eat_anim)
    ├── idle breathing sound
    └── update_particles(dt)

love.draw()
    ├── background
    ├── corner badges (meat, heart)
    ├── pet sprite (mood-selected)
    ├── LCD belly
    ├── particles
    └── "z z z" when sleeping

love.keypressed
    ├── escape → save_state() + love.event.quit()
    ├── f      → feed_action()
    ├── p      → pet_action()
    └── t      → toggle always-on-top

love.mousepressed
    ├── left on body  → pet_action (not drag)
    ├── right on body → feed_action + start drag
    └── right outside → feed_action
```

The save file `deskpet.save` is written on quit and on key escape; it stores a 5-line plaintext blob (`hunger\naffection\nnow\nlast_tick\npacked_xy`).