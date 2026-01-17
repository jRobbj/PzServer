--=========================================================
-- 🍗 배고픔(Hunger) 증가량 감소 (B42.13 + 멀티 대응)
--   - HUNGER 값이 올라갈 때만 증가량을 줄인다.
--   - 내려갈 때(배고픔 해소)는 건드리지 않는다.
--   - 값 범위: 0 ~ 100 (값이 클수록 더 배고픔)
--=========================================================

-- 스킬트리에서 조정할 전역 배수
RPG_HUNGER_GAIN_FACTOR = RPG_HUNGER_GAIN_FACTOR or 1.0
-- 1.0 = 원래대로 증가
-- 0.7 = 증가량 30% 감소
-- 0.5 = 증가량 50% 감소

-- 플레이어별 마지막 배고픔 값 저장용
local lastHunger = {}

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

local function hungerGainReducer(player)
    if not player then return end
    if player.isDead and player:isDead() then return end

    local stats = player.getStats and player:getStats() or nil
    if not stats or not stats.get or not stats.set then return end

    -- B42.13: CharacterStat.HUNGER 사용 (0 ~ 100)
    local current = stats:get(CharacterStat.HUNGER)
    if current == nil then return end

    local key = getPlayerKey(player)

    -- 첫 프레임이면 기준값만 저장하고 끝
    if lastHunger[key] == nil then
        lastHunger[key] = current
        return
    end

    local prev      = lastHunger[key]
    local change    = current - prev
    local newHunger = current

    --------------------------------------------------------
    -- 🔻 배고픔이 "늘어나는 중"일 때만 증가량을 줄인다
    --------------------------------------------------------
    if change > 0 then
        local gain   = change
        local factor = RPG_HUNGER_GAIN_FACTOR or 1.0

        -- factor < 1.0 이면 덜 오른다
        local newGain = gain * factor
        newHunger = prev + newGain

    --------------------------------------------------------
    -- 🔺 배고픔이 줄어들거나 그대로면 그대로 둔다
    --------------------------------------------------------
    else
        newHunger = current
    end

    -- 범위 제한 (0 ~ 100)
    if newHunger < 0   then newHunger = 0   end
    if newHunger > 100 then newHunger = 100 end

    stats:set(CharacterStat.HUNGER, newHunger)
    lastHunger[key] = newHunger
end

Events.OnPlayerUpdate.Add(hungerGainReducer)
