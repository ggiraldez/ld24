require('input')
require('gfx')
game = {}

local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

-- player = nil
-- critters = {}

local segmentTypes = { 'life', 'speed', 'attack' }
local segmentSizes = {
    life = { 10, 14, 18, 22, 28, 32 },
    speed = { 10, 14, 18, 22, 28, 32 },
    attack = { 22, 22, 28, 28, 32, 32 }
}

--
-- Critters code
--

-- creates a level 1 critter of the given type st at position x,y
local function createCritter(x, y, st)
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
        -- segments
        segs = {{ 
            x=x, y=y,                       -- position
            angle=angle,                    -- angle
            st=st,                          -- type
            level=level,                    -- level
            size=segmentSizes[st][level]/2  -- size
        }}
    }
    return c
end

local function updateStats(c)
    -- recalculate max life, max speed, max energý and friction for the critter
end

-- adds a segment of the given type at level 1 to the critter c
local function addSegment(c, st)
    local last = c.segs[#(c.segs)]
    local x = last.x
    local y = last.y
    local angle = c.va
    local size = segmentSizes[st][1]/2
    x = x - (size + last.size) * math.cos(angle)
    y = y - (size + last.size) * math.sin(angle)
    table.insert(c.segs, {
        x=x, y=y,
        angle=angle,
        st=st,
        level=1,
        size=size
    })
    updateStats(c)
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
    s.size = segmentSizes[s.st][s.level]/2
    c.level = c.level + 1
    updateSegments(c)
    updateStats(c)
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

        -- modify v, va with a, aa 
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

            if d < 1000 then
                c.aa = math.random() * 2 * math.pi
            elseif d < 3000 then
                c.aa = math.atan2(-c.y, -c.x) + math.random() * math.pi - math.pi/2
            else
                c.aa = math.atan2(-c.y, -c.x)
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
    game.restart()
end

function game.restart()
    globalTic = 0

    player = createCritter(0, 0, 'attack')
    addSegment(player, 'life')
    
    critters = {}
    for i = 1, 50 do
        local c
        local st = segmentTypes[math.random(#segmentTypes)]
        local level = math.random(20)
        if st == 'attack' then
            level = math.max(level, 2)
        end
                
        local x = math.random(sw) - sw/2
        local y = math.random(sh) - sh/2
        
        c = createCritter(x, y, st)
        while level > 1 do
            addSegment(c, segmentTypes[math.random(2)])
            level = level - 1
            for i = 1, math.min(level, #(c.segs)-1) do
                evolveSegment(c, i)
            end
            level = level - i
        end
        table.insert(critters, c)
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
end

function game.toggleDebug() end



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
    for i = 1, #ss do
        local s = ss[i]
        love.graphics.drawq(img, qs[s.st][s.level], s.x, s.y, (s.angle+math.pi), 1, 1, 16, 16)
    end
end

function game.render()
    love.graphics.translate(sw/2 - player.x, sh/2 - player.y)
    renderBackground()
    renderCritter(player)
    for i = 1, #critters do
        renderCritter(critters[i])
    end
end

return game

