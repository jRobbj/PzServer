--=========================================================
-- 🔥 스트레스(Stress) 증가량 감소 (B42.13 + 멀티 대응)
--   - STRESS 값이 "올라갈 때"만 상승량을 줄인다.
--   - 내려갈 때(회복)는 건드리지 않는다.
--   - 값 범위: 0 ~ 100
--=========================================================

-- 스킬트리에서 바꾸기 쉽도록 전역 변수로 둔다.
RPG_STRESS_GAIN_FACTOR = RPG_STRESS_GAIN_FACTOR or 1.0
-- 1.0 = 원래대로 상승
-- 0.7 = 상승량 30% 감소
-- 0.5 = 상승량 50% 감소

-- 플레이어별 마지막 스트레스 값 저장용
local lastStress = {}

local function getPlayerKey(player)
    -- 멀티 대비: OnlineID 우선
    if player.getOnlineID then
        local id = player:getOnlineID()
        if id and id ~= -1 then
            return id
        end
    end
    -- 없으면 로컬 플레이어 번호
    if player.getPlayerNum then
        return player:getPlayerNum()
    end
    -- 최후의 fallback
    return 0
end

local function stressGainReducer(player)
    if not player then return end
    if player.isDead and player:isDead() then return end

    local stats = player.getStats and player:getStats() or nil
    if not stats or not stats.get or not stats.set then return end

    -- B42.13: CharacterStat.STRESS 사용 (0 ~ 100 가정)
    local current = stats:get(CharacterStat.STRESS)
    if current == nil then return end

    local key = getPlayerKey(player)

    -- 첫 프레임이면 기준값만 저장하고 종료
    if lastStress[key] == nil then
        lastStress[key] = current
        return
    end

    -- 이번 프레임 스트레스 변화량
    local prev      = lastStress[key]
    local change    = current - prev
    local newStress = current

    ------------------------------------------------------------
    -- 🔻 스트레스가 "올라갈 때"만 상승량을 줄인다
    ------------------------------------------------------------
    if change > 0 then
        local gain   = change
        local factor = RPG_STRESS_GAIN_FACTOR or 1.0

        -- factor < 1.0 이면 덜 오른다
        local newGain = gain * factor
        newStress = prev + newGain

    ------------------------------------------------------------
    -- 🔺 스트레스가 "내려갈 때"는 건드리지 않는다
    ------------------------------------------------------------
    else
        -- 회복/유지 구간은 그대로 둔다
        newStress = current
    end

    -- 범위 제한 (0 ~ 100)
    if newStress < 0   then newStress = 0   end
    if newStress > 100 then newStress = 100 end

    stats:set(CharacterStat.STRESS, newStress)
    lastStress[key] = newStress
end

Events.OnPlayerUpdate.Add(stressGainReducer)
