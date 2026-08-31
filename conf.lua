function love.conf(t)
    t.identity = "deskpet"          -- save dir name
    t.version  = "11.4"
    t.console  = false

    t.window.title     = "Pet"
    t.window.width     = 240
    t.window.height    = 280
    t.window.borderless = true
    t.window.resizable  = false
    t.window.vsync      = 1

    -- strip modules we don't use (lighter footprint)
    t.modules.joystick = false
    t.modules.physics  = false
    t.modules.video    = false
    t.modules.touch    = false
    t.modules.thread   = false
end