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
        energy = love.graphics.newQuad(16, 0, 16, 16, iw, ih)
    }
end

gfx.load()

return gfx

