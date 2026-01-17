--===============================================================
-- 😄 우울(불행) 회복 스킬 - TrainingOptimism 전용
--    - B42.13 대응: CharacterStat.UNHAPPINESS 사용 (0 ~ 100)
--    - RPG_UNHAPPY_RECOVERY_RATE 는 "시간당 회복량"
--      (예: 30.0 → 게임시간 1시간에 30 감소)
--    - 시간 압축(배속) 포함된 getWorldAgeHours() 기반
--===============================================================

-- Effects 쪽에서 nodes.TrainingOptimism 등에 따라 세팅:
--   RPG_UNHAPPY_RECOVERY_RATE = 0.0 (기본)
--   if nodes.TrainingOptimism then
--       RPG_UNHAPPY_RECOVERY_RATE = 30.0
--   end
RPG_UNHAPPY_RECOVERY_RATE = RPG_UNHAPPY_RECOVERY_RATE or 0.0

-- 마지막으로 불행을 갱신한 게임 시간(월드 시간, 시간 단위)
local RPG_LastUnhappyUpdateTime = 0

local function UnhappyRecoverySkill(player)
    if not player or (player.isDead and player:isDead()) then
        return
    end

    -------------------------------------------------
    -- 멀티 대비: 로컬 플레이어만 처리 (싱글이면 0번만)
    -------------------------------------------------
    local p0 = getSpecificPlayer and getSpecificPlayer(0) or nil
    if not p0 or player ~= p0 then
        return
    end

    -------------------------------------------------
    -- 1) 스킬트리에서 계산된 회복 속도 읽기
    --    - 0 이하이면 스킬 미적용 상태로 보고 종료
    -------------------------------------------------
    local rate = _G.RPG_UNHAPPY_RECOVERY_RATE or 0.0
    if rate <= 0 then
        return
    end

    -------------------------------------------------
    -- 2) 게임 시간(월드 시간, 시간 단위) 계산
    -------------------------------------------------
    local gt = getGameTime and getGameTime() or nil
    if not gt then return end

    local now = gt:getWorldAgeHours()  -- 예: 0.5 = 30분 경과
    if RPG_LastUnhappyUpdateTime == 0 then
        RPG_LastUnhappyUpdateTime = now
        return
    end

    local dt = now - RPG_LastUnhappyUpdateTime
    if dt <= 0 then
        return
    end

    RPG_LastUnhappyUpdateTime = now

    -------------------------------------------------------
    -- dt = 지난 "게임 시간" (시간 단위, 배속 포함)
    -- rate = "시간당 회복량"
    -- 실제 회복량 = rate * dt
    -------------------------------------------------------
    local stats = player.getStats and player:getStats() or nil
    if not stats or not stats.get or not stats.set then return end

    -- 0 ~ 100 스케일의 불행 값
    local unh = stats:get(CharacterStat.UNHAPPINESS)
    if type(unh) ~= "number" then
        return
    end
    if unh <= 0 then
        return
    end

    local recover = rate * dt
    local newUnh = unh - recover
    if newUnh < 0   then newUnh = 0   end
    if newUnh > 100 then newUnh = 100 end

    stats:set(CharacterStat.UNHAPPINESS, newUnh)
end

Events.OnPlayerUpdate.Add(UnhappyRecoverySkill)
