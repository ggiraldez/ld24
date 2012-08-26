require('input')
require('gfx')
game = {}

local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
local debug = true

-- player = nil
-- critters = {}
-- items = {}

local segmentTypes = { 'life', 'speed', 'attack' }
local segmentSizes = {
    head = {
        life = { 10, 14, 18, 22, 28, 32 },
        speed = { 10, 14, 18, 22, 28, 32 },
        attack = { 22, 22, 28, 28, 32, 32 }
    },
    body = {
        life = { 10, 14, 18, 22, 28, 32 },
        speed = { 10, 14, 18, 22, 28, 32 },
        attack = { 10, 14, 18, 22, 28, 32 },
    },
    tail = {
        life = { 10, 14, 18, 22, 28, 32 },
        speed = { 10, 14, 18, 22, 28, 32 },
        attack = { 22, 22, 28, 28, 32, 32 }
    }
}

local itemTypes = { 'food', 'energy', 'life', 'speed', 'attack' }

local zones = {}

local function computeZones()
    local inner = 0
    local outer = 700
    local delta = 500
    local inc = 1.1
    for lvl = 1,50 do
        table.insert(zones, {
            inner=inner,
            outer=outer
        })
        inner = outer
        outer = outer + delta
        delta = delta * inc
    end
end
computeZones()

--
-- Critters code
--

-- creates a level 1 critter of the given type stype at position x,y
local function createCritter(x, y, stype)
    local angle = math.random()*2*math.pi
    local level = 1
    local c = {
        x = x, y = y,           -- position (of the first segment)
        v = 0, va = angle,      -- velocity (value, angle)
        a = 0, aa = 0,          -- acceleration (value, angle)
        level = level,          -- overall level
        max_v = 4,              -- maximum velocity
        friction = 0.02,        -- friction coefficient
        max_life = 10,          -- total life
        life = 10,              -- current life
        max_energy = 10,        -- total energy
        energy = 10,            -- current energy
        attack = 0,             -- attack strength
        color = { 255, 255, 255 },
        -- segments
        segs = {{ 
            x=x, y=y,                       -- position
            angle=angle,                    -- angle
            stype=stype,                    -- type
            level=level,                    -- level
            size=segmentSizes.head[stype][level]/2  -- size
        }}
    }
    return c
end

local function updateStats(c)
    -- recalculate max life, max speed, max energý and friction for the critter
    local l, s, a = 0,0,0
    local cl, cs, ca = 0,0,0
    local max_life, max_energy, attack, friction, max_speed = 0,0,0,0,0
    
    max_life = #(c.segs)
    max_energy = #(c.segs)
    friction = 2

    for i = 1, #(c.segs) do
        local seg = c.segs[i]
        if seg.stype == 'life' then
            l = l + seg.level
            cl = cl + 1
            max_life = max_life + 2*seg.level
            max_energy = max_energy + 1
            friction = friction - 1

        elseif seg.stype == 'speed' then
            s = s + seg.level
            cs = cs + 1
            friction = friction + seg.level
        
        elseif seg.stype == 'attack' then
            a = a + seg.level
            ca = ca + 1
            if i == 1 then
                attack = attack + 1.5 * seg.level
            elseif i == #(c.segs) then
                attack = attack + seg.level
            else
                attack = attack + 0.5 * seg.level
            end
            max_energy = max_energy + seg.level
        end
    end

    if c.segs[1].stype == 'attack' then
        c.attack = attack
    else
        c.attack = 0
    end
    c.max_life = max_life
    c.max_energy = max_energy

    max_speed = 4 + s - cl
    max_speed = math.max(0.5, math.min(10, max_speed))
    c.max_v = max_speed

    friction = math.min(1, math.max(20, friction))
    c.friction = friction / 100

    local total = l + s + a
    c.color = { 
        math.min(255, 80*l/total+192),
        math.min(255, 80*s/total+192), 
        math.min(255, 80*a/total+192)
    }
end

