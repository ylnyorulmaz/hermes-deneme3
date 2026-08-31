-- conf.lua — deskpet
-- LÖVE2D configuration. Two files + procedural sprites = tiny portable folder.

function love.conf(t)
    t.title    = "deskpet"
        t.author   = "deskpet"
        t.version  = "11.5"

    -- The pet is a small floating widget. ~256x256 logical window; we scale up
    -- so the chunky pixels stay readable on hi-DPI screens.
    t.window.width  = 256
    t.window.height = 256

    -- Borderless + no resize so it feels like a desktop widget, not a game.
    t.window.borderless = true
    t.window.resizable  = false
    t.window.minwidth, t.window.minheight = 256, 256

    -- No menu bar clutter; that's the vibe of a keychain toy.
    t.window.vsync = true

    -- Modules we don't use — keep boot near-instant.
    t.modules.joystick = false
    t.modules.physics  = false

    -- Always-on-top toggle: on Windows the LÖVE FFI snippet below does it.
    -- See main.lua -> apply_always_on_top() for the platform guard.
    t.modules.audio   = true   -- blips + chirps
    t.modules.timer   = true
end