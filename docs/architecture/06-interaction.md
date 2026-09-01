# Interaction & input

## Window behavior

- Borderless, non-resizable 256×256 logical window.
- Drag anywhere on the body to move the window.
- Right-click anywhere to feed.
- Left-click on body to pet.

## Mouse input

### `love.mousepressed(x, y, button)`

- Body hit-test: `(x - pet_cx)^2 + (y - pet_cy)^2 <= (pet_r + 10)^2`.
- **Left click on body** → `pet_action(x, y)`. Left-click does NOT start a drag (drag is right-click only).
- **Right click on body** → `feed_action(x, y)` + start drag (`PET.drag_off = {dx, dy}`).
- **Right click outside body** → `feed_action(x, y)` (no drag).
- **Left click outside body** → nothing.

### `love.mousemoved(x, y, dx, dy)`

- If dragging: move window by `(dx, dy)` and update `PET.x`, `PET.y`.
- Affection lean: if `affection >= 6`, bias `lean_target` toward cursor horizontally.

### `love.mousereleased(x, y, button)`

- Release drag on button 2 (right).

## Keyboard input (`love.keypressed`)

| Key | Action |
|-----|--------|
| `escape` | Save state, quit. |
| `f` | Feed (calls `feed_action(0, 0)`). |
| `p` | Pet (calls `pet_action(VIS.pet_cx, VIS.pet_cy)`). |
| `t` | Toggle always-on-top (Windows FFI). |

## Actions

### `pet_action(x, y)`

1. Set `hop_t = CFG.hop_dur` (bounce).
2. Reset `last_pet` and `last_action`.
3. `affection = min(10, affection + pet_aff_gain)`.
4. Spawn heart particles at `(x, y)`.
5. If > 0.4 s since last chirp, play `chirp_arpeggio()`.

### `feed_action(x, y)`

1. Bail if `hunger >= max_hunger`.
2. `hunger = min(max_hunger, hunger + feed_gain)`.
3. Reset `last_tick`.
4. Start eat animation (`eat_anim_t = eat_dur`), shake (`shake_dur`).
5. Spawn crumb particles at `(x, y)`.
6. Play a 440 Hz beep.

## Always-on-top (AOT)

Windows FFI snippet is present but commented out (intentionally, per spec). `Alt+T` toggles `AOT.enabled`. The FFI call uses `SetWindowPos` with `HWND_TOPMOST`. On non-Windows the branch is a no-op since `AOT.supported` is never set.

## LCD belly

The LCD is drawn over the cream belly patch every frame:

1. Brown filled circle background with outline.
2. Pie sweep from top (−π/2) clockwise; arc shrinks as hunger depletes (full at last tick, empty approaching next tick).
3. Countdown text: `ceil(hunger_drain - elapsed)` seconds.
4. Affection display: `v` repeated `affection` times below the LCD.

## Emotion lean

When affection ≥ 6, `lean_target` follows the horizontal cursor offset, making the pet tilt toward the mouse. Lerped at `dt * 4` per frame.

## Sleeping idle

After 5 minutes of no petting, the pet enters `sleep` mood:
- Eyes close (horizontal lines).
- Mouth becomes a small arc.
- Breathing sound every ~6 s.
- `"z z z"` text floats above the pet.