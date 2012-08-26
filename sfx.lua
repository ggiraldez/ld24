sfx = {}

function sfx.load()
    sfx.hit = love.sound.newSoundData("assets/hit.wav")
    sfx.hurt = love.sound.newSoundData("assets/hurt.wav")
    sfx.death = love.sound.newSoundData("assets/death.wav")
    sfx.kill = love.sound.newSoundData("assets/kill.wav")
    sfx.levelup = love.sound.newSoundData("assets/levelup.wav")
    sfx.pickup = love.sound.newSoundData("assets/pickup.wav")
    sfx.newseg = love.sound.newSoundData("assets/newsegment.wav")
end

function sfx.play(sample, quiet)
    local data = sfx[sample]
    if data then
        local source = love.audio.newSource(data)
        if quiet then
            source:setVolume(0.5)
        end
        source:play()
    end
end

function sfx.init()
    print("Loading sounds")
    sfx.load()
end

return sfx

