require('input')
require('gfx')
game = {}

local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
local screenSize = math.max(sw, sh)
local farThreshold = 3 * screenSize
local debug = true

-- player = nil
-- critters = {}
-- items = {}
-- segments = {}

--
-- Constants
--

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

local shelters = {
    { x=0, y=0, size=50 }
}


-- 
-- Zones
--

local zones = {}

local function computeZones()
    local inner = 0
    local outer = 700
    local delta = 500
    local inc = 1.1
    for lvl = 1,100 do
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

local function zoneFromDistance(d)
    local zone = #zones
    for z = 1,#zones do
        if d < zones[z].outer and d >= zones[z].inner then
            zone = z
            break
        end
    end
    return zone
end

local function zoneFromCoordinates(x, y)
    return zoneFromDistance(math.sqrt(x*x + y*y))
end

local function distanceToPlayer(c)
    local dx = c.x - player.x
    local dy = c.y - player.y
    return math.sqrt(dx*dx + dy*dy)
end

local function distance2ToPlayer(c)
    local dx = c.x - player.x
    local dy = c.y - player.y
    return dx*dx + dy*dy
end

local function tooFar(c)
    if distance2ToPlayer(c) > farThreshold*farThreshold then
        return true
    else
        return false
    end
end

local function randomCoordinates(hidden)
    local span = 0.75 * farThreshold
    local x = (math.random()-0.5) * span
    local y = (math.random()-0.5) * span
    if hidden then
        -- if hidden requested, make sure the coordinates don't fall within currently screen coordinates
        if math.abs(x) < sw/2 then
            x = x + sw/2 * x/math.abs(x)
        end
        if math.abs(y) < sh/2 then
            y = y + sh/2 * y/math.abs(y)
        end
    end
    y = y + player.y
    x = x + player.x
    return x, y
end

local function onScreen(x, y)
    local border = 60
    if x > player.x - sw/2 - border and x < player.x + sw/2 + border and
        y > player.y - sh/2 - border and y < player.y + sh/2 + border then
        return true
    else
        return false
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

local function createRandomItem(hidden)
    local itype
    if math.random(10) > 4 then
        itype = 'food'
    else
        itype = 'energy'
    end
    local x, y = randomCoordinates(hidden)
    return createItem(x, y, itype)
end

local function updateItem(it)
    it.angle = (it.angle + it.spin) % (2*math.pi)
    it.x = it.x + it.v * math.cos(it.va)
    it.y = it.y + it.v * math.sin(it.va)
end


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
        zone = 1,               -- zone the critter lives in
        max_v = 4,              -- maximum velocity
        friction = 0.02,        -- friction coefficient
        max_life = 10,          -- total life
        life = 0,              -- current life
        max_energy = 10,        -- total energy
        energy = 10,            -- current energy
        attack = 0,             -- attack strength
        dead = false,           -- is it dead yet?
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
            max_life = max_life + 4*seg.level
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
    max_speed = math.max(1.5, math.min(10, max_speed))
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

    -- life decay
    c.life = c.life - c.max_life / (4 * 60 * 60)
    if c.life <= 0 then
        c.life = 0
        c.dead = true
    end
end

local function critterDied(c)
    -- spawn segments
    print("Critter died")
    for i = 1, #(c.segs) do
        local stype = c.segs[i].stype
        local x = c.x + (math.random()-0.5) * 4
        local y = c.y + (math.random()-0.5) * 4
        local s = createItem(x, y, stype)
        s.ttl = math.random(3)*60*60
        table.insert(segments, s)
    end
end


--
-- Player code
-- 

local function createPlayer()
    local player = createCritter(0, 0, 'attack')
    addSegment(player, 'life')
    updateStats(player)
    player.life = player.max_life
    player.energy = player.max_energy
    return player
end

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

local function updatePlayer()
    updateCritter(player)
    for i = 1, #shelters do
        local s = shelters[i]
        if distanceToPlayer(s) < s.size then
            player.life = player.life + (player.max_life / (60 * 10))
            player.life = math.min(player.life, player.max_life)
            break
        end
    end
end


--
-- AI code
-- 

