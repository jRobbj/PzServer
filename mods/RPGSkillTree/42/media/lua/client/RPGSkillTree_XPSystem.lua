----------------------------------------------------
-- RPG SkillTree XP & Reset System
----------------------------------------------------

local BASE_XP_PER_KILL = 100   -- 좀비 1마리당 XP

-- 🔹 percent(%) 확률로 true 반환 (예: 1 → 1%)
local function RPG_RandomChance(percent)
    return ZombRand(10000) < percent * 100   -- 0.01 * 10000 = 100
end

----------------------------------------------------
-- 🔹 레벨별 필요 경험치 테이블
--   의미: "현재 레벨 L → L+1 에 필요한 XP = LevelXPTable[L+1]"
----------------------------------------------------
LevelXPTable = {
    [1]  = 0,        -- 사용 안함
    [2]  = 500,
    [3]  = 1000,
    [4]  = 2000,
    [5]  = 2500,
    [6]  = 3000,
    [7]  = 3500,
    [8]  = 4000,
    [9]  = 5000,
    [10] = 6500,
    [11] = 8000,
    [12] = 12000,
    [13] = 15000,
    [14] = 19000,
    [15] = 24000,
    [16] = 29250,
    [17] = 35000,
    [18] = 47250,
    [19] = 49500,
    [20] = 54000,
    [21] = 56250,
    [22] = 58500,
    [23] = 63000,
    [24] = 65250,
    [25] = 67500,
    [26] = 69750,
    [27] = 72000,
    [28] = 76500,
    [29] = 78750,
    [30] = 90000,
    [31] = 96750,
    [32] = 99000,
    [33] = 103500,
    [34] = 105750,
    [35] = 108000,
    [36] = 112500,
    [37] = 114750,
    [38] = 117000,
    [39] = 121500,
    [40] = 123750,
    [41] = 126000,
    [42] = 130500,
    [43] = 132750,
    [44] = 135000,
    [45] = 139500,
    [46] = 141750,
    [47] = 146250,
    [48] = 148500,
    [49] = 225000,
    [50] = 227250,
    [51] = 229500,
    [52] = 247500,
    [53] = 252000,
    [54] = 256500,
    [55] = 256500,
    [56] = 261000,
    [57] = 265500,
    [58] = 270000,
    [59] = 274500,
    [60] = 279000,
    [61] = 315000,
    [62] = 360000,
    [63] = 405000,
    [64] = 450000,
    [65] = 495000,
    [66] = 540000,
    [67] = 585000,
    [68] = 630000,
    [69] = 675000,
    [70] = 1350000,
    [71] = 1687500,
    [72] = 2025000,
    [73] = 2362500,
    [74] = 2700000,
    [75] = 3375000,
}



----------------------------------------------------
-- 🔹 전역: 현재 레벨 L에서 다음 레벨까지 필요한 XP
--   L -> L+1 에 필요한 양 = LevelXPTable[L+1]
----------------------------------------------------
function RPG_GetRequiredXP(level)
    if level >= 75 then
        return 999999999 -- 만렙
    end

    local need = LevelXPTable[level + 1]
    if not need then
        return 999999999
    end
    return need
end

----------------------------------------------------
-- 🔹 내부 XP 추가 함수 (player0 기준)
--   + 60,000 XP마다 스킬트리 초기화 포인트 지급
----------------------------------------------------
local RESET_XP_THRESHOLD = 90000   -- 90,000 XP 마다 1포인트

