--=========================================================
-- 🔥 공황(Panic) 상승량 감소 (B42.13 + 멀티 대응)
--   - PANIC 값이 "올라갈 때"만 상승량을 줄인다.
--   - 공황이 내려갈 때(회복)는 그대로 둔다.
--   - 값 범위: 0 ~ 100
--=========================================================

-- 스킬트리에서 바꾸기 쉽도록 전역 변수로 둠
RPG_PANIC_GAIN_FACTOR = RPG_PANIC_GAIN_FACTOR or 1.0
-- 1.0 = 원래대로 상승
-- 0.7 = 상승량 30% 감소
-- 0.5 = 상승량 50% 감소

-- 플레이어별 마지막 공황 값 저장용
local lastPanic = {}

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
    -- 최후 fallback
    return 0
end

local function panicGainReducer(player)
    if not player then return end
    if player.isDead and player:isDead() then return end

    local stats = player.getStats and player:getStats() or nil
    if not stats or not stats.get or not stats.set then return end

    -- B42.13: CharacterStat.PANIC 사용 (0 ~ 100)
    local current = stats:get(CharacterStat.PANIC)
    if current == nil then return end

    local key = getPlayerKey(player)

    -- 첫 프레임이면 기준값만 저장하고 종료
    if lastPanic[key] == nil then
        lastPanic[key] = current
        return
    end

    -- 이번 프레임 공황 변화량
    local prev     = lastPanic[key]
    local change   = current - prev
    local newPanic = current

    ------------------------------------------------------------
    -- 🔻 공황이 "올라갈 때"만 상승량을 줄인다
    ------------------------------------------------------------
    if change > 0 then
        local gain   = change
        local factor = RPG_PANIC_GAIN_FACTOR or 1.0

        -- factor < 1.0 이면 덜 오른다
        local newGain = gain * factor
        newPanic      = prev + newGain

    ------------------------------------------------------------
    -- 🔺 공황이 "내려갈 때"는 건드리지 않는다
    ------------------------------------------------------------
    else
        -- 회복/유지 구간은 건드리지 않고 current 그대로
        newPanic = current
    end
    -- change == 0 이면 newPanic = current 그대로 유지

    -- 범위 제한 (0 ~ 100)
    if newPanic < 0   then newPanic = 0   end
    if newPanic > 100 then newPanic = 100 end

    stats:set(CharacterStat.PANIC, newPanic)
    lastPanic[key] = newPanic
end

Events.OnPlayerUpdate.Add(panicGainReducer)
