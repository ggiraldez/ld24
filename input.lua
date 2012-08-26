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

    input.any = false
    input.pressed = {}
    input.escape = false
end

function input.keypressed(key, unicode)
    if key == 'escape' then
        input.escape = true
    else
        input.any = true
        input.pressed[key] = true
    end
end

input.reset()

return input