local function RPG_AddXP(amount)
    local player = getSpecificPlayer(0)
    if not player then return end

    local md = player:getModData()

    -- 기본 RPG 스탯
    md.RPG_XP          = md.RPG_XP or 0              -- 현재 레벨에서 쌓인 XP
    md.RPG_Level       = md.RPG_Level or 1
    md.RPGSkillPoints  = md.RPGSkillPoints or 0      -- 스킬 포인트
    md.RPG_XPToNext    = md.RPG_XPToNext or RPG_GetRequiredXP(md.RPG_Level)

    -- 🔹 초기화 포인트 관련 변수
    md.RPG_TotalXP      = md.RPG_TotalXP or 0        -- 총 누적 XP (참고용)
    md.RPG_ResetXPAcc   = md.RPG_ResetXPAcc or 0     -- 90,000 XP 누적 카운터
    md.RPG_ResetPoints  = md.RPG_ResetPoints or 0    -- 스킬트리 초기화 포인트 개수

    ------------------------------------------------
    -- XP 증가
    ------------------------------------------------
    md.RPG_XP        = md.RPG_XP + amount
    md.RPG_TotalXP   = md.RPG_TotalXP + amount
    md.RPG_ResetXPAcc = md.RPG_ResetXPAcc + amount

    ------------------------------------------------
    -- 🔹 90,000 XP마다 스킬트리 초기화 포인트 1개 지급
    ------------------------------------------------
    while md.RPG_ResetXPAcc >= RESET_XP_THRESHOLD do
        md.RPG_ResetXPAcc = md.RPG_ResetXPAcc - RESET_XP_THRESHOLD
        md.RPG_ResetPoints = md.RPG_ResetPoints + 1

        -- 원하는 연출 (말/사운드/로그)
        if player.Say then
            player:Say("You gained a Skill Reset Point!")
        end
        print(string.format("[RPG] Gained Skill Reset Point! Total=%d",
            md.RPG_ResetPoints))
    end

    ------------------------------------------------
    -- 🔥 레벨업 처리 (연속 레벨업도 지원)
    ------------------------------------------------
    while true do
        local need = RPG_GetRequiredXP(md.RPG_Level)

        if need <= 0 then
            md.RPG_XPToNext = 0
            break
        end

        if md.RPG_XP < need then
            md.RPG_XPToNext = need
            break
        end

        -- 레벨업
        md.RPG_XP       = md.RPG_XP - need
        md.RPG_Level    = md.RPG_Level + 1
        md.RPGSkillPoints = md.RPGSkillPoints + 1

        -- 레벨업 대사
        if player.Say then
            player:Say("Level up! Now level " .. tostring(md.RPG_Level) .. "! Press [L] key")
        end

        -- 레벨업 사운드 (sounds.txt에 GainExperienceLevel 정의 필요)
        player:playSound("GainExperienceLevel")

        print(string.format("[RPG] Level Up! Lv=%d, SP=%d",
            md.RPG_Level, md.RPGSkillPoints))
    end

    -- 마지막에 XPToNext 재설정
    md.RPG_XPToNext = RPG_GetRequiredXP(md.RPG_Level)

    ------------------------------------------------
    -- 스킬트리 UI와 동기화
    ------------------------------------------------
    if RPGSkillTreeUI and RPGSkillTreeUI.instance then
        local ui = RPGSkillTreeUI.instance
        ui.skillPoints = md.RPGSkillPoints
        ui.nodeState   = md.RPGSkillNodes or ui.nodeState
    end
end

----------------------------------------------------
-- 🔹 스킬트리 초기화 함수
--   - 초기화 포인트 1개 소모
--   - Start 제외 모든 노드 해제 + 쓴 포인트 환불
----------------------------------------------------
function RPG_ResetSkillTree(playerObj)
    local player = playerObj or getSpecificPlayer(0)
    if not player then return end

    local md = player:getModData()
    md.RPG_ResetPoints = md.RPG_ResetPoints or 0
    md.RPGSkillPoints  = md.RPGSkillPoints or 0
    md.RPGSkillNodes   = md.RPGSkillNodes or {}

    -- 포인트 없으면 실패
    if md.RPG_ResetPoints <= 0 then
        if player.Say then
            player:Say("No Skill Reset Points left.")
        end
        return
    end

    -- 초기화 포인트 1개 소모
    md.RPG_ResetPoints = md.RPG_ResetPoints - 1

    -- 찍었던 노드 개수 계산 + 초기화
    local refunded = 0
    for id, val in pairs(md.RPGSkillNodes) do
        if id ~= "Start" and val == true then
            refunded = refunded + 1
            md.RPGSkillNodes[id] = false
        end
    end

    -- Start 노드는 항상 유지
    md.RPGSkillNodes["Start"] = true

    -- 찍었던 만큼 스킬포인트 환불
    md.RPGSkillPoints = md.RPGSkillPoints + refunded

    -- UI 동기화
    if RPGSkillTreeUI and RPGSkillTreeUI.instance then
        local ui = RPGSkillTreeUI.instance
        ui.skillPoints = md.RPGSkillPoints
        ui.nodeState   = md.RPGSkillNodes
    end
	
    -- 🔥 리셋 후 스킬 효과 다시 계산
    if RPG_UpdateAllSkillEffects then
        RPG_UpdateAllSkillEffects(player)
    end
	
    -- 피드백
    if player.Say then
        player:Say(string.format("Skill tree reset! (%d points refunded)", refunded))
    end

    print(string.format("[RPG] Skill tree reset. Refunded=%d, ResetPointsLeft=%d",
        refunded, md.RPG_ResetPoints))
