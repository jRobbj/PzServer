---------------------------------------------------------
-- 🔹 Accumulated Power 발동 로직
--   - 스킬트리 노드 AccumulatedPower를 찍었을 때만 동작
--   - "좀비들에게 둘러싸이거나(여럿 가까이 있음) 끌려갈 상황"에서 발동
--   - 주변 좀비 넉다운 + 1일(24시간) 쿨타임
---------------------------------------------------------

local function RPG_AccumulatedPower_TryActivate(player)
    if not player then return end

    local md = player:getModData()
    md.RPGSkillNodes = md.RPGSkillNodes or {}
    local nodes = md.RPGSkillNodes

    -------------------------------------------------
    -- 1) 노드를 안 찍었으면 아예 무시
    -------------------------------------------------
    if not nodes.AccumulatedPower then
        return
    end

    -------------------------------------------------
    -- 2) 쿨타임 상태면 발동 불가
    -------------------------------------------------
    md.RPG_AP_OnCooldown      = md.RPG_AP_OnCooldown      or false
    md.RPG_AP_CooldownHours   = md.RPG_AP_CooldownHours   or 0
    md.RPG_AP_RechargeHours   = md.RPG_AP_RechargeHours   or 24  -- 1일 = 24시간

    if md.RPG_AP_OnCooldown then
        return
    end

    -------------------------------------------------
    -- 3) “위기 상황인지” 체크
    --    - 체력이 아주 낮거나
    --    - Death Drag Down 중이거나
    --    - 주변에 가까운 좀비가 여러 마리 있을 때
    -------------------------------------------------
    local body = player:getBodyDamage()
    local healthLow = body:getHealth() < 15
    local beingDragged = player:isDeathDragDown()

    -- 주변 감지
    local enemies = player:getSpottedList()
    local surrounded = false
    local nearCount  = 0

    if enemies and enemies:size() > 0 then
        for i = 0, enemies:size() - 1 do
            local e = enemies:get(i)
            if e and e:isZombie() then
                if e:DistTo(player) <= 2.5 then
                    nearCount = nearCount + 1
                end
            end
        end
    end

    -- 예: 주변 3마리 이상 근접 → 둘러싸인 걸로 판단
    if nearCount >= 3 then
        surrounded = true
    end

    -------------------------------------------------
    -- 4) 실제 발동 조건:
    --    체력 낮음 / 끌려가는 중 / 둘러싸임 중 하나라도 충족
    -------------------------------------------------
    if not (healthLow or beingDragged) then
        return
    end

    -------------------------------------------------
    -- 5) 발동 처리
    -------------------------------------------------

    -- (1) 끌려가는 중이면 해제
    if player:isDeathDragDown() then
        md.RPG_AP_DraggedDown = true  -- 원하면 쿨타임 늘릴 때 쓸 수 있음
        player:setPlayingDeathSound(false)
        player:setDeathDragDown(false)
        player:setHitReaction("EvasiveBlocked")
    end

    -- (2) 주변 좀비 넉다운
    if enemies and enemies:size() > 0 then
        for i = 0, enemies:size() - 1 do
            local z = enemies:get(i)
            if z and z:isZombie() then
                if z:DistTo(player) <= 10 then
                    z:setStaggerBack(true)
                    z:setKnockedDown(true)
                end
            end
        end
    end

    -- (3) 쿨타임 시작
    md.RPG_AP_OnCooldown    = true
    md.RPG_AP_CooldownHours = 0

    -- (4) 연출
    if HaloTextHelper then
        HaloTextHelper.addTextWithArrow(
            player,
            getText("UI_RPG_AccumulatedPower") or "Accumulated Power",
            true,
            HaloTextHelper.getColorGreen()
        )
    end

    if player.Say then
        player:Say("Accumulated Power activated!")
    end
end

---------------------------------------------------------
-- 🔹 Accumulated Power 쿨타임 카운터
--   - EveryHours 이벤트에 연결해서 1시간마다 호출
--   - 24시간 지나면 쿨타임 해제
---------------------------------------------------------

local function RPG_AccumulatedPower_Counter()
    local player = getSpecificPlayer(0) or getPlayer()
    if not player then return end

    local md = player:getModData()
    md.RPGSkillNodes = md.RPGSkillNodes or {}
    local nodes = md.RPGSkillNodes

    -- 스킬 노드를 안 찍었으면 쿨타임도 아무 의미 없음
    if not nodes.AccumulatedPower then
        md.RPG_AP_OnCooldown    = false
        md.RPG_AP_CooldownHours = 0
        return
    end

    md.RPG_AP_OnCooldown    = md.RPG_AP_OnCooldown    or false
    md.RPG_AP_CooldownHours = md.RPG_AP_CooldownHours or 0
    md.RPG_AP_RechargeHours = md.RPG_AP_RechargeHours or 24   -- 1일

    if not md.RPG_AP_OnCooldown then
        return
    end

    local recharge = md.RPG_AP_RechargeHours

    -- 🔹 쿨타임이 다 찼으면 초기화
    if md.RPG_AP_CooldownHours >= recharge then
        md.RPG_AP_CooldownHours = 0
        md.RPG_AP_OnCooldown    = false
        md.RPG_AP_DraggedDown   = false

        if player.Say then
            player:Say("Accumulated Power is ready again.")
        end
    else
        -- 🔹 아직이면 1시간 증가
        md.RPG_AP_CooldownHours = md.RPG_AP_CooldownHours + 1
    end
end

---------------------------------------------------------
-- 🔹 Accumulated Power: 남은 쿨타임 조회 함수
---------------------------------------------------------
function RPG_GetAccumulatedPowerCooldownRemain(player)
    if not player then return 0 end

    local md = player:getModData()
    md.RPG_AP_OnCooldown    = md.RPG_AP_OnCooldown    or false
    md.RPG_AP_CooldownHours = md.RPG_AP_CooldownHours or 0
    md.RPG_AP_RechargeHours = md.RPG_AP_RechargeHours or 24

    if not md.RPG_AP_OnCooldown then
        return 0
    end

    local remain = md.RPG_AP_RechargeHours - md.RPG_AP_CooldownHours
    if remain < 0 then remain = 0 end

    return remain
end

---------------------------------------------------------
-- 🔹 이벤트 연결
---------------------------------------------------------

-- 위기 상황을 계속 감지해서 발동시키는 부분 (매 틱/매 프레임)
local function RPG_OnPlayerUpdate_AccumulatedPower(player)
    RPG_AccumulatedPower_TryActivate(player)
end

Events.OnPlayerUpdate.Add(RPG_OnPlayerUpdate_AccumulatedPower)

-- 쿨타임 카운터 (매 게임 시간 1시간마다)
Events.EveryHours.Add(RPG_AccumulatedPower_Counter)

