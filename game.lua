require('input')
require('gfx')
require('sfx')
game = {}

-- module variables
--
local sw, sh
local screenSize
local scale = 1
local farThreshold

local debug = false
local updateTime, updateAcc = 0, 0
local renderTime, renderAcc = 0, 0

local quitting = false
local paused = false

local introTime = 10000
local xp_penalty = 0.5
local max_seg_level = 6
local near_dist

local function resize()
  sw = love.graphics.getWidth()
  sh = love.graphics.getHeight()
  scale = 1
  screenSize = math.max(sw, sh)
  if screenSize > 1600 then
    scale = 2
    sw = sw / 2
    sh = sh / 2
    screenSize = screenSize / 2
  end
  farThreshold = 3 * screenSize
  near_dist = screenSize / 2
end

resize()

-- forward declarations
--
local critterEatSegment


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

local function distance2(e1, e2)
    local dx = e1.x - e2.x
    local dy = e1.y - e2.y
    return dx*dx + dy*dy
end

local function distance(e1, e2)
    local dx = e1.x - e2.x
    local dy = e1.y - e2.y
    return math.sqrt(dx*dx + dy*dy)
end

local function distanceToPlayer(c)
    return distance(c, player)
end

local function distance2ToPlayer(c)
    return distance2(c, player)
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
        va=math.random()*2*math.pi,
        hold=30
    }
end

local function createRandomItem(hidden)
    local itype
    if math.random(10) > 2 then
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
    if it.hold > 0 then
        it.hold = it.hold - 1
    end
end

local function consumeItem(critter, index)
    local it = items[index]
    if it.itype == 'food' then
        critter.life = critter.life + 0.25 * critter.max_life
        critter.life = math.min(critter.life, critter.max_life)
    elseif it.itype == 'energy' then
        critter.energy = critter.energy + 2
        critter.energy = math.min(critter.energy, critter.max_energy)
    end
    -- just to make sure the item is invalid if we cached it somewhere
    it.x = 1/0
    it.y = 1/0
    items[index] = createRandomItem(true)
    if critter == player then
        sfx.play('pickup')
    end
end

local function consumeSegment(critter, index)
    local seg = segments[index]
    if seg.ttl > 0 then
        critterEatSegment(critter, seg)
        if critter == player then
            sfx.play('pickup')
        end
    end
    -- just to make sure the item is invalid if we cached it somewhere
    seg.x = 1/0
    seg.y = 1/0
    seg.ttl = 0
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
        progress = 0,           -- progress to next level (must be equal or greater than level)

        max_v = 4,              -- maximum velocity
        friction = 0.02,        -- friction coefficient

        max_life = 10,          -- total life
        life = 0,               -- current life
        hurt_time = 0,          -- timer when the critter takes damage
        last_attacker = nil,

        max_energy = 10,        -- total energy
        energy = 10,            -- current energy

        attack = 0,             -- attack strength
        attack_cooldown = 0,    -- must wait to attack again

        dead = false,           -- is it dead yet?

        size = 0,               -- total size (sum of all segments * 2)
        color = { 255, 255, 255 },

        eaten = {               -- count of levels eaten of each type to figure out
            life = 0,           -- what type will be the new segment
            speed = 0,
            attack = 0
        },
        nearby = {              -- nearby items (updated in checkItemsCollisions)
            food = {},
            energy = {}
        },

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
    local total_size = 0

    max_life = #(c.segs)
    max_energy = #(c.segs)
    friction = 2

    for i = 1, #(c.segs) do
        local seg = c.segs[i]
        total_size = total_size + seg.size*2
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
    c.size = total_size

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
    -- update segment positions
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
    -- level up one segment
    if num < 1 or num > #(c.segs) then
        return false
    end
    local s = c.segs[num]
    if s.level == max_seg_level then
        return false
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
    return true
end

local function nextSegmentType(c)
    local stype = nil
    local winning = 0
    if c.eaten.life > winning then
        winning = c.eaten.life
        stype = 'life'
    end
    if c.eaten.speed > winning then
        winning = c.eaten.speed
        stype = 'speed'
    end
    if c.eaten.attack > winning then
        winning = c.eaten.attack
        stype = 'attack'
    end
    return stype
end

