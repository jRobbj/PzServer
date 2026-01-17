--=========================================================
-- 💧 목마름(Thirst) 증가량 감소 (B42.13 + 멀티 대응)
--   - THIRST 값이 올라갈 때만 증가량을 줄인다.
--   - 내려갈 때(갈증 해소)는 건드리지 않는다.
--   - 값 범위: 0 ~ 100 (값이 클수록 더 목마름)
--=========================================================

-- 스킬트리에서 조정할 전역 배수
RPG_THIRST_GAIN_FACTOR = RPG_THIRST_GAIN_FACTOR or 1.0
-- 1.0 = 원래대로 증가
-- 0.7 = 증가량 30% 감소
-- 0.5 = 증가량 50% 감소 (체감 강하게)

-- 플레이어별 마지막 목마름 값 저장용
local lastThirst = {}

local function getPlayerKey(player)
    -- 멀티 대비: OnlineID가 있으면 그걸 우선 사용
    if player.getOnlineID then
        local id = player:getOnlineID()
        if id and id ~= -1 then
            return id
        end
    end
    -- 아니면 로컬 플레이어 번호 사용
    if player.getPlayerNum then
        return player:getPlayerNum()
    end
    -- 최후 fallback
    return 0
end

local function thirstGainReducer(player)
    if not player then return end
    if player.isDead and player:isDead() then return end

    local stats = player.getStats and player:getStats() or nil
    if not stats or not stats.get or not stats.set then return end

    -- B42.13: CharacterStat.THIRST 사용 (0 ~ 100)
    local current = stats:get(CharacterStat.THIRST)
    if current == nil then return end

    local key = getPlayerKey(player)

    -- 첫 프레임이면 기준값만 저장하고 종료
    if lastThirst[key] == nil then
        lastThirst[key] = current
        return
    end

    local prev      = lastThirst[key]
    local change    = current - prev
    local newThirst = current

    --------------------------------------------------------
    -- 🔻 목마름이 "늘어나는 중"일 때만 증가량을 줄인다
    --------------------------------------------------------
    if change > 0 then
        local gain   = change
        local factor = RPG_THIRST_GAIN_FACTOR or 1.0

        -- factor < 1.0 이면 덜 오른다
        local newGain = gain * factor
        newThirst = prev + newGain

    --------------------------------------------------------
    -- 🔺 목마름이 줄어들거나 그대로면 그대로 둔다
    --------------------------------------------------------
    else
        newThirst = current
    end

    -- 범위 제한 (0 ~ 100)
    if newThirst < 0   then newThirst = 0   end
    if newThirst > 100 then newThirst = 100 end

    stats:set(CharacterStat.THIRST, newThirst)
    lastThirst[key] = newThirst
end

Events.OnPlayerUpdate.Add(thirstGainReducer)
