gfx = {}

function gfx.load()
    gfx.images = {}
    gfx.quads = {}

    gfx.images.segments = love.graphics.newImage("assets/segments.png")

    local iw, ih = gfx.images.segments:getWidth(), gfx.images.segments:getHeight()
    local ql, qs, qa
    
    ql = {}
    qs = {}
    qa = {}
    for i = 6,1,-1 do
        ql[i] = love.graphics.newQuad(32*(6-i), 0, 32, 32, iw, ih)
        qs[i] = love.graphics.newQuad(32*(6-i), 32, 32, 32, iw, ih)
        qa[i] = love.graphics.newQuad(32*(6-i), 64, 32, 32, iw, ih)
    end
    gfx.quads['life'] = ql
    gfx.quads['speed'] = qs
    gfx.quads['attack'] = qa
end

gfx.load()

return gfx

