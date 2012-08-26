gfx = {}

function gfx.load()
    local iw, ih

    gfx.images = {}
    gfx.quads = {}

    gfx.images.segments = love.graphics.newImage("assets/segments.png")
    iw, ih = gfx.images.segments:getWidth(), gfx.images.segments:getHeight()

    local qfl, qfs, qfa, qml, qms, qma, qll, qls, qla
    
    gfx.quads.head = {}
    gfx.quads.body = {}
    gfx.quads.tail = {}

    qfl = {}
    qfs = {}
    qfa = {}
    qml = {}
    qms = {}
    qma = {}
    qll = {}
    qls = {}
    qla = {}
    for i = 6,1,-1 do
        qfl[i] = love.graphics.newQuad(32*(6-i), 0, 32, 32, iw, ih)
        qfs[i] = love.graphics.newQuad(32*(6-i), 32, 32, 32, iw, ih)
        qfa[i] = love.graphics.newQuad(32*(6-i), 64, 32, 32, iw, ih)
        qml[i] = love.graphics.newQuad(32*(6-i), 96, 32, 32, iw, ih)
        qms[i] = love.graphics.newQuad(32*(6-i), 128, 32, 32, iw, ih)
        qma[i] = love.graphics.newQuad(32*(6-i), 160, 32, 32, iw, ih)
        qll[i] = love.graphics.newQuad(32*(6-i), 192, 32, 32, iw, ih)
        qls[i] = love.graphics.newQuad(32*(6-i), 224, 32, 32, iw, ih)
        qla[i] = love.graphics.newQuad(32*(6-i), 256, 32, 32, iw, ih)
    end
    gfx.quads.head['life'] = qfl
    gfx.quads.head['speed'] = qfs
    gfx.quads.head['attack'] = qfa
    gfx.quads.body['life'] = qml
    gfx.quads.body['speed'] = qms
    gfx.quads.body['attack'] = qma
    gfx.quads.tail['life'] = qll
    gfx.quads.tail['speed'] = qls
    gfx.quads.tail['attack'] = qla


    gfx.images.items = love.graphics.newImage("assets/items.png")
    iw, ih = gfx.images.items:getWidth(), gfx.images.items:getHeight()

    gfx.quads['items'] = {
        food = love.graphics.newQuad(0, 0, 16, 16, iw, ih),
        energy = love.graphics.newQuad(16, 0, 16, 16, iw, ih),
        
        life = love.graphics.newQuad(0, 16, 16, 16, iw, ih),
        speed = love.graphics.newQuad(16, 16, 16, 16, iw, ih),
        attack = love.graphics.newQuad(32, 16, 16, 16, iw, ih)
    }

end

local function clearPixels(x, y, r, g, b, a)
    return 0,0,0,0
end

local function createBackground(base, value, count)
    local w, h = base:getWidth(), base:getHeight()
    local data = love.image.newImageData(w, h)
    data:paste(base, 0, 0, 0, 0, w, h)
    for i = 1, count do
        local x = math.random(w-2)
        local y = math.random(h-2)
        local v = math.max(0, math.min(255, math.random(value - 30, value + 30)))
        data:setPixel(x, y, v, v, v, 255)
        data:setPixel(x-1, y, v, v, v, 192)
        data:setPixel(x+1, y, v, v, v, 192)
        data:setPixel(x, y-1, v, v, v, 192)
        data:setPixel(x, y+1, v, v, v, 192)
    end
    return love.graphics.newImage(data)
end

function gfx.createBackgrounds()
    local base = love.image.newImageData(512, 512)
    base:mapPixel(clearPixels)

    gfx.bg = {}
    gfx.bg.near = {}
    gfx.bg.far = {}
    for i = 1,9 do
        table.insert(gfx.bg.near, createBackground(base, 225, 100))
        table.insert(gfx.bg.far, createBackground(base, 128, 60))
    end
end

function gfx.init()
    print("Creating backgrounds")
    gfx.createBackgrounds()
    
    print("Loading textures")
    gfx.load()

    print("Loading font")
    gfx.fonts = {}
    gfx.fonts.normal = love.graphics.newFont("assets/victor-pixel.ttf", 14)
    gfx.fonts.big = love.graphics.newFont("assets/victor-pixel.ttf", 18)
    gfx.fonts.huge = love.graphics.newFont("assets/victor-pixel.ttf", 24)
    love.graphics.setFont(gfx.fonts.normal)
end

return gfx

