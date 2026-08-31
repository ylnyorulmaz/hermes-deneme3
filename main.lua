-- ============================================================================
-- deskpet — a Tamagotchi-style desktop widget
-- LÖVE2D 11.x, Lua 5.1-compatible (love2d bundles Lua 5.1).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. State container & tunables
-- ---------------------------------------------------------------------------

local PET = {
    -- hunger: 0 = starving, 10 = full. Drains 1 every 30s.
    hunger       = 10,
    -- affection: 0..10, raised by petting. Decays very slowly.
    affection    = 5,
    -- time bookkeeping
    last_tick    = 0,        -- love timer time at last hunger tick
    last_pet     = 0,        -- for idle / sleep
    last_action  = 0,        -- for any activity timeout
    born_at      = 0,        -- for "day N" / growth (future hook)

    -- transient effects
    shake_t      = 0,        -- remaining shake seconds
    hop_t        = 0,        -- remaining hop seconds (pet bounce)
    eat_anim_t   = 0,        -- eat animation remaining
    blink_t      = 0,        -- blink overlay remaining
    blink_next   = 2,        -- next blink in seconds

    -- particles
    particles    = {},

    -- positioning
    x, y         = 100, 100, -- window position
    drag_off     = nil,     -- {dx, dy} while dragging

    -- affection lean: target lean angle (radians)
    lean         = 0,

    -- save path
    save_path    = "deskpet.save",
}

local CFG = {
    max_hunger    = 10,
    hunger_drain  = 30.0,   -- seconds per hunger tick
    feed_gain     = 2,
    pet_aff_gain  = 1,
    aff_decay     = 60.0,   -- seconds per affection point of decay
    idle_sleep    = 300,    -- 5 minutes
    hop_dur       = 0.18,
    shake_dur     = 0.25,
    eat_dur       = 0.7,
    blink_dur     = 0.12,
}

-- derived display state
local VIS = {
    width   = 256,
    height  = 256,
    pet_r   = 96,                  -- radius of the round body
    pet_cx  = 128,
    pet_cy  = 140,                 -- body sits below center to leave room for ears/hat
    lcd_cx  = 128,
    lcd_cy  = 152,
    lcd_r   = 56,
    bg      = {0.07, 0.10, 0.18},  -- dark navy
    body    = {0.86, 0.62, 0.36},  -- tan/orange
    belly   = {0.96, 0.89, 0.74},  -- cream
    lcd_bg  = {0.36, 0.21, 0.10},  -- brown LCD
    lcd_fg  = {0.95, 0.88, 0.55},  -- LCD pixel text
    heart   = {0.95, 0.32, 0.42},
}

-- ---------------------------------------------------------------------------
-- 1. Pixel-art assets, drawn procedurally into canvases on love.load
--    Keeps the folder at ~few KB; no PNG sprite sheet required.
-- ---------------------------------------------------------------------------

local SPR = {}   -- sprite canvases

