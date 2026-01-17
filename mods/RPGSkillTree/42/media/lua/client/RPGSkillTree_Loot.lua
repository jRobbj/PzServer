----------------------------------------------------
-- RPG SkillTree Extra Loot System
----------------------------------------------------

-- percent(0.0~1.0) 확률로 true
local function RPG_RollChance01(p)
    if not p or p <= 0 then return false end
    if p >= 1 then return true end
    return ZombRandFloat(0.0, 1.0) < p
end

-- 컨테이너 채워질 때 추가 루팅
local function RPG_ExtraLoot_OnFill(roomName, containerType, container)
    if not container then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    -- 스킬트리 루팅 확률
    local chance = RPG_LOOT_EXTRA_CHANCE or 0.0
    if chance <= 0 then return end

    -- 확률 실패하면 아무 일도 안 함
    if not RPG_RollChance01(chance) then
        return
    end

    -- 이미 들어있는 아이템 중 하나를 랜덤으로 골라서 복사
    local items = container:getItems()
    if items:isEmpty() then return end

    local idx  = ZombRand(items:size())
    local item = items:get(idx)
    if not item then return end

    container:AddItem(item:getFullType())

    -- 피드백(원하면 주석 풀기)
    -- print(string.format("[RPG] Extra loot! (%s)", item:getFullType()))
end

Events.OnFillContainer.Add(RPG_ExtraLoot_OnFill)
