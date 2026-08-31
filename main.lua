---------------------------------------------------------------
-- deskpet v0.4 — "pet IS the device" (LÖVE 11.x)
-- Chunky pixel pet with a round belly-LCD: countdown + pie sweep.
-- Matches reference aesthetic: navy bg, tan body, cream belly,
-- brown LCD circle, pixel font. No visible buttons.
-- Controls: left-click pet = PET · right-click = FEED
--           drag body = move · Esc = quit
-- Optional art override: sprites/pet.png (2 cols x 4 rows grid)
---------------------------------------------------------------

local W, H = 240, 280
local SETTINGS = "settings.txt"

-- tuning
local HUNGER_INTERVAL = 30    -- real seconds per -1 hunger (the LCD countdown)
local SLEEP_AFTER     = 300   -- idle seconds before Zzz

-- state
local hunger, hungerTimer = 8, 0
local anim        = { name = "idle", t = 0, dur = 0 }
local blinkTimer  = love.math.random(3, 8)
local blinking    = 0
local lastTouch   = 0
local sleeping    = false
local whined      = false
local dragging, dragMoved = false, 0
local grabX, grabY = 0, 0
local petScale    = 2

-- layout (pet art is a 96x96 grid, drawn at petScale)
local petPX, petPY = 24, 24                    -- 96*2 = 192px, centered
local iconPet  = { x = 24,  y = 240, w = 28, h = 28 }   -- heart = pet
local iconFeed = { x = 188, y = 240, w = 28, h = 28 }   -- meat = feed

-- palette (from your refs)
local PAL = {
    outline = { 0.10, 0.11, 0.17 },   -- dark navy silhouette
    body    = { 0.89, 0.64, 0.39 },   -- tan fur
    shade   = { 0.76, 0.51, 0.29 },   -- fur shadow
    cream   = { 0.97, 0.92, 0.83 },   -- belly patch
    lcd     = { 0.40, 0.26, 0.14 },   -- brown LCD circle
    lcdPie  = { 0.64, 0.44, 0.20 },   -- timer sweep wedge
    pink    = { 0.94, 0.63, 0.66 },   -- cheeks, hearts, inner ear
    white   = { 0.98, 0.96, 0.90 },   -- LCD text
    dim     = { 0.75, 0.68, 0.58 },   -- tiny labels
    pipOff  = { 0.23, 0.24, 0.32 },   -- empty hunger pips
}

---------------------------------------------------------------
-- 3x5 pixel font + icons
---------------------------------------------------------------
local FONT = {
    ["0"] = { "111","101","101","101","111" },
    ["1"] = { "010","110","010","010","111" },
    ["2"] = { "111","001","111","100","111" },
    ["3"] = { "111","001","111","001","111" },
    ["4"] = { "101","101","111","001","001" },
    ["5"] = { "111","100","111","001","111" },
    ["6"] = { "111","100","111","101","111" },
    ["7"] = { "111","001","010","010","010" },
    ["8"] = { "111","101","111","101","111" },
    ["9"] = { "111","101","111","001","111" },
    [":"] = { "0","1","0","1","0" },
    A = { "010","101","111","101","101" },
    D = { "110","101","101","101","110" },
    E = { "111","100","111","100","111" },
    F = { "111","100","111","100","100" },
    O = { "111","101","101","101","111" },
    T = { "111","010","010","010","010" },
    Z = { "111","001","010","100","111" },
}
local HEART = { "01010","11111","11111","01110","00100" }
local MEAT  = {
    "..mmmm..",
    ".mmmmmm.",
    "mmmmmmmm",
    "mmmmmmmm",
    ".mmmmmm.",
    "..mmbb..",
    "...mb...",
    "...bb...",
}

local function pxMap(map, x, y, s, col)
    love.graphics.setColor(col)
    for r = 1, #map do
        local row = map[r]
        for c = 1, #row do
            local ch = row:sub(c, c)
            if ch ~= "." and ch ~= "0" and ch ~= " " then
                if ch == "b" then love.graphics.setColor(PAL.cream) end
                love.graphics.rectangle("fill", x + (c - 1) * s, y + (r - 1) * s, s, s)
                love.graphics.setColor(col)
            end
        end
    end