-- A "chunky pixel" frame for the pet: round body + cat ears + face + belly patch.
local function make_pet_frame(opts)
    opts = opts or {}
    local mood = opts.mood or "idle"   -- "idle" | "eat" | "sad" | "sleep" | "pet"
    local size = 192
    local c = love.graphics.newCanvas(size, size)
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)

    -- ears (triangles)
    love.graphics.setColor(VIS.body)
    love.graphics.polygon("fill",
        60, 60,  78, 18,  96, 56)        -- left ear
    love.graphics.polygon("fill",
        132, 56, 150, 18, 168, 60)       -- right ear
    love.graphics.setColor(0.55, 0.36, 0.18)
    love.graphics.polygon("fill",
        70, 56,  82, 30,  90, 54)        -- inner left ear
    love.graphics.polygon("fill",
        138, 54, 146, 30, 158, 56)       -- inner right ear

    -- body (round)
    love.graphics.setColor(VIS.body)
    love.graphics.circle("fill", size/2, size/2 + 8, 72)

    -- belly (cream patch)
    love.graphics.setColor(VIS.belly)
    love.graphics.circle("fill", size/2, size/2 + 18, 46)

    -- outline
    love.graphics.setColor(0.20, 0.12, 0.06)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", size/2, size/2 + 8, 72)
    love.graphics.circle("line", size/2, size/2 + 18, 46)
    love.graphics.setLineWidth(1)

    -- eyes (position depends on mood)
    love.graphics.setColor(0.10, 0.06, 0.04)
    if mood == "sleep" then
        love.graphics.line(size/2 - 18, size/2 - 2, size/2 - 8,  size/2 - 2)
        love.graphics.line(size/2 + 8,  size/2 - 2, size/2 + 18, size/2 - 2)
    elseif mood == "sad" then
        love.graphics.circle("fill", size/2 - 14, size/2 + 0, 3)
        love.graphics.circle("fill", size/2 + 14, size/2 + 0, 3)
    else
        love.graphics.circle("fill", size/2 - 14, size/2 - 6, 3)
        love.graphics.circle("fill", size/2 + 14, size/2 - 6, 3)
        -- eye shine
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", size/2 - 12, size/2 - 8, 1, 1)
        love.graphics.rectangle("fill", size/2 + 16, size/2 - 8, 1, 1)
    end

    -- mouth
    love.graphics.setColor(0.20, 0.10, 0.06)
    if mood == "eat" then
        love.graphics.arc("fill", size/2, size/2 + 14, 6, 0, math.pi)
    elseif mood == "sad" then
        love.graphics.arc("line", size/2, size/2 + 14, 5, math.pi, 2 * math.pi)
    elseif mood == "sleep" then
        love.graphics.arc("line", size/2, size/2 + 14, 4, 0, math.pi)
    else
        love.graphics.arc("fill", size/2, size/2 + 8, 3, 0, math.pi)
    end

    -- whiskers
    love.graphics.setColor(0.20, 0.10, 0.06)
    love.graphics.line(size/2 - 22, size/2 + 10, size/2 - 38, size/2 + 6)
    love.graphics.line(size/2 + 22, size/2 + 10, size/2 + 38, size/2 + 6)
    love.graphics.line(size/2 - 22, size/2 + 14, size/2 - 38, size/2 + 18)
    love.graphics.line(size/2 + 22, size/2 + 14, size/2 + 38, size/2 + 18)

    -- blink overlay (drawn as a dark bar across eyes) — used for pet blinks
    if mood == "blink" then
        love.graphics.setColor(0.10, 0.06, 0.04)
        love.graphics.rectangle("fill", size/2 - 22, size/2 - 8, 44, 4)
    end

    -- "EAT" prompt when sad & hungry — small pixel text above head
    if mood == "sad" then
        love.graphics.setColor(0.95, 0.32, 0.32)
        love.graphics.printf("EAT", 0, 18, size, "center")
    end

    love.graphics.setCanvas()
    return c
end

local function make_icon(kind)
    -- A 32x32 icon for the "meat" / "heart" badge we draw in a corner.
    local size = 32
    local c = love.graphics.newCanvas(size, size)
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)
    if kind == "meat" then
        love.graphics.setColor(0.78, 0.30, 0.30)
        love.graphics.circle("fill", 14, 14, 10)
        love.graphics.setColor(1, 0.95, 0.85)
        love.graphics.circle("fill", 16, 12, 4)
        love.graphics.setColor(0.30, 0.15, 0.10)
        love.graphics.circle("line", 14, 14, 10)
    elseif kind == "heart" then
        love.graphics.setColor(VIS.heart)
        love.graphics.polygon("fill",
            16, 26, 4, 14, 8, 6, 14, 6, 16, 12,
            18, 6, 24, 6, 28, 14)
    end
    love.graphics.setCanvas()
    return c
end

local function pet_sprite()
    local mood
    if PET.hunger <= 3 then mood = "sad"
    elseif PET.eat_anim_t > 0 then mood = "eat"
    elseif (love.timer.getTime() - PET.last_pet) > CFG.idle_sleep then mood = "sleep"
    else mood = "idle" end

    local blink = PET.blink_t > 0
    if mood == "idle" and blink then mood = "blink" end
    return SPR.pet[mood] or SPR.pet.idle
end

-- ---------------------------------------------------------------------------
-- 2. Save / Load (window position, hunger, with offline decay)
-- ---------------------------------------------------------------------------

local function save_state()
    local data = string.format("%d\n%d\n%.0f\n%.0f\n%d\n",
        PET.hunger, PET.affection,
        love.timer.getTime(), PET.last_tick,
        math.floor(PET.x) * 1000 + math.floor(PET.y))
    love.filesystem.write(PET.save_path, data)
end