local function levelUpCritter(c)
    local extra = c.progress - c.level
    c.progress = extra

    local num = nil
    local ss = c.segs
    for i = 1, #ss do
        if ss[i].level < max_seg_level then
            if i < #ss and ss[i+1].level == ss[i].level then
                num = i
                break
            end
        end
    end

    if num ~= nil then
        -- evolve the num segment
        evolveSegment(c, num)
        if c == player then
            sfx.play('levelup')
        end
    else
        local stype = nextSegmentType(c)
        if not stype then
            stype = segmentTypes[math.random(#segmentTypes)]
        end
        addSegment(c, stype)
        -- add a segment
        c.eaten.life = 0
        c.eaten.speed = 0
        c.eaten.attack = 0
        if c == player then
            sfx.play('newseg')
        end
    end
    local lp = c.life / c.max_life
    local ep = c.energy / c.max_energy
    updateStats(c)
    c.life = lp * c.max_life
    c.energy = ep * c.max_energy

end

critterEatSegment = function(c, segitem)
    local stype = segitem.itype
    local level = segitem.level

    -- some life and energy is regained
    if stype == 'life' then
        c.life = c.life + level
    elseif stype == 'speed' then
        c.life = c.life + level/2
        c.energy = c.energy + level/2
    elseif stype == 'attack' then
        c.energy = c.energy + level
    end
    c.life = math.min(c.life, c.max_life)
    c.energy = math.min(c.energy, c.max_energy)

    -- progress to level up
    c.progress = c.progress + segitem.level * xp_penalty
    c.eaten[stype] = c.eaten[stype] + level
    if c.progress >= c.level then
        levelUpCritter(c)
    end
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

    -- attack cooldown
    if c.attack_cooldown > 0 then
        c.attack_cooldown = c.attack_cooldown - 1
    end

    -- timers
    if c.hurt_time > 0 then
        c.hurt_time = c.hurt_time - 1
    end
end

local function critterDied(c)
    if onScreen(c.x, c.y) then
        if c == player then
            sfx.play('death')
        elseif c.last_attacker == player then
            sfx.play('kill')
        else
            sfx.play('kill', true)
        end
    end

    -- spawn segments
    for i = 1, #(c.segs) do
        local seg = c.segs[i]
        local stype = seg.stype
        local x = seg.x + (math.random()-0.5) * 4
        local y = seg.y + (math.random()-0.5) * 4
        local s = createItem(x, y, stype)
        s.ttl = (math.random()*60+30)*60        -- decay 30-90 secs
        s.hold = 30                             -- must wait 30 tics to consume
        s.level = c.segs[i].level
        table.insert(segments, s)
    end
end

local function damageCritter(target, damage, source)
    target.life = target.life - damage
    target.hurt_time = 30
    target.last_attacker = source
    if onScreen(target.x, target.y) then
        if target == player then
            sfx.play('hurt')
        else
            if source == player then
                sfx.play('hit')
            else
                sfx.play('hit', true)
            end
        end
    end
end

local function checkCritterAttack(attacker, defender)
    if defender.dead then
        return false
    end
    local ar = attacker.segs[1].size    -- head
    local dss = defender.segs
    local hit = false

    -- check each of the defender segments
    for i = 1, #dss do
        local ds = dss[i]
        if distance(attacker, ds) < ar then
            hit = true
            if ds.stype == 'attack' and i > 1 then
                -- the attacker takes some damage
                -- but not from the head, since that is calculated from the
                -- defender when it computes attack damage
                local thorns = ds.level + defender.level/2
                damageCritter(attacker, thorns, defender)
            end
        end
    end

    if hit then
        -- the defender takes damage
        local damage = attacker.attack
        damageCritter(defender, damage, attacker)
        attacker.attack_cooldown = 60
    end
    return hit
end

local function checkItemsCollisions(c)
    local d2
    local head_size2 = c.segs[1].size * c.segs[1].size

    -- check collisions against items
    c.nearby.food = {}
    c.nearby.energy = {}
    for j = 1, #items do
        local it = items[j]
        d2 = distance2(c, it)
        if d2 < head_size2 then
            consumeItem(c, j)
        elseif d2 < near_dist * near_dist then
            table.insert(c.nearby[it.itype], it)
        end
    end

    -- check collisions against segment items
    for j = 1, #segments do
        local s = segments[j]
        if s.hold <= 0 then
            d2 = distance2(c, s)
            if d2 < head_size2 then
                consumeSegment(c, j)
            end
        end
    end
end

local function checkCollisions(c)
    local d2
    local head_size2 = c.segs[1].size * c.segs[1].size

    -- against the player and other critters
    if c.segs[1].stype == 'attack' and c.attack_cooldown <= 0 then
        d2 = distance2(c, player)
        if d2 < head_size2 + player.size*player.size then
            -- attack player
            checkCritterAttack(c, player)
        end

        if c.attack_cooldown <= 0 then
            for j = 1, #critters do
                local cj = critters[j]
                d2 = distance2(c, cj)
                if d2 < head_size2 + cj.size*cj.size and c ~= cj then
                    if checkCritterAttack(c, cj) then
                        -- if successful, break for the cooldown
                        break
                    end
                end
            end
        end
    end

    checkItemsCollisions(c)
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
    player.deadTime = 0                 -- initialize to avoid possible bugs
    return player
end

local function processPlayerInput()
    local a = 0.2
    local ax, ay = 0, 0
    if input.up then ay = ay - 1 end
    if input.down then ay = ay + 1 end
    if input.left then ax = ax - 1 end
    if input.right then ax = ax + 1 end

    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getX(), love.mouse.getY()
        ax = mx/scale - sw/2
        ay = my/scale - sh/2
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
    if player.dead then
        critterDied(player)
        player.deadTime = 120
    else
        for i = 1, #shelters do
            local s = shelters[i]
            if distanceToPlayer(s) < s.size then
                player.life = player.life + (player.max_life / (60 * 10))
                player.life = math.min(player.life, player.max_life)
                break
            end
        end
    end
end

local function checkPlayerCollisions()
    local d2
    local head_size2 = player.segs[1].size * player.segs[1].size

    -- against other critters
    if player.attack_cooldown <= 0 then
        for j = 1, #critters do
            local cj = critters[j]
            d2 = distance2(player, cj)
            if d2 < head_size2 + cj.size*cj.size then
                if checkCritterAttack(player, cj) then
                    -- we got a hit so we are now in cooldown
                    break
                end
            end
        end
    end

    checkItemsCollisions(player)
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
            c.count = math.random(5,15)     -- tics to apply acceleration

            -- try to keep the critter in his zone
            local z = zones[c.zone]
            if d < z.inner then
                c.aa = math.atan2(c.y, c.x) + (math.random()-0.5) * math.pi*3/4
            elseif d > z.outer then
                c.aa = math.atan2(-c.y, -c.x) + (math.random()-0.5) * math.pi*3/4
            else
                c.aa = math.random() * 2 * math.pi
            end

            -- basic instinct: if life is below 3/4, try to eat
            if c.life / c.max_life < 0.75 then
                local nearest = nil
                local dist = 1/0
                local candidates = c.nearby.food
                for i = 1, #candidates do
                    local food = candidates[i]
                    local d2 = distance2(c, food)
                    if d2 < dist then
                        nearest = food
                        dist = d2
                    end
                end
                if nearest then
                    local dx = nearest.x - c.x
                    local dy = nearest.y - c.y
                    c.aa = math.atan2(dy, dx)
                end
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
    sfx.init()
    game.restart()
end

function game.restart()
    globalTic = 0
    introTime = 0

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
    local start = love.timer.getTime()

    if not paused then
        globalTic = globalTic + 1
    end
    input.tic()

    if input.escape then
        if quitting then
            quitting = false
        elseif paused then
            paused = false
        else
            quitting = true
        end
        input.reset()
    end
    if quitting then
        if input.pressed['y'] then
            love.event.push('quit')
            return
        elseif input.pressed['r'] then
            quitting = false
            game.restart()
            input.reset()
            return
        elseif input.pressed['n'] then
            quitting = false
        end
        input.reset()
    else
        if paused then
            if input.any then
                paused = false
                input.reset()
            end
        else
            if input.pressed['p'] then
                paused = not paused
                input.reset()
            end
        end
    end

    if player.dead then
        if player.deadTime <= 0 and input.any then
            game.restart()
            return
        end
        input.reset()
    end

    if not paused then
        game.update()
    end

    -- compute update/tic time
    updateAcc = updateAcc + love.timer.getTime() - start
    if globalTic % 60 == 0 then
        updateTime = math.floor(updateAcc / 60 * 1000 * 1000)
        updateAcc = 0
    end
end

function game.update()
    if not player.dead then
        -- player processing
        processPlayerInput()
        updatePlayer()
    end

    -- garbage collection
    if globalTic % 60 == 0 then
        local itemsCollected = 0
        for i = 1, #items do
            if tooFar(items[i]) then
                items[i] = createRandomItem(true)
                itemsCollected = itemsCollected + 1
            end
        end
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
    end

    -- collisions
    if not player.dead then
        checkPlayerCollisions()
    end

    -- divide the critters in batches to aleviate processing
    local modTic = globalTic % 7
    for i = 1, #critters do
        local c = critters[i]
        local check = false
        if onScreen(c.x, c.y) or i % 7 == modTic then
            -- if the critter is onscreen, we check every tic
            check = true
        end
        if check and not c.dead then
            checkCollisions(c)
        end
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

local function renderCritter(c, micro_hud)
    if not onScreen(c.x, c.y) then
        return
    end
    local img = gfx.images.segments
    local qs = gfx.quads
    local ss = c.segs
    local s = ss[1]

    if c.hurt_time > 0 and math.ceil(c.hurt_time/10) % 2 == 0 then
        love.graphics.setColor(255,255,255,255)
    else
        love.graphics.setColor(c.color)
    end
    love.graphics.draw(img, qs.head[s.stype][s.level], s.x, s.y, (s.angle+math.pi), 1, 1, 16, 16)
    for i = 2, #ss-1 do
        s = ss[i]
        love.graphics.draw(img, qs.body[s.stype][s.level], s.x, s.y, (s.angle), 1, 1, 16, 16)
    end
    if #ss > 1 then
        s = ss[#ss]
        love.graphics.draw(img, qs.tail[s.stype][s.level], s.x, s.y, (s.angle), 1, 1, 16, 16)
    end

    if micro_hud then
        local x = c.x - 8
        local y = c.y - ss[1].size - 4
        love.graphics.setColor(255,255,255,128)
        love.graphics.rectangle('fill', x-1, y-1, 16, 4)
        love.graphics.setColor(255,0,0,160)
        love.graphics.rectangle('fill', x, y, math.max(0,c.life/c.max_life)*16, 2)
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
            love.graphics.draw(img, qs[it.itype], it.x, it.y, it.angle, 1, 1, 8, 8)
        end
    end
end

local function renderHUD()
    local s, w
    local font = gfx.fonts.normal
    love.graphics.setFont(font)

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
        love.graphics.rectangle('fill', 1, 1, math.max(0, player.life/player.max_life*200), 8)
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
        love.graphics.rectangle('fill', 1, 1, math.max(0, player.energy/player.max_energy*200), 8)
    love.graphics.pop()

    -- level and progress to next level
    love.graphics.push()
        love.graphics.translate(sw/2, sh-18)
        love.graphics.setColor(255,255,255,128)
        s = ""..player.level
        w = font:getWidth(s)
        love.graphics.print(s, -110-w, -5)
        love.graphics.setColor(64,64,64,128)
        love.graphics.rectangle('fill', -100, 0, 200, 4)
        love.graphics.setColor(255,192,0,192)
        love.graphics.rectangle('fill', -100, 0, (player.progress/player.level*200), 4)

        local stype = nextSegmentType(player)
        if stype == 'life' then
            love.graphics.setColor(200,0,0,192)
        elseif stype == 'speed' then
            love.graphics.setColor(0,200,0,192)
        elseif stype == 'attack' then
            love.graphics.setColor(0,0,200,192)
        else
            love.graphics.setColor(200,200,200,192)
        end
        love.graphics.rectangle('fill', 110, -1, 6, 6)
    love.graphics.pop()
end

local function renderDebug()
    love.graphics.setFont(gfx.fonts.normal)
    love.graphics.setColor(255,255,255)
    local d = distanceToPlayer({x=0,y=0})
    local zone = zoneFromDistance(d)

    local str
    str = love.timer.getFPS() .. " fps, zone "..zone..", dist ".. math.ceil(d) ..
          ", " .. #critters .. " critters, " .. #items .. " items, " .. #segments .. " segments"
    love.graphics.print(str, 0, 0)

    str = "Update " .. updateTime ..
          " us, render " .. renderTime .. " ms"
    love.graphics.print(str, 0, 10)
end

local function printCenteredText(text, font, y)
    font = gfx.fonts[font]
    local w = font:getWidth(text)
    love.graphics.setFont(font)
    love.graphics.print(text, (sw-w)/2, y)
end

local function renderPause()
    love.graphics.setColor(255,255,255,255)
    printCenteredText("Paused", 'big', sh/2 + 60)
    printCenteredText("Press any key to resume", 'normal', sh/2 + 80)
end

local function renderQuitConfirmation()
    love.graphics.setColor(255,255,255,255)
    printCenteredText("Quit? Y/N", 'big', sh/2 + 60)
    printCenteredText("(Press R to restart)", 'normal', sh/2 + 80)
end

local function renderDead()
    if player.deadTime > 0 then
        player.deadTime = player.deadTime - 1
    end

    love.graphics.setColor(255,255,255,255*(120-player.deadTime)/120)
    printCenteredText("You died :(", 'big', sh/2 - 20)

    if player.deadTime <= 0 then
        printCenteredText('Press any key to restart', 'normal', sh/2 + 10)
    end
end

local function renderIntro()
    local fadeTime = 90

    local function doText(text, font, y, color, from, to)
        if from and to then
            if introTime < from or introTime > to then
                return
            end
            color = table.copy(color)
            local df = introTime - from
            if df < fadeTime then
                color[4] = color[4] * df/fadeTime
            end
            local dt = to - introTime
            if dt < 2*fadeTime then
                color[4] = color[4] * dt/(2*fadeTime)
            end
        end
        font = gfx.fonts[font]
        love.graphics.setFont(font)
        local w = font:getWidth(text)
        love.graphics.setColor(color)
        love.graphics.print(text, (sw-w)/2, y)
    end

    local color1 = { 255,255,255,192 }
    doText('PINCERS', 'huge', sh/4, color1, 0, 800)
    doText('made by Gustavo Giráldez', 'big', sh/4+30, color1, 0.75*fadeTime, 800)

    local color2 = { 255,255,255,128 }
    doText('for the Ludum Dare 24 compo', 'normal', sh/2+90, color2, 2*fadeTime, 800)
    doText('August 2012', 'normal', sh/2+110, color2, 2.75*fadeTime, 800)

    doText('use the mouse, arrow keys or WASD to guide your creature',
           'normal', sh/2+170, color2, 3.5*fadeTime, 1200)
    doText('eat the red and blue pills to regain life and energy',
           'normal', sh/2+180, color2, 3.5*fadeTime, 1200)
end

function game.render()
    local start = love.timer.getTime()

    resize()
    love.graphics.scale(scale, scale)

    -- background color is a function of the distance of the player to the origin
    local d = math.sqrt(player.x*player.x + player.y*player.y)
    local v = d/5000
    local c = math.max(0, 96 * (1-v))
    if player.hurt_time > 0 then
        local lp = 1-player.life/player.max_life
        local r = math.min(255, c + (192*lp*player.hurt_time/30))
        love.graphics.setBackgroundColor(r,c,c)
    else
        love.graphics.setBackgroundColor(c,c,c)
    end
    love.graphics.clear()

    love.graphics.push()
    love.graphics.translate(sw/2 - player.x, sh/2 - player.y)

    renderBackground()
    renderShelters()

    renderItems(items)
    renderItems(segments)

    if not player.dead then
        renderCritter(player)
    end
    for i = 1, #critters do
        local c = critters[i]
        if not c.dead then
            renderCritter(c, true)
        end
    end

    love.graphics.pop()

    if quitting then
        renderQuitConfirmation()
    else
        if paused then
            renderPause()
        else
            if introTime < 1200 then
                if distance2ToPlayer({x=0, y=0}) > 200*200 then
                    introTime = introTime + 3
                else
                    introTime = introTime + 1
                end
                if not player.dead then
                    -- intro interferes with dead message
                    renderIntro()
                end
            end
        end

        renderHUD()
        if player.dead then
            if player.hurt_time > 0 then
                player.hurt_time = player.hurt_time - 1
            end
            renderDead()
        end
    end

    renderAcc = renderAcc + love.timer.getTime() - start
    if globalTic % 60 == 0 then
        renderTime = math.floor(renderAcc / 60 * 1000)
        renderAcc = 0
    end

    if debug then
        renderDebug()
    end
end

return game