end

local function textW(str, s)
    local w = 0
    for i = 1, #str do
        local g = FONT[str:sub(i, i)]
        w = w + (g and #g[1] or 2) + 1
    end
    return (w - 1) * s
end

local function pxText(str, x, y, s, col)
    local cx = x
    for i = 1, #str do
        local g = FONT[str:sub(i, i)]
        if g then
            pxMap(g, cx, y, s, col)
            cx = cx + (#g[1] + 1) * s
        else
            cx = cx + 3 * s
        end
    end
end

local function pxTextCentered(str, cx, y, s, col)
    pxText(str, cx - textW(str, s) / 2, y, s, col)
end

---------------------------------------------------------------
-- placeholder pet (96x96 chunky pixel cat, generated in code)
---------------------------------------------------------------
local function makeFrame(kind)
    local S = 96
    local id = love.image.newImageData(S, S)
    local O, T, SH, P, D = PAL.outline, PAL.body, PAL.shade, PAL.pink, PAL.outline

    local function px(x, y, c)
        if x >= 0 and x < S and y >= 0 and y < S then
            id:setPixel(x, y, c[1], c[2], c[3], 1)
        end
    end
    local function disc(cx, cy, r, c)
        for y = math.floor(cy - r), math.ceil(cy + r) do
            for x = math.floor(cx - r), math.ceil(cx + r) do
                local dx, dy = x - cx, y - cy
                if dx * dx + dy * dy <= r * r then px(x, y, c) end
            end
        end
    end
    local function rect(x0, y0, x1, y1, c)
        for y = y0, y1 do for x = x0, x1 do px(x, y, c) end end
    end
    local function ear(cx, y0, y1, hl, hr, c)
        for y = y0, y1 do
            local t = (y - y0) / (y1 - y0)
            for x = math.floor(cx - hl * t), math.ceil(cx + hr * t) do px(x, y, c) end
        end
    end
    local function inRRect(x, y, x0, y0, x1, y1, r)
        if x < x0 or x > x1 or y < y0 or y > y1 then return false end
        local dx = math.max(x0 + r - x, x - (x1 - r), 0)
        local dy = math.max(y0 + r - y, y - (y1 - r), 0)
        return dx * dx + dy * dy <= r * r
    end

    -- feet (behind body)
    disc(30, 92, 8, O) disc(66, 92, 8, O)
    disc(30, 92, 6, T) disc(66, 92, 6, T)
    -- pointy ears: outline / tan / pink inner
    ear(27, 2, 24, 15, 11, O)  ear(69, 2, 24, 11, 15, O)
    ear(27, 6, 23, 11, 8, T)   ear(69, 6, 23, 8, 11, T)
    ear(27, 11, 21, 6, 4, P)   ear(69, 11, 21, 4, 6, P)
    -- barrel body + outline, darker toward the bottom
    for y = 0, S - 1 do for x = 0, S - 1 do
        if inRRect(x, y, 8, 14, 88, 94, 26) then px(x, y, O) end
    end end
    for y = 0, S - 1 do for x = 0, S - 1 do
        if inRRect(x, y, 11, 17, 85, 91, 23) then
            px(x, y, (y >= 82) and SH or T)
        end
    end end
    -- belly patch + brown LCD circle with navy ring
    disc(48, 63, 27, PAL.cream)
    disc(48, 63, 21, O)
    disc(48, 63, 19, PAL.lcd)
    -- cheeks + whiskers
    rect(14, 41, 21, 46, P)  rect(75, 41, 82, 46, P)
    rect(4, 42, 12, 43, D)   rect(4, 48, 12, 49, D)
    rect(84, 42, 92, 43, D)  rect(84, 48, 92, 49, D)
    -- eyes
    if kind == "blink" or kind == "sleep" then
        rect(24, 33, 34, 36, D) rect(62, 33, 72, 36, D)
    elseif kind == "happy" then
        for i = 0, 5 do                          -- ^^ eyes
            local ly = 36 - math.floor(2.4 * math.sin(math.pi * i / 5))
            rect(24 + i, ly, 25 + i, ly + 1, D)
            rect(67 + i, ly, 68 + i, ly + 1, D)
        end
    else
        rect(24, 28, 34, 38, D) rect(62, 28, 72, 38, D)
        rect(30, 30, 32, 32, PAL.white) rect(68, 30, 70, 32, PAL.white)
    end
    -- nose + mouth
    rect(46, 41, 49, 43, D)
    if kind == "eat" then
        disc(48, 48, 5, D)
        rect(46, 50, 49, 52, P)                  -- tongue
    elseif kind == "sad" then
        for i = 0, 8 do                          -- frown
            local dy = (i % 2 == 0) and 1 or 0
            px(44 + i, 46 + dy, D) px(44 + i, 47 + dy, D)
        end
    elseif kind == "happy" then
        disc(48, 47, 3, D)
    else
        for i = 0, 8 do                          -- little "w" mouth
            local dy = (i % 2 == 0) and 0 or 1
            px(44 + i, 45 + dy, D) px(44 + i, 46 + dy, D)
        end
    end

    local img = love.graphics.newImage(id)
    img:setFilter("nearest", "nearest")
    return img
end

local Frames = {}

---------------------------------------------------------------
-- sprite loading: sprites/pet.png with procedural fallback
-- Sheet: square cells, 2 columns x 4 rows (any cell size):
--   (0,0) idle   (1,0) blink
--   (0,1) eat1   (1,1) eat2
--   (0,2) happy1 (1,2) happy2
--   (0,3) sad    (1,3) sleep
-- IMPORTANT for the LCD overlay to line up: draw your pet's belly
-- circle centered at 50% / 65.6% of the cell, radius ~20% of cell
-- (that's the (48,63) r19 spot on the 96x96 placeholder grid).
---------------------------------------------------------------
local FRAME_PX = 96

local function sheetFrame(sheet, col, row, fs)
    local q = love.graphics.newQuad(col * fs, row * fs, fs, fs, sheet:getDimensions())
    local c = love.graphics.newCanvas(fs, fs)
    c:setFilter("nearest", "nearest")
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(sheet, q, 0, 0)
    love.graphics.setCanvas()
    return c
end

local function loadFrames()
    local path = "sprites/pet.png"
    if love.filesystem.getInfo(path) then
        local sheet = love.graphics.newImage(path)
        sheet:setFilter("nearest", "nearest")
        local fs   = math.floor(sheet:getHeight() / 4)
        local cols = math.floor(sheet:getWidth() / fs)
        assert(fs > 0 and cols >= 1,
            "pet.png must be a grid with 4 rows (see layout comment)")
        FRAME_PX = fs
        local function f(col, row) return sheetFrame(sheet, col, row, fs) end
        Frames.idle  = f(0, 0)
        Frames.blink = (cols > 1) and f(1, 0) or f(0, 0)
        Frames.eat   = { f(0, 1) }
        Frames.happy = { f(0, 2) }
        if cols > 1 then
            Frames.eat[2]   = f(1, 1)
            Frames.happy[2] = f(1, 2)
        end
        Frames.sad   = f(0, 3)
        Frames.sleep = (cols > 1) and f(1, 3) or f(0, 3)
    else
        FRAME_PX = 96
        Frames.idle  = makeFrame("idle")
        Frames.blink = makeFrame("blink")
        Frames.eat   = { makeFrame("eat") }
        Frames.happy = { makeFrame("happy") }
        Frames.sad   = makeFrame("sad")
        Frames.sleep = makeFrame("sleep")
    end
end

---------------------------------------------------------------
-- synthesized blips
---------------------------------------------------------------
local function makeBlip(freq, dur, vol)
    local rate = 22050
    local sd = love.sound.newSoundData(math.floor(rate * dur), rate, 16, 1)
    for i = 0, sd:getSampleCount() - 1 do
        local t = i / rate
        sd:setSample(i, math.sin(2 * math.pi * freq * t) * (1 - t / dur) * (vol or 0.35))
    end
    return love.audio.newSource(sd)
end
local sfxFeed, sfxPet, sfxWhine

---------------------------------------------------------------
-- persistence (position + hunger, with offline decay)
---------------------------------------------------------------
local function loadSettings()
    local s = love.filesystem.read(SETTINGS)
    if not s then return nil end
    local x, y, h, ts = s:match("(-?%d+),(-?%d+),(%d+),(%d+)")
    if not x then return nil end
    return tonumber(x), tonumber(y), tonumber(h), tonumber(ts)
end

---------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(0.15, 0.16, 0.23)   -- navy, like refs

    loadFrames()
    petScale = 192 / FRAME_PX

    sfxFeed  = makeBlip(520, 0.12)
    sfxPet   = makeBlip(880, 0.15)
    sfxWhine = makeBlip(300, 0.25, 0.25)

    local flags = { borderless = true, resizable = false, vsync = 1, highdpi = false }
    local sx, sy, sh, sts = loadSettings()
    if sx then
        flags.x, flags.y = sx, sy
        local elapsed = os.time() - sts
        hunger = math.max(0, sh - math.floor(elapsed / HUNGER_INTERVAL))
        hungerTimer = elapsed % HUNGER_INTERVAL
    else
        local dw, dh = love.window.getDesktopDimensions()
        flags.x = dw - W - 20
        flags.y = dh - H - 40
    end
    love.window.setMode(W, H, flags)
    love.window.setTitle("Pet")

    lastTouch = love.timer.getTime()
end

local function playAnim(name, dur)
    anim.name, anim.t, anim.dur = name, 0, dur
end

local function doFeed()
    lastTouch = love.timer.getTime()
    sleeping = false
    if hunger < 10 then
        hunger = math.min(10, hunger + 2)
        whined = false
        playAnim("eat", 1.2)
        sfxFeed:stop(); sfxFeed:play()
    else
        playAnim("happy", 0.6)
    end
end

local function doPet()
    lastTouch = love.timer.getTime()
    sleeping = false
    playAnim("happy", 0.9)
    sfxPet:stop(); sfxPet:play()
end

function love.update(dt)
    local mx, my = love.mouse.getPosition()
    local hovering = mx >= 0 and my >= 0 and mx < W and my < H

    if dragging then
        local wx, wy = love.window.getPosition()
        love.window.setPosition(wx + mx - grabX, wy + my - grabY)
    end

    hungerTimer = hungerTimer + dt
    while hungerTimer >= HUNGER_INTERVAL do
        hungerTimer = hungerTimer - HUNGER_INTERVAL
        hunger = math.max(0, hunger - 1)
        if hunger <= 3 and not whined then
            whined = true
            sfxWhine:stop(); sfxWhine:play()
        end
    end

    local adt = math.min(dt, 0.1)
    if anim.name ~= "idle" then
        anim.t = anim.t + adt
        if anim.t >= anim.dur then anim.name = "idle" end
    else
        blinkTimer = blinkTimer - adt
        if blinkTimer <= 0 then
            blinking = 0.15
            blinkTimer = love.math.random(3, 8)
        end
    end
    if blinking > 0 then blinking = blinking - adt end

    if not sleeping and anim.name == "idle"
       and love.timer.getTime() - lastTouch > SLEEP_AFTER then
        sleeping = true
    end

    if not hovering and not dragging and anim.name == "idle" then
        love.timer.sleep(0.05)
    end
end

---------------------------------------------------------------
-- drawing
---------------------------------------------------------------
local function inRect(x, y, r)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

local function drawHungerPips()
    local pipW, gap = 8, 3
    local total = 10 * pipW + 9 * gap
    local x0, y0 = (W - total) / 2, 8
    for i = 1, 10 do
        love.graphics.setColor(i <= hunger and PAL.shade or PAL.pipOff)
        love.graphics.rectangle("fill", x0 + (i - 1) * (pipW + gap), y0, pipW, 5)
    end
end

local function drawLCD()
    -- LCD position in window coords (tracks whatever pet art is loaded)
    local cx = petPX + 48 * petScale
    local cy = petPY + 63 * petScale
    local r  = 16 * petScale
    local now = love.timer.getTime()

    if sleeping then
        pxTextCentered("ZZZ", cx, cy - 10, 4, PAL.dim)
    elseif anim.name == "eat" then
        local t = math.min(1, anim.t / 0.9)      -- food drops to the mouth
        pxMap(MEAT, cx - 12, cy - 30 + t * 24, 3, PAL.shade)
    elseif anim.name == "happy" then
        local b = math.abs(math.sin(now * 10)) * 4
        pxMap(HEART, cx - 17, cy - 8 - b, 3, PAL.pink)
        pxMap(HEART, cx + 3,  cy - 8 - (4 - b), 3, PAL.pink)
    elseif hunger <= 3 then
        if (now * 1.5) % 1 < 0.6 then
            pxTextCentered("EAT", cx, cy - 12, 5, PAL.pink)
        end
    else
        -- countdown to next hunger tick + pie sweep (the ref look)
        local frac = hungerTimer / HUNGER_INTERVAL
        love.graphics.setColor(PAL.lcdPie)
        love.graphics.arc("fill", "pie", cx, cy, r,
            -math.pi / 2, -math.pi / 2 + frac * 2 * math.pi)
        pxTextCentered("FOOD", cx, cy - 20, 2, PAL.dim)
        local rem = math.max(0, HUNGER_INTERVAL - hungerTimer)
        pxTextCentered(string.format("%02d:%02d",
            math.floor(rem / 60), math.floor(rem % 60)), cx, cy - 7, 3, PAL.white)
    end
end

local function drawIcons()
    local mx, my = love.mouse.getPosition()
    local hP = inRect(mx, my, iconPet)
    local hF = inRect(mx, my, iconFeed)
    pxMap(HEART, iconPet.x + 6, iconPet.y + 6, 3, hP and PAL.pink or PAL.dim)
    pxMap(MEAT, iconFeed.x + 2, iconFeed.y + 2, 3, hF and PAL.shade or PAL.pipOff)
end

function love.draw()
    -- pet
    local f
    if sleeping then f = Frames.sleep
    elseif anim.name == "eat" then
        f = Frames.eat[1 + math.floor(anim.t / 0.15) % #Frames.eat]
    elseif anim.name == "happy" then
        f = Frames.happy[1 + math.floor(anim.t / 0.15) % #Frames.happy]
    elseif blinking > 0 then f = Frames.blink
    elseif hunger <= 3 then f = Frames.sad
    else f = Frames.idle end
    local bounce = (anim.name == "happy") and -math.abs(math.sin(anim.t * 12)) * 6 or 0
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(f, petPX, petPY + bounce, 0, petScale, petScale)

    drawLCD()
    drawHungerPips()
    drawIcons()
end

---------------------------------------------------------------
-- input
---------------------------------------------------------------
function love.mousepressed(x, y, button)
    if button == 2 then doFeed() return end       -- right-click = feed
    if button ~= 1 then return end
    if inRect(x, y, iconFeed) then doFeed() return end
    if inRect(x, y, iconPet)  then doPet()  return end
    dragging, dragMoved = true, 0
    grabX, grabY = x, y
end

function love.mousemoved(x, y, dx, dy)
    if dragging then dragMoved = dragMoved + math.abs(dx) + math.abs(dy) end
end

function love.mousereleased(x, y, button)
    if button ~= 1 then return end
    -- click (not drag) on the pet body = pet it
    if dragging and dragMoved < 5
       and x >= petPX and x < petPX + 192
       and y >= petPY and y < petPY + 192 then
        doPet()
    end
    dragging = false
end

function love.keypressed(key)
    if key == "escape" or key == "q" then love.event.quit() end
    if key == "f" then doFeed() end
end

function love.quit()
    local wx, wy = love.window.getPosition()
    love.filesystem.write(SETTINGS,
        table.concat({ wx, wy, hunger, os.time() }, ","))
end