end

----------------------------------------------------
-- 🔹 리셋 포인트 관련: 남은 XP 조회 헬퍼
--   호출 시: remain, chunk = RPG_GetResetXPRemain(playerObj)
--   remain : 다음 리셋포인트까지 남은 XP
--   chunk  : 1포인트당 기준 XP(지금은 60000)
----------------------------------------------------
function RPG_GetResetXPRemain(playerObj)
    local player = playerObj or getSpecificPlayer(0)
    if not player then
        return RESET_XP_THRESHOLD, RESET_XP_THRESHOLD
    end

    local md = player:getModData()
    md.RPG_ResetXPAcc = md.RPG_ResetXPAcc or 0

    local remain = RESET_XP_THRESHOLD - md.RPG_ResetXPAcc
    if remain < 0 then remain = 0 end

    return remain, RESET_XP_THRESHOLD
end

----------------------------------------------------
-- 🔹 percent(%) 확률로 true 반환 (예: 1 → 1%)
----------------------------------------------------
local function RPG_RandomChance(percent)
    return ZombRand(10000) < percent * 100   -- 0.01 * 10000 = 100
end

----------------------------------------------------
-- 🔹 좀비 사망 시 XP 지급
--   - XP 트리 배수(RPG_ZOMBIE_XP_FACTOR) 적용
--   - XPVer21 : 1% 확률로 25배
--   - XPVer22 : 1% 확률로 50배로 변경
--   - XPVer2Big : 1% 확률로 150배로 변경
----------------------------------------------------
local function OnZombieDead_RPG(zombie)
    if not zombie then return end

    local player = getSpecificPlayer(0)
    if not player then return end
	
    -- 🔹 장비(목걸이 등)에서 오는 XP 보너스를 킬 순간에 다시 계산
    if RPG_UpdateItemXPBonus then
        RPG_UpdateItemXPBonus(player)
	end
	
    local md    = player:getModData()
    md.RPGSkillNodes = md.RPGSkillNodes or {}
    local nodes = md.RPGSkillNodes

    ------------------------------------------------
    -- 1) 기본 XP (XP 트리 배수 적용)
    ------------------------------------------------
    local factor     = RPG_ZOMBIE_XP_FACTOR or 1.0   -- XPgain1~4 / WeaknessDetection 영향
    local baseAmount = BASE_XP_PER_KILL * factor     -- 예: 100 * 2.0 = 200

    ------------------------------------------------
    -- 2) Ver2 노드에 따른 확률 보너스 배수 계산
    --    (더 높은 노드가 있으면 아래 단계 효과를 덮어씀)
    ------------------------------------------------
    local bonusMul = 1  -- 기본은 x1 (보너스 없음)

    if nodes.XPVer2Big then
        -- 최종 노드: 1% 확률로 150배
        bonusMul = 150
    elseif nodes.XPVer22 then
        -- 2단계: 1% 확률로 50배
        bonusMul = 50
    elseif nodes.XPVer21 then
        -- 1단계: 1% 확률로 25배
        bonusMul = 25
    end

    ------------------------------------------------
    -- 3) 1% 확률 체크
    ------------------------------------------------
    local finalAmount = baseAmount

    if bonusMul > 1 and RPG_RandomChance(1) then
        finalAmount = baseAmount * bonusMul

        -- 피드백 (말풍선)
        if player.Say then
            player:Say(string.format("Lucky XP! x%d", bonusMul))
        end
    end
	
	-- 아이템 XP 곱연산
	local imul = RPG_ITEM_XP_FACTOR or 1.0
	finalAmount = finalAmount * imul

    -----------------------------------------------
    -- 4) 최종 XP 지급 (레벨 / 리셋 포인트 시스템으로 들어감)
    ------------------------------------------------
    RPG_AddXP(finalAmount)
end

Events.OnZombieDead.Add(OnZombieDead_RPG)