-- adds a segment of the given type at level 1 to the critter c
local function addSegment(c, stype)
    local last = c.segs[#(c.segs)]
    local x = last.x
    local y = last.y
    local angle = c.va
    local size = segmentSizes.tail[stype][1]/2
    if #(c.segs) > 1 then
        last.size = segmentSizes.body[last.stype][last.level]/2
    end
    x = x - (size + last.size) * math.cos(angle)
    y = y - (size + last.size) * math.sin(angle)
    table.insert(c.segs, {
        x=x, y=y,
        angle=angle,
        stype=stype,
        level=1,
        size=size
    })
end

local function updateSegments(c)
    -- update segments
    local ss = c.segs
    
    -- first segment
    ss[1].x = c.x
    ss[1].y = c.y
    ss[1].angle = c.va

    -- other segments
    for i = 2, #ss do
        local last = ss[i-1]
        local s = ss[i]
        local dx = s.x - last.x
        local dy = s.y - last.y
        if dx == 0 and dy == 0 then
            dx = math.cos(c.va)
            dy = math.sin(c.va)
        else
            local d = math.sqrt(dx*dx + dy*dy)
            dx = dx / d
            dy = dy / d
        end
        s.x = last.x + (s.size + last.size) * dx
        s.y = last.y + (s.size + last.size) * dy
        s.angle = math.atan2(dy, dx)
    end
end

local function evolveSegment(c, num)
    if num < 1 or num > #(c.segs) then
        print("invalid segment")
        return
    end
    local s = c.segs[num]
    if s.level == 6 then
        print("segment cannot evolve further")
        return
    end
    s.level = s.level + 1
    if num == 1 then
        s.size = segmentSizes.head[s.stype][s.level]/2
    elseif num == #(c.segs) then
        s.size = segmentSizes.tail[s.stype][s.level]/2
    else
        s.size = segmentSizes.body[s.stype][s.level]/2
    end
    c.level = c.level + 1
    updateSegments(c)
end

local function updateCritter(c)
    local vx, vy = 0,0
    local ax, ay = 0,0
    local v, va = c.v, c.va
    local a, aa = c.a, c.aa

    if a > 0 then
        ax = a * math.cos(aa)
        ay = a * math.sin(aa)
    end

    if v > 0 then
        -- add friction
        local f = v * c.friction
        local fa = va
        ax = ax - f * math.cos(fa)
        ay = ay - f * math.sin(fa)
        a = math.sqrt(ax * ax + ay * ay)
    end

    if a > 0 then
        vx = v * math.cos(va)
        vy = v * math.sin(va)

        vx = vx + ax
        vy = vy + ay
        v = math.min(c.max_v, math.sqrt(vx * vx + vy * vy))
        va = math.atan2(vy, vx)
    end

    c.v = v
    c.va = va

    if v > 0 then
        vx = v * math.cos(va)
        vy = v * math.sin(va)
        c.x = c.x + vx
        c.y = c.y + vy

        updateSegments(c)
    end
end


--
-- Player code
-- 

local function processPlayerInput()
    local a = 0.2
    local ax, ay = 0, 0
    if input.up then ay = ay - 1 end
    if input.down then ay = ay + 1 end
    if input.left then ax = ax - 1 end
    if input.right then ax = ax + 1 end
    
    if love.mouse.isDown('l') then
        local mx, my = love.mouse.getX(), love.mouse.getY()
        ax = mx - sw/2
        ay = my - sh/2
        local m = math.sqrt(mx*mx + my*my)
        a = math.min(a, m/sw)
    end

    if ax ~= 0 or ay ~= 0 then
        player.a = a
        player.aa = math.atan2(ay, ax)
    else
        player.a = 0
    end
end



--
-- AI code
-- 

local function aiCritter(c)
    if c.tic == nil then
        c.tic = globalTic
    end

    -- at most one action every ~1/4 sec
    if globalTic > c.tic + math.random(10,20) then
        c.tic = globalTic

        if math.random(100) < 30 then
            local d = math.sqrt(c.x * c.x + c.y * c.y)

            c.a = 0.5
            c.count = 10

            local z = zones[c.level]

            if d < z.inner then
                c.aa = math.atan2(c.y, c.x) + (math.random()-0.5) * math.pi*3/4
            elseif d > z.outer then
                c.aa = math.atan2(-c.y, -c.x) + (math.random()-0.5) * math.pi*3/4
            else
                c.aa = math.random() * 2 * math.pi
            end
        end
    end

    if not c.count or c.count == 0 then
        c.a = 0
    else
        c.count = c.count - 1
    end
end



--
-- Items code
--

local function createItem(x, y, itype)
    return {
        x=x, y=y, itype=itype, 
        angle=math.random()*2*math.pi,
        spin=(math.random()-0.5)*math.pi/50,
        v=math.random()*.2,
        va=math.random()*2*math.pi
    }
end

local function updateItem(it)
    it.angle = (it.angle + it.spin) % (2*math.pi)
    it.x = it.x + it.v * math.cos(it.va)
    it.y = it.y + it.v * math.sin(it.va)
end


--
-- General game loop code
--

function game.init()
    game.restart()
end

function game.restart()
    globalTic = 0

    -- create player critter
    player = createCritter(0, 0, 'attack')
    addSegment(player, 'life')
    updateStats(player)
    
    -- populate critters
    critters = {}
    for i = 1, 100 do
        local c
        local stype = segmentTypes[math.random(#segmentTypes)]
        local level = math.random(5)
        if stype == 'attack' then
            level = math.max(level, 2)
        end
                
        -- FIXME: these should be calculated according to critter level
        local z = zones[level]
        local angle = math.random() * 2 * math.pi
        local d = math.random(z.inner, z.outer)
        local x = d * math.cos(angle)
        local y = d * math.sin(angle)
        
        c = createCritter(x, y, stype)
        while level > 1 do
            addSegment(c, segmentTypes[math.random(#segmentTypes)])
            level = level - 1
            for i = 1, math.min(level, #(c.segs)-1) do
                evolveSegment(c, i)
            end
            level = level - i
        end
        updateStats(c)
        table.insert(critters, c)
    end

    -- populate items
    items = {}
    for i = 1, 50 do
        local it = itemTypes[math.random(2)]
        local x = (math.random()-0.5) * 2000
        local y = (math.random()-0.5) * 2000
        table.insert(items, createItem(x, y, it))
    end
end

function game.tic()
    globalTic = globalTic + 1
    input.tic()

    processPlayerInput()

    updateCritter(player)
    for i = 1, #critters do
        aiCritter(critters[i])
        updateCritter(critters[i])
    end

    for i = 1, #items do
        updateItem(items[i])
    end
end

function game.toggleDebug()
    debug = not debug
end



--
-- Render code
--

local function renderBackground()
    love.graphics.circle('line', 0, 0, 50)
end

local function renderCritter(c)
    local img = gfx.images.segments
    local qs = gfx.quads
    local ss = c.segs
    local s = ss[1]
    love.graphics.setColor(c.color)
    love.graphics.drawq(img, qs.head[s.stype][s.level], s.x, s.y, (s.angle+math.pi), 1, 1, 16, 16)
    for i = 2, #ss-1 do
        s = ss[i]
        love.graphics.drawq(img, qs.body[s.stype][s.level], s.x, s.y, (s.angle), 1, 1, 16, 16)
    end
    if #ss > 1 then
        s = ss[#ss]
        love.graphics.drawq(img, qs.tail[s.stype][s.level], s.x, s.y, (s.angle), 1, 1, 16, 16)
    end
end

local function renderItems()
    local img = gfx.images.items
    local qs = gfx.quads.items
    for i = 1, #items do
        local it = items[i]
        love.graphics.drawq(img, qs[it.itype], it.x, it.y, it.angle, 1, 1, 8, 8)
    end
end

function game.render()
    local d = math.sqrt(player.x*player.x + player.y*player.y)
    local v = d/5000
    local c = math.max(0, 128 * (1-v))
    love.graphics.setBackgroundColor(c,c,c)
    love.graphics.clear()

    love.graphics.push()
    love.graphics.translate(sw/2 - player.x, sh/2 - player.y)
    
    love.graphics.setColor(255,255,255)
    renderBackground()
    renderItems()

    renderCritter(player)
    for i = 1, #critters do
        renderCritter(critters[i])
    end

    love.graphics.setColor(255,255,255)

    love.graphics.pop()

    if debug then
        local zone = 1
        for z = 1,#zones do
            if d < zones[z].outer and d > zones[z].inner then
                zone = z
                break
            end
        end
        love.graphics.print("d=" .. math.ceil(d) .. ", zone: " .. zone, sw-200,0)
    end
end

return game

