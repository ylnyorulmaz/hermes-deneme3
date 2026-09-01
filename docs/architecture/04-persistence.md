# Save / Load & persistence

## File format

State is written as a plaintext 5-line file at `PET.save_path` (`"deskpet.save"`):

```
{hunger}\n{affection}\n{now}\n{last_tick}\n{packed_xy}\n
```

- `packed_xy = floor(x) * 1000 + floor(y)`

This was chosen for simplicity: a single `love.filesystem.read/write` with a trivial parser, no serialization library.

## `save_state()`

```lua
data = string.format("%d\n%d\n%.0f\n%.0f\n%d\n",
    PET.hunger, PET.affection,
    love.timer.getTime(), PET.last_tick,
    math.floor(PET.x) * 1000 + math.floor(PET.y))
love.filesystem.write(PET.save_path, data)
```

Called on:

- `love.keypressed("escape")`
- `love.quit()`

## `load_state()`

1. Bail early if `love.filesystem.getInfo(PET.save_path)` is nil (first run).
2. Read and parse the 5-line format via pattern matching.
3. Clamp `hunger` and `affection` to `[0, 10]`.
4. **Offline hunger decay**: compute `delta = now - last_tick`, then `ticks = floor(delta / CFG.hunger_drain)`. Apply up to `ticks` points of hunger decay. Advance `last_tick` by `ticks * CFG.hunger_drain` so the live tick system picks up cleanly.
5. Window position is restored separately (in `love.load`), by parsing the same packed-xy value out of the saved file a second time.

## Offline decay rationale

If the app is closed for 60 minutes, the pet should not be starving instantly on reopen. The decay is computed lazily on load and applied as a lump sum so the in-game tick loop (which fires every `CFG.hunger_drain` seconds) remains in sync.

## Save lifecycle diagram

```
First run
  → no save file → defaults (hunger=10, affection=5, x=100, y=100)

Every run
  → load_state()
      → restore values
      → apply offline decay
      → restore window position

During runtime
  → every hunger tick (real-time)
  → affection decay every 60 s

On quit / escape
  → save_state()  → write current values
```