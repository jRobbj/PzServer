--===============================================================
-- 🔥 스태미나(Endurance) 소모량 감소 (스킬트리 연동 버전)
--   - 스태미나가 감소할 때만 소모량을 줄인다.
--   - 회복 구간은 건드리지 않는다.
--   - B42.13: CharacterStat.ENDURANCE (0.0 ~ 1.0) 사용
--   - 멀티 대응: 플레이어별 lastEndurance 분리
--===============================================================

RPG_STAMINA_DRAIN_FACTOR = RPG_STAMINA_DRAIN_FACTOR or 1.0
-- 1.0 = 감소 없음
-- 0.7 = 30% 감소
-- 0.5 = 50% 감소

-- 플레이어별 마지막 Endurance 저장용
local lastEndurance = {}

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

local function staminaDrainReducer(player)
    if not player then return end
    if player.isDead and player:isDead() then return end

    local stats = player.getStats and player:getStats() or nil
    if not stats or not stats.get or not stats.set then return end

    -- B42.13: CharacterStat.ENDURANCE (0.0 ~ 1.0)
    local current = stats:get(CharacterStat.ENDURANCE)
    if current == nil then return end

    local key = getPlayerKey(player)

    -- 첫 프레임 초기화
    if lastEndurance[key] == nil then
        lastEndurance[key] = current
        return
    end

    local prev  = lastEndurance[key]
    local delta = prev - current  -- 양수면 감소한 양

    -- 감소한 경우만 소모량 감소 적용
    if delta > 0 then
        local factor = RPG_STAMINA_DRAIN_FACTOR or 1.0
        -- factor < 1.0 이면 일부를 환불해서 실제 소모량을 줄인다
        local refund = delta * (1.0 - factor)
        local newVal = current + refund

        if newVal > 1 then newVal = 1 end
        if newVal < 0 then newVal = 0 end

        stats:set(CharacterStat.ENDURANCE, newVal)
        current = newVal
    end

    -- 다음 프레임 기준값 갱신 (플레이어별)
    lastEndurance[key] = current
end

Events.OnPlayerUpdate.Add(staminaDrainReducer)
