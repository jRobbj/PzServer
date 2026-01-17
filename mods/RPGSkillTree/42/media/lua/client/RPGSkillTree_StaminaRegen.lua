--===============================================================
-- 🔥 스태미나(Endurance) 회복 속도 조절 (B42.13 + 멀티 대응)
--     - 스태미나가 줄어드는(소모) 구간은 그대로 두고
--       스태미나가 늘어나는(회복) 구간에만 배수를 건다.
--     - CharacterStat.ENDURANCE 사용 (0.0 ~ 1.0)
--===============================================================

-- 스킬트리에서 조정할 전역 배율
-- 1.0 = 기본 회복 속도
-- 1.2 = 20% 더 빠른 회복
-- 0.8 = 20% 느린 회복
RPG_STAMINA_REGEN_FACTOR = RPG_STAMINA_REGEN_FACTOR or 1.0

-- 플레이어별 마지막 Endurance 저장용
local lastEndurance = {}

local function getPlayerKey(player)
    -- 멀티 대비: OnlineID 우선 사용
    if player.getOnlineID then
        local id = player:getOnlineID()
        if id and id ~= -1 then
            return id
        end
    end
    -- 없으면 로컬 플레이어 번호 사용
    if player.getPlayerNum then
        return player:getPlayerNum()
    end
    -- 최후의 fallback
    return 0
end

local function staminaRegenModifier(player)
    if not player then return end
    if player.isDead and player:isDead() then return end

    local stats = player.getStats and player:getStats() or nil
    if not stats or not stats.get or not stats.set then return end

    -- B42.13: CharacterStat.ENDURANCE (0.0 ~ 1.0)
    local current = stats:get(CharacterStat.ENDURANCE)
    if current == nil then return end

    local key = getPlayerKey(player)

    ------------------------------------------------------------
    -- 첫 프레임이면 기준값만 저장하고 종료
    ------------------------------------------------------------
    if lastEndurance[key] == nil then
        lastEndurance[key] = current
        return
    end

    ------------------------------------------------------------
    -- 이번 프레임에서 얼마나 변했는지 계산
    ------------------------------------------------------------
    local prev         = lastEndurance[key]
    local change       = current - prev
    local newEndurance = current

    ------------------------------------------------------------
    -- 🔻 스태미나가 감소한 경우 (소모 구간)
    --     → 소모는 건드리지 않고 그대로 둔다.
    ------------------------------------------------------------
    if change < 0 then
        newEndurance = current

    ------------------------------------------------------------
    -- 🔺 스태미나가 증가한 경우 (회복 구간)
    --     → 여기만 회복 배율을 적용한다.
    ------------------------------------------------------------
    elseif change > 0 then
        local gain        = change
        local regenFactor = RPG_STAMINA_REGEN_FACTOR or 1.0

        local newGain     = gain * regenFactor
        newEndurance      = prev + newGain
    end

    ------------------------------------------------------------
    -- 0~1 범위로 클램프 후 적용
    ------------------------------------------------------------
    if newEndurance > 1 then newEndurance = 1 end
    if newEndurance < 0 then newEndurance = 0 end

    stats:set(CharacterStat.ENDURANCE, newEndurance)

    -- 다음 프레임 기준값 갱신 (플레이어별)
    lastEndurance[key] = newEndurance
end

----------------------------------------------------------------
-- 매 프레임 실행 (멀티에서도 각 player 콜백으로 들어옴)
----------------------------------------------------------------
Events.OnPlayerUpdate.Add(staminaRegenModifier)
