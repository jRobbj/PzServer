local function isZombieBehindTarget(player, target)
    if not player or not target then
        return false
    end

    local forward = target:getForwardDirection()
    if not forward then
        return false
    end

    local dx = player:getX() - target:getX()
    local dy = player:getY() - target:getY()
    local distance = math.sqrt((dx * dx) + (dy * dy))

    if distance <= 0 then
        return false
    end

    local toPlayerX = dx / distance
    local toPlayerY = dy / distance

    local dot = (forward:x() * toPlayerX) + (forward:y() * toPlayerY)

    return dot < -0.5
end

local function shouldNeckSnap(attacker, target)
    if not attacker or not target then
        return false
    end

    if not instanceof(attacker, "IsoPlayer") then
        return false
    end

    if not instanceof(target, "IsoZombie") then
        return false
    end

    if attacker:isDead() or target:isDead() then
        return false
    end

    local isSneaking = false
    if attacker.isSneaking and attacker:isSneaking() then
        isSneaking = true
    elseif attacker.isCrouching and attacker:isCrouching() then
        isSneaking = true
    end

    if not isSneaking then
        return false
    end

    return isZombieBehindTarget(attacker, target)
end

local function onWeaponHitCharacter(attacker, target, weapon, damage)
    if shouldNeckSnap(attacker, target) then
        target:Kill(attacker)
    end
end

Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
