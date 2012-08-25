require('input')
game = {}

local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

-- player = nil
-- critters = {}

--
-- Critters code
--

local function createCritter(x, y)
    return {
        x = x, y = y,
        v = 0, va = 0,
        a = 0, aa = 0,
        size = 10
    }
end

local function updateCritter(c)
    local vx, vy = 0,0
    local ax, ay = 0,0
    local v, va = c.v, c.va
    local a, aa = c.a, c.aa
    local max_v = 4
    local friction = 0.02

    if a > 0 then
        ax = a * math.cos(aa)
        ay = a * math.sin(aa)
    end

    if v > 0 then
        -- add friction
        local f = v * friction
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
        v = math.min(max_v, math.sqrt(vx * vx + vy * vy))
        va = math.atan2(vy, vx)
    end

    if v > 0 then
        vx = v * math.cos(va)
        vy = v * math.sin(va)
        c.x = c.x + vx
        c.y = c.y + vy
    end

    c.v = v
    c.va = va
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

    -- at most one action every 1/4 sec
    if globalTic > c.tic + 15 then
        c.tic = globalTic

        if math.random(100) < 30 then
            c.a = 0.5
            c.aa = math.random() * 2 * math.pi
            c.count = 10
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

    player = createCritter(0, 0)
    player.size = 15
    
    critters = {}
    for i = 1, 50 do
        table.insert(critters, createCritter(math.random(sw) - sw/2, math.random(sh) - sh/2))
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
function game.reloadGfx() end



--
-- Render code
--

local function renderBackground()
    love.graphics.circle('line', 0, 0, 50)
end

local function renderCritter(c)
    love.graphics.circle('fill', c.x, c.y, c.size)
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

