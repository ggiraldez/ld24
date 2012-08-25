input = {}

function input.tic()
    input.up    = love.keyboard.isDown('up')    or love.keyboard.isDown('w')
    input.down  = love.keyboard.isDown('down')  or love.keyboard.isDown('s')
    input.left  = love.keyboard.isDown('left')  or love.keyboard.isDown('a')
    input.right = love.keyboard.isDown('right') or love.keyboard.isDown('d')
end

function input.reset()
    input.up = false
    input.down = false
    input.left = false
    input.right = false

    input.counts = { up = 0, down = 0 }
end

function input.keypressed(key, unicode)
    if key == 'up' or key == 'down' then
        input.counts[key] = input.counts[key] + 1
    end
end

function input.consumeAll(key)
    local count = input.counts[key]
    if count > 0 then
        input.counts[key] = 0
    end
    return count
end

function input.consumeOne(key)
    local count = input.counts[key]
    if count > 0 then
        input.counts[key] = count - 1
        return true
    else
        return false
    end
end

input.reset()

return input

