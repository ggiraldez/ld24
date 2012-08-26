require('utils')
local game = require('game')
local input = require('input')
local ticsPerSec = 60
local showFPS = false

function love.load()
    math.randomseed(os.time())
    game.init()
end

do
    local lastTicTime = 0
    local currentTime = 0
    local lastReport = 0
    local reportInterval = 1
    local tics = 0

    function love.update(dt)
        currentTime = currentTime + dt
        while currentTime - lastTicTime > 1/ticsPerSec do
            game.tic()
            tics = tics + 1
            lastTicTime = lastTicTime + 1/ticsPerSec
        end
        if currentTime - lastReport > reportInterval then
            if showFPS then
                -- print(tics .. " tics, " .. love.timer.getFPS() .. " fps")
            end
            lastReport = currentTime
            tics = 0
        end
    end
end

function love.keypressed(key, unicode)
    -- if key == "escape" then
    --     love.event.push("quit")
    -- elseif key == "numlock" then
    --     debug.debug()
    --     love.timer.step()
    -- end

    if key == "f11" then
        --love.graphics.toggleFullscreen()

    elseif key == "f2" then
        game.toggleDebug()
    elseif key == "f3" then
        game.restart()

    elseif key == "f4" then
        reloadCode()
    elseif key == "f5" then
        reloadGfx()
    else
        input.keypressed(key, unicode)
    end
end

function love.draw()
    love.graphics.push()
    game.render()
    love.graphics.pop()
end

function reloadCode()
    package.loaded.game = nil
    game = require('game')
end

function reloadGfx()
    package.loaded.gfx = nil
    gfx = require('gfx')
    gfx.init()
end


