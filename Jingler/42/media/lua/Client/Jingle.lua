-- Configuration Constants
local SCAN_INTERVAL = 1.0                  -- How often to scan movement (in seconds)
local JINGLE_COOLDOWN = 40.0               -- Cooldown between jingles (in seconds)
local JINGLE_CHANCE_BASE = 0.05            -- Base chance to jingle per tick
local JINGLE_CHANCE_RUNNING_MULTIPLIER = 2.0
local JINGLE_CHANCE_SPRINTING_MULTIPLIER = 9.0

-- Internal State
local timeAccum = 0.0
local jingleCooldown = 0.0
local jingleAction = nil

-- TAJingleSoundAction Class
TAJingleSoundAction = {}
TAJingleSoundAction.__index = TAJingleSoundAction

function TAJingleSoundAction:new(character)
    local obj = {
        character = character,
        lastX = nil,
        lastY = nil,
        lastZ = nil
    }
    setmetatable(obj, self)
    return obj
end

-- Count total keys in all key rings
function TAJingleSoundAction:getKeyCount()
    local inventory = self.character:getInventory()
    local totalKeys = 0

    for i = 0, inventory:getItems():size() - 1 do
        local item = inventory:getItems():get(i)
        if item:getType() == "KeyRing" then
            local ringInventory = item:getInventory()
            if ringInventory then
                totalKeys = totalKeys + (ringInventory:getItems():size() - 1)
            end
        end
    end

    return totalKeys
end

-- Play a jingle sound based on key count
function TAJingleSoundAction:playJingle()
    local keyCount = self:getKeyCount()
    if keyCount <= 0 then return end

    local soundManager = getSoundManager()
    if not soundManager then return end

    local volume = math.min(keyCount * 0.01, 1.0)
    local soundIndex = ZombRand(1, 16)
    local soundName = "jingle_" .. soundIndex
    local square = self.character:getSquare()
    local radius = 8

    --print(string.format("JINGLE → %s @ vol %.2f, radius %d", soundName, volume, radius))
    soundManager:setSoundVolume(volume)
    soundManager:PlayWorldSound(soundName, false, square, radius, volume, 1, false)

    jingleCooldown = JINGLE_COOLDOWN
end

-- Check if the character is moving and maybe trigger a jingle
function TAJingleSoundAction:checkPlayerMovement(delta)
    if not self.character or self.character:isDead() then return end

    local currentX = self.character:getX()
    local currentY = self.character:getY()
    local currentZ = self.character:getZ()

    -- Initialize last known position
    if not self.lastX or not self.lastY or not self.lastZ then
        self.lastX = currentX
        self.lastY = currentY
        self.lastZ = currentZ
        return
    end

    -- Determine if the player actually moved
    local moved = (currentX ~= self.lastX) or (currentY ~= self.lastY) or (currentZ ~= self.lastZ)

    -- Save current position for next tick
    self.lastX = currentX
    self.lastY = currentY
    self.lastZ = currentZ

    if not moved then return end

    local walking = self.character:isWalking()
    local running = self.character:isRunning()
    local sprinting = self.character:isSprinting()

    local keyCount = self:getKeyCount()
    local chance = JINGLE_CHANCE_BASE * (keyCount * 0.25)

    if sprinting then
        chance = chance * JINGLE_CHANCE_SPRINTING_MULTIPLIER
    elseif running then
        chance = chance * JINGLE_CHANCE_RUNNING_MULTIPLIER
    end

    if (walking or running or sprinting) and jingleCooldown <= 0 and ZombRandFloat(0, 1) < chance then
        self:playJingle()
    end
end

-- Main Update Tick
Events.OnTick.Add(function(delta)
    timeAccum = timeAccum + delta
    if jingleCooldown > 0 then
        jingleCooldown = jingleCooldown - delta
    end

    if timeAccum >= SCAN_INTERVAL then
        timeAccum = timeAccum - SCAN_INTERVAL

        if not jingleAction then
            jingleAction = TAJingleSoundAction:new(getPlayer())
        end

        jingleAction:checkPlayerMovement(delta)
    end
end)