local function createRandomCritter(hidden)
    local x, y = randomCoordinates(hidden)
    local zone = zoneFromCoordinates(x, y)
    
    local level = math.random(math.ceil(zone/2), zone)
    local stype
    if level == 1 then
        -- no attack critters of level 1 (and in zone 1)
        stype = segmentTypes[math.random(2)]
    else
        stype = segmentTypes[math.random(#segmentTypes)]
    end

    local c = createCritter(x, y, stype)
    c.zone = zone

    while level > c.level do
        addSegment(c, segmentTypes[math.random(#segmentTypes)])
        local ii = #(c.segs)-1
        for i = 1,ii  do
            evolveSegment(c, i)
            if level <= c.level then
                break
            end
        end
    end
    updateStats(c)
    c.life = c.max_life * (math.random()*0.3+0.7)
    c.energy = c.max_energy
    return c
end

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

            local z = zones[c.zone]

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
-- General game loop code
--

function game.init()
    gfx.init()
    game.restart()
end

function game.restart()
    globalTic = 0

    -- create player critter
    player = createPlayer()
    
    -- populate critters
    critters = {}
    for i = 1, 100 do
        table.insert(critters, createRandomCritter())
    end

    -- populate items
    items = {}
    for i = 1, 100 do
        table.insert(items, createRandomItem())
    end

    -- segments: these are items but their lifetime is different from the regular items
    segments = {}
end

function game.tic()
    globalTic = globalTic + 1
    input.tic()

    -- player processing
    processPlayerInput()
    updatePlayer()

    -- garbage collection
    if globalTic % 60 == 0 then
        local itemsCollected = 0
        for i = 1, #items do
            if tooFar(items[i]) then
                items[i] = createRandomItem(true)
                itemsCollected = itemsCollected + 1
            end
        end
        print("Garbage collected "..itemsCollected.." items")
    end
    if globalTic % 60 == 29 then
        local crittersCollected = 0
        for i = 1, #critters do
            if tooFar(critters[i]) then
                critters[i].dead = true
                critters[i] = createRandomCritter(true)
                crittersCollected = crittersCollected + 1
            end
        end
        print("Garbage collected "..crittersCollected.." critters")
    end

    -- other critters processing
    for i = 1, #critters do
        local c = critters[i]
        if c.dead then
            critterDied(c)
            c = createRandomCritter(true)
            critters[i] = c
        end
        aiCritter(c)
        updateCritter(c)
    end

    -- update items position and rotation
    for i = 1, #items do
        updateItem(items[i])
    end
    -- update segments
    local deadSegments = {}
    for i = 1, #segments do
        local s = segments[i]
        updateItem(s)
        s.ttl = s.ttl - 1
        if s.ttl <= 0 then
            table.insert(deadSegments, i)
        end
    end
    if #deadSegments > 0 then
        for i = #deadSegments,1,-1 do
            table.remove(segments, deadSegments[i])
        end
        print("Collected " .. #deadSegments .. " segments")
    end
end

function game.toggleDebug()
    debug = not debug
end



--
-- Render code
--

local function renderBackground()
    love.graphics.setColor(255, 255, 255, 128)

    local function tileBackground(ox, oy, tiles)
        -- all backgrounds assumed to be the same dimensions
        local bgw, bgh = tiles[1]:getWidth(), tiles[1]:getHeight()

        local scol = math.floor((ox - sw/2) / bgw)
        local ecol = math.ceil((ox + sw/2) / bgw)
        local srow = math.floor((oy - sh/2) / bgh)
        local erow = math.ceil((oy + sh/2) / bgh)

        for row = srow, erow do
            for col = scol, ecol do
                local index = ((row + col) % #tiles) + 1
                love.graphics.draw(tiles[index], col * bgw, row * bgh)
            end
        end
    end
    love.graphics.push()
    love.graphics.translate(player.x/2, player.y/2)
    tileBackground(player.x/2, player.y/2, gfx.bg.far)
    love.graphics.pop()
    tileBackground(player.x, player.y, gfx.bg.near)

end

local function renderShelters()
    love.graphics.setColor(255, 255, 255, 128)
    for i = 1, #shelters do
        local s = shelters[i]
        love.graphics.circle('line', s.x, s.y, s.size)
    end
end

local function renderCritter(c)
    if not onScreen(c.x, c.y) then
        return
    end
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

local function renderItems(items)
    local img = gfx.images.items
    local qs = gfx.quads.items
    for i = 1, #items do
        local it = items[i]
        if onScreen(it.x, it.y) then
            if it.ttl and it.ttl < 120 then
                love.graphics.setColor(255,255,255,192*(it.ttl/120))
            else
                love.graphics.setColor(255,255,255,192)
            end
            love.graphics.drawq(img, qs[it.itype], it.x, it.y, it.angle, 1, 1, 8, 8)
        end
    end
end

local function renderHUD()
    local s, w
    local font = love.graphics.getFont()

    -- render life
    love.graphics.push()
        love.graphics.translate(10, sh-20)
        love.graphics.setColor(255,255,255,128)
        love.graphics.rectangle('line', 0, 0, 202, 10)
        s = math.ceil(player.life) .. "/" .. player.max_life
        love.graphics.print(s, 212, -3)
        love.graphics.setColor(64,64,64,128)
        love.graphics.rectangle('fill', 1, 1, 200, 8)
        love.graphics.setColor(160,0,0,128)
        love.graphics.rectangle('fill', 1, 1, (player.life/player.max_life*200), 8)
    love.graphics.pop()

    -- render energy
    love.graphics.push()
        love.graphics.translate(sw-212, sh-20)
        love.graphics.setColor(255,255,255,128)
        love.graphics.rectangle('line', 0, 0, 202, 10)
        s = math.ceil(player.energy) .. "/" .. player.max_energy
        w = font:getWidth(s)
        love.graphics.print(s, -10 - w, -3)
        love.graphics.setColor(64,64,64,128)
        love.graphics.rectangle('fill', 1, 1, 200, 8)
        love.graphics.setColor(0,0,160,128)
        love.graphics.rectangle('fill', 1, 1, (player.energy/player.max_energy*200), 8)
    love.graphics.pop()
end

local function renderDebug()
    love.graphics.setColor(255,255,255)
    local d = distanceToPlayer({x=0,y=0})
    local zone = zoneFromDistance(d)
    local str = love.timer.getFPS() .. " fps, zone "..zone..", dist ".. math.ceil(d)
    str = str .. ", " .. #critters .. " critters, " .. #items .. " items, " .. #segments .. " segments"
    love.graphics.print(str, 0, 0)
end

function game.render()
    -- background color is a function of the distance of the player to the origin
    local d = math.sqrt(player.x*player.x + player.y*player.y)
    local v = d/5000
    local c = math.max(0, 96 * (1-v))
    love.graphics.setBackgroundColor(c,c,c)
    love.graphics.clear()

    love.graphics.push()
    love.graphics.translate(sw/2 - player.x, sh/2 - player.y)
    
    renderBackground()
    renderShelters()

    renderItems(items)
    renderItems(segments)

    renderCritter(player)
    for i = 1, #critters do
        renderCritter(critters[i])
    end

    love.graphics.pop()

    renderHUD()

    if debug then
        renderDebug()
    end
end

return game