local function load_state()
    if not love.filesystem.getInfo(PET.save_path) then return end
    local contents = love.filesystem.read(PET.save_path) or ""
    local h, a, saved_t, last_tick, packed = contents:match("(%-?%d+)\n(%-?%d+)\n(%-?%d+%.?%d*)\n(%-?%d+%.?%d*)\n(%-?%d+)")
    if not h then return end
    PET.hunger    = math.max(0, math.min(CFG.max_hunger, tonumber(h) or 10))
    PET.affection = math.max(0, math.min(10, tonumber(a) or 5))
    PET.last_tick = tonumber(last_tick) or love.timer.getTime()

    -- offline hunger decay
    local now   = love.timer.getTime()
    local delta = math.max(0, now - PET.last_tick)
    local ticks = math.floor(delta / CFG.hunger_drain)
    if ticks > 0 then
        PET.hunger = math.max(0, PET.hunger - ticks)
        PET.last_tick = PET.last_tick + ticks * CFG.hunger_drain
    end
end

-- ---------------------------------------------------------------------------
-- 3. Always-on-top (Win FFI, commented out per spec; toggleable at runtime)
-- ---------------------------------------------------------------------------

local AOT = { enabled = false, supported = false }
local function apply_always_on_top(flag)
    -- Windows FFI snippet (intentionally commented — the spec says "already in
    -- the code, commented out"). Toggleable at runtime via Alt+T.
    --[==[
        local ffi = require("ffi")
        ffi.cdef[[
            HWND GetActiveWindow();
            HWND SetWindowPos(HWND, HWND, int, int, int, int, UINT);
        ]]
        local user32 = ffi.load("user32")
        local HWND_TOPMOST = ffi.cast("HWND", -1)
        local SWP_NOMOVE = 0x0002; local SWP_NOSIZE = 0x0001
        local hwnd = user32.GetActiveWindow()
        user32.SetWindowPos(hwnd, flag and HWND_TOPMOST or ffi.cast("HWND", 0),
            0, 0, 0, 0, SWP_NOMOVE + SWP_NOSIZE)
        AOT.supported = true
        --]==]
        AOT.enabled = flag
    end

-- ---------------------------------------------------------------------------
-- 4. Particles
-- ---------------------------------------------------------------------------

local function spawn_crumbs(x, y)
    for _ = 1, 12 do
        table.insert(PET.particles, {
            x = x, y = y,
            vx = (math.random() - 0.5) * 80,
            vy = -math.random() * 60 - 20,
            life = 0.6 + math.random() * 0.3,
            age  = 0,
            size = 2,
            color = {0.78, 0.55, 0.30},
        })
    end
end

local function spawn_hearts(x, y)
    for _ = 1, 5 do
        table.insert(PET.particles, {
            x = x + (math.random() - 0.5) * 20,
            y = y,
            vx = (math.random() - 0.5) * 30,
            vy = -math.random() * 40 - 10,
            life = 0.8, age = 0,
            size = 6,
            color = VIS.heart,
            kind = "heart",
        })
    end
end

local function update_particles(dt)
    local i = 1
    while i <= #PET.particles do
        local p = PET.particles[i]
        p.age = p.age + dt
        if p.age >= p.life then
            table.remove(PET.particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 120 * dt   -- light gravity on crumbs
            i = i + 1
        end
    end
end

local function draw_particles()
    for _, p in ipairs(PET.particles) do
        local a = 1 - p.age / p.life
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
        if p.kind == "heart" then
            love.graphics.circle("fill", p.x, p.y, p.size * 0.5)
        else
            love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
        end
    end
end

-- ---------------------------------------------------------------------------
-- 5. Sound (synthesized blips — no external samples needed)
-- ---------------------------------------------------------------------------

local SFX = {}
local function beep(freq, dur, vol)
    if not love.audio then return end
    local sr = 22050
    local n  = math.floor(sr * dur)
    local data = love.sound.newSoundData(n, sr, 16, 1)
    for i = 0, n - 1 do
        local t = i / sr
        local env = math.min(1, (1 - t / dur) * 4)
        data:setSample(i, math.sin(2 * math.pi * freq * t) * vol * env)
    end
    local src = love.audio.newSource(data)
    src:play()
    table.insert(SFX, src)
end

local function chirp_arpeggio()
    -- happy chirp: C5 -> E5 -> G5
    beep(523.25, 0.07, 0.15)
    love.timer.sleep(0.06)
    beep(659.25, 0.07, 0.15)
    love.timer.sleep(0.06)
    beep(783.99, 0.09, 0.15)
end

local function whine()
    beep(220, 0.18, 0.10)
    love.timer.sleep(0.10)
    beep(196, 0.18, 0.10)
end

local function breathe()
    beep(180 + math.random(40), 0.30, 0.04)
end

-- ---------------------------------------------------------------------------
-- 6. LÖVE callbacks
-- ---------------------------------------------------------------------------

-- Forward declarations: the helper functions below are defined later in the
-- file but referenced from inside these callbacks. Declaring the locals up
-- front lets Lua resolve them as chunk-locals (not globals) at closure
-- creation time, even though their values are filled in below.
local draw_lcd
local pet_action, feed_action

function love.load()
    love.window.setTitle("deskpet")
    load_state()

    -- build sprites once
    SPR.pet = {
        idle  = make_pet_frame({mood = "idle"}),
        blink = make_pet_frame({mood = "blink"}),
        eat   = make_pet_frame({mood = "eat"}),
        sad   = make_pet_frame({mood = "sad"}),
        sleep = make_pet_frame({mood = "sleep"}),
    }
    SPR.meat  = make_icon("meat")
    SPR.heart = make_icon("heart")

    -- place window at last saved coords
    if love.filesystem.getInfo(PET.save_path) then
        local contents = love.filesystem.read(PET.save_path) or ""
        local packed = contents:match("(%-?%d+)\n%-?%d+\n%-?%d+%.?%d*\n%-?%d+%.?%d*\n(%-?%d+)")
        if packed then
            local n = tonumber(packed)
            PET.x = math.floor(n / 1000)
            PET.y = n - PET.x * 1000
            love.window.setPosition(PET.x, PET.y)
        end
    end

    -- hide system menu bar; we want the keychain-toy vibe
    -- (note: love.window.hide is intentionally not used so the user can
    -- re-grab the window; drag-anywhere is the interaction model)
end

function love.update(dt)
    local now = love.timer.getTime()

    -- hunger tick
    if now - PET.last_tick >= CFG.hunger_drain and PET.hunger > 0 then
        PET.hunger = PET.hunger - 1
        PET.last_tick = PET.last_tick + CFG.hunger_drain
        if PET.hunger == 3 then whine() end
    end

    -- affection drift toward lean
    PET.lean = PET.lean + (PET.lean_target or 0 - PET.lean) * math.min(1, dt * 4)
    -- affection decay
    if now - (PET.last_aff_decay or now) >= CFG.aff_decay and PET.affection > 0 then
        PET.affection = math.max(0, PET.affection - 1)
        PET.last_aff_decay = now
    end

    -- blink schedule
    PET.blink_next = PET.blink_next - dt
    if PET.blink_next <= 0 then
        PET.blink_t = CFG.blink_dur
        PET.blink_next = 2 + math.random() * 4
    end
    if PET.blink_t > 0 then PET.blink_t = PET.blink_t - dt end

    -- transient effects
    if PET.shake_t > 0 then PET.shake_t = PET.shake_t - dt end
    if PET.hop_t > 0 then PET.hop_t = PET.hop_t - dt end
    if PET.eat_anim_t > 0 then PET.eat_anim_t = PET.eat_anim_t - dt end

    -- sleep breathing every ~6s while sleeping
    if (now - PET.last_pet) > CFG.idle_sleep then
        if math.floor(now * 2) ~= math.floor((now - dt) * 2) then
            if math.random() < 0.3 then breathe() end
        end
    end

    update_particles(dt)
end

function love.draw()
    -- shake offset
    local sx = 0
    if PET.shake_t > 0 then
        sx = (math.random() - 0.5) * 6 * (PET.shake_t / CFG.shake_dur)
    end

    -- background
    love.graphics.clear(VIS.bg[1], VIS.bg[2], VIS.bg[3])

    -- corner badges
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.draw(SPR.meat,  12, 12)
    love.graphics.draw(SPR.heart, 12, VIS.height - 44)

    -- pet sprite
    local spr = pet_sprite()
    local dx = (VIS.width - spr:getWidth()) / 2 + sx
    local dy = (VIS.height - spr:getHeight()) / 2

    -- hop on pet
    if PET.hop_t > 0 then
        local p = PET.hop_t / CFG.hop_dur
        dy = dy - math.sin(p * math.pi) * 10
    end

    -- affection lean (rotation around belly)
    if PET.lean ~= 0 then
        love.graphics.push()
        love.graphics.translate(VIS.pet_cx, VIS.pet_cy)
        love.graphics.rotate(PET.lean)
        love.graphics.translate(-VIS.pet_cx, -VIS.pet_cy)
        love.graphics.draw(spr, dx, dy)
        love.graphics.pop()
    else
        love.graphics.draw(spr, dx, dy)
    end

    -- LCD belly patch (drawn over body so it sits on the cream patch)
    draw_lcd()

    -- particles
    draw_particles()

    -- ZZZ when sleeping
    if (love.timer.getTime() - PET.last_pet) > CFG.idle_sleep then
        love.graphics.setColor(0.9, 0.9, 1.0, 0.8)
        love.graphics.printf("z z z", VIS.pet_cx - 30, 20, 60, "center")
    end
end

-- ---------------------------------------------------------------------------
-- 7. LCD with countdown + pie sweep
-- ---------------------------------------------------------------------------

function draw_lcd()  -- assigns into the forward-declared local above
    local cx, cy, r = VIS.lcd_cx, VIS.lcd_cy, VIS.lcd_r
    love.graphics.setColor(VIS.lcd_bg)
    love.graphics.circle("fill", cx, cy, r)
    love.graphics.setColor(0.20, 0.10, 0.04)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, r)

    -- pie sweep — full at last tick, empty as we approach next tick
    local elapsed = love.timer.getTime() - PET.last_tick
    local frac    = math.min(1, elapsed / CFG.hunger_drain)
    if PET.hunger > 0 then
        love.graphics.setColor(0.55, 0.40, 0.20, 0.8)
        love.graphics.arc("fill", cx, cy, r - 4,
            -math.pi / 2, -math.pi / 2 + (1 - frac) * 2 * math.pi)
    end

    -- countdown text
    local secs_left = math.max(0, math.ceil(CFG.hunger_drain - elapsed))
    love.graphics.setColor(VIS.lcd_fg)
    love.graphics.printf(tostring(secs_left),
        cx - r, cy - 8, r * 2, "center")

    -- affection under LCD
    love.graphics.setColor(VIS.heart)
    local aff_str = string.rep("v", PET.affection)
    love.graphics.printf(aff_str, cx - r, cy + r - 10, r * 2, "center")
end

-- ---------------------------------------------------------------------------
-- 8. Input — drag, feed, pet, AOT toggle, quit
-- ---------------------------------------------------------------------------

function love.mousepressed(x, y, button)
    local now = love.timer.getTime()

    -- dragging: any button on the body starts a drag
    local body_x, body_y = VIS.pet_cx, VIS.pet_cy
    if (x - body_x)^2 + (y - body_y)^2 <= (VIS.pet_r + 10)^2 then
        if button == 1 then
            -- left click = pet (not drag) — only drag on right click
            pet_action(x, y)
        elseif button == 2 then
            PET.drag_off = { dx = x, dy = y }
            feed_action(x, y)
        end
    else
        -- click outside body: right = feed, left = nothing
        if button == 2 then feed_action(x, y) end
    end
end

function love.mousereleased(x, y, button)
    if button == 2 then PET.drag_off = nil end
end

function love.mousemoved(x, y, dx, dy)
    if PET.drag_off then
        local px, py = love.window.getPosition()
        love.window.setPosition(px + dx, py + dy)
        PET.x, PET.y = love.window.getPosition()
    end

    -- affection-target lean: bias toward cursor when happy
    if PET.affection >= 6 then
        PET.lean_target = (x - VIS.pet_cx) / 200
    else
        PET.lean_target = 0
    end
end

function love.keypressed(key)
    if key == "escape" then
        save_state()
        love.event.quit()
    elseif key == "f" then
        feed_action(0, 0)
    elseif key == "p" then
        pet_action(VIS.pet_cx, VIS.pet_cy)
    elseif key == "t" then
        -- Alt+T toggles always-on-top
        apply_always_on_top(not AOT.enabled)
    end
end

function love.quit()
    save_state()
end

-- ---------------------------------------------------------------------------
-- 9. Actions
-- ---------------------------------------------------------------------------

local last_chirp = 0
function pet_action(x, y)
    PET.hop_t = CFG.hop_dur
    PET.last_pet = love.timer.getTime()
    PET.last_action = PET.last_pet
    PET.affection = math.min(10, PET.affection + CFG.pet_aff_gain)
    spawn_hearts(x, y)
    if love.timer.getTime() - last_chirp > 0.4 then
        chirp_arpeggio()
        last_chirp = love.timer.getTime()
    end
end

function feed_action(x, y)
    if PET.hunger >= CFG.max_hunger then return end
    PET.hunger = math.min(CFG.max_hunger, PET.hunger + CFG.feed_gain)
    PET.last_tick = love.timer.getTime()
    PET.eat_anim_t = CFG.eat_dur
    PET.shake_t = CFG.shake_dur
    PET.last_action = PET.last_tick
    spawn_crumbs(x or VIS.pet_cx, y or VIS.pet_cy)
    beep(440, 0.06, 0.20)
end