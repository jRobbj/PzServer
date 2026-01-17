---------------------------------------------------------
-- 🔹 Work1 / Work2 / Work3 기반 작업 속도 증가
---------------------------------------------------------

local function RPG_QuickWorkerFromSkills(player)
    if not player or player:isDead() then return end

    -------------------------------------------------
    -- 1) Work 스킬 노드 찍었는지 확인
    -------------------------------------------------
    local md = player:getModData()
    md.RPGSkillNodes = md.RPGSkillNodes or {}
    local nodes = md.RPGSkillNodes

    local workLevel = 0
    if nodes.Work1 then workLevel = workLevel + 1 end
    if nodes.Work2 then workLevel = workLevel + 1 end
    if nodes.Work3 then workLevel = workLevel + 1 end

    -- 하나도 안 찍혀 있으면 빠르게 리턴
    if workLevel <= 0 then
        return
    end

    -------------------------------------------------
    -- 2) 현재 타임드 액션 있는지 확인
    -------------------------------------------------
    if not player:hasTimedActions() then
        return
    end

    local actions = player:getCharacterActions()
    if not actions or actions:isEmpty() then
        return
    end

    local action = actions:get(0)
    if not action then
        return
    end

    local typeName  = action:getMetaType()
    local delta     = action:getJobDelta()
    local multiplier = getGameTime():getMultiplier() or 1.0

    -------------------------------------------------
    -- 3) 블랙리스트 액션은 건드리지 않기
    -------------------------------------------------
    local blacklist = { "ISWalkToTimedAction", "ISPathFindAction", "PlayInstrumentAction", "" }


    if tableContains and tableContains(blacklist, typeName) then
        return
    end

    -- 아직 진행이 0 이면(시작 안 됐으면) 건드리지 않음
    if delta <= 0 then
        return
    end

    -------------------------------------------------
    -- 4) 스킬 레벨 기반 속도 보정치 계산
    --    - 우리는 Work1/2/3 개수에 비례시킴
    --
    --    예시:
    --      Work1   만 찍음 → 0.5
    --      Work1+2       → 1.0
    --      Work1+2+3     → 1.5  (가장 빠름)
    -------------------------------------------------
    local modifier = 0.5 * workLevel

    if modifier < 0 then
        modifier = 0
    end

    -------------------------------------------------
    -- 5) 너무 크게 한번에 점프해서 1.0 넘어가지 않도록
    -------------------------------------------------
    if delta < 0.99 - (modifier * 0.01) then
        -- 현재 시간에 (modifier * 게임속도배수) 만큼 더해준다
        action:setCurrentTime(action:getCurrentTime() + modifier * multiplier)
    end
end

---------------------------------------------------------
-- 🔹 이벤트에 연결: 매 틱마다 호출해서 작업 속도 보정
---------------------------------------------------------
local function RPG_OnPlayerUpdate_QuickWorker(player)
    RPG_QuickWorkerFromSkills(player)
end

Events.OnPlayerUpdate.Add(RPG_OnPlayerUpdate_QuickWorker)
