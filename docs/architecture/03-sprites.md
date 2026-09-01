# Procedural sprite pipeline

All pet and icon graphics are generated procedurally into LÖVE2D canvases at `love.load`. No sprite sheets, no PNG atlas, no external image loader for the pet itself.

## `make_pet_frame(opts)` — the pet sprite

Creates a 192×192 canvas and draws the pet in layers:

1. **Ears** — two filled triangles (tan outer, darker inner).
2. **Body** — filled circle, radius 72, offset +8 px down so ears/hat have room.
3. **Belly** — cream circle, radius 46, slightly lower.
4. **Outline** — two stroked circles over body and belly.
5. **Eyes** — mood-dependent:
   - `idle` / `eat` / `sad`: two black circles with white shine dots.
   - `sleep`: two horizontal lines (closed eyes).
   - `sad`: slightly larger circles.
6. **Mouth** — mood-dependent arc:
   - `eat`: filled arc (open mouth).
   - `sad`: open arc (frown).
   - `sleep`: small arc.
   - `idle`: small filled arc.
7. **Whiskers** — four lines on each cheek.
8. **Blink overlay** — a dark bar across the eyes when `mood == "blink"`.
9. **"EAT" prompt** — red text above the head when `sad && hungry`.

Returned canvas is placed into `SPR.pet[mood]`.

## `make_icon(kind)` — badge icons

Creates a 32×32 canvas. Two kinds:

- `"meat"` — red circle with a highlight dot and outline (food badge).
- `"heart"` — pink heart polygon (affection badge).

## Mood selection — `pet_sprite()`

```lua
mood = "sad"     if hunger <= 3
mood = "eat"     if eat_anim_t > 0
mood = "sleep"   if idle for > CFG.idle_sleep seconds
mood = "blink"   if blinking (idle overlay)
mood = "idle"    otherwise
```

`blink` takes precedence over `idle` whenever `PET.blink_t > 0`. The function returns `SPR.pet[mood]`.

## `SPR` table

Populated in `love.load`:

```lua
SPR.pet  = { idle, blink, eat, sad, sleep }
SPR.meat = make_icon("meat")
SPR.heart = make_icon("heart")
```

## Design rationale

- **Procedural** means the entire pet fits in ~few KB on disk.
- **Chunky pixel** style is intentionally low-resolution (192 px) so individual geometric primitives look like pixel art without needing an art tool.
- **One canvas per mood** avoids per-frame redraw; we swap the canvas via `love.graphics.setCanvas`.