# Particle system

## Data structure

Each particle is a table:

| Field | Type | Meaning |
|-------|------|---------|
| `x`, `y` | float | Position (world coords). |
| `vx`, `vy` | float | Velocity (px/s). |
| `life` | float | Total lifetime in seconds. |
| `age` | float | Elapsed time. |
| `size` | int | Drawing radius or side length. |
| `color` | {r, g, b} | RGB triples. |
| `kind` | string | `"heart"` or absent (crumb). |

## Spawning

- `spawn_crumbs(x, y)` — 12 crumbs at a feed position. Brownish color, random upward+sideways velocity, 0.6–0.9 s lifetime, size 2.
- `spawn_hearts(x, y)` — 5 hearts at a pet position. Pink, upward velocity, 0.8 s lifetime, size 6.

## Update (`update_particles(dt)`)

Iterates in-place with a manual index (to handle removals efficiently):

1. Advance `age += dt`.
2. If `age >= life`, `table.remove`.
3. Otherwise, integrate position, apply a light gravity (`vy += 120 * dt`), increment index.

## Draw (`draw_particles()`)

For each particle, alpha = `1 - age / life`. Hearts draw as circles; crumbs draw as rectangles.

## Design note

The manual `while i <= #PET.particles` loop with `table.remove` avoids creating a new table every frame — important because particles are spawned and removed every few seconds.

## Sound synthesis (SFX)

No audio files are used. All sounds are synthesized into `SoundData` at runtime:

- `beep(freq, dur, vol)` — generates `floor(sr * dur)` samples of a sine wave at `freq` Hz with a 4× fade-out envelope. Plays through `love.audio`.
- `chirp_arpeggio()` — C5 (523.25) → E5 (659.25) → G5 (783.99), a happy chord. Fired on pet.
- `whine()` — low 220/196 Hz tone, fired when hunger hits 3.
- `breathe()` — random high-ish tone, fired every ~6 s while sleeping.

`SFX` table keeps references to playing sources; they self-clean via LÖVE's source lifecycle.