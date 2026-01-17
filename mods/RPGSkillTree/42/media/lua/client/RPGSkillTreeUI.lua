require "ISUI/ISPanel" --ISUI/ISPanel 의 파일을 Import한다.
require "ISUI/ISButton"
require "RPGSkillTree_Effects"
RPGSkillTreeUI = ISPanel:derive("RPGSkillTreeUI") --ISPanel을 기반으로 한 새 UI타입, 이름은 RPGSkillTreeUI라고 하겠다.
RPGSkillTreeUI.instance = nil --지금 스킬트리 창이 열려있는지 저장하는 변수 (처음엔 nil=없음)
local StartNodeTexture = "media/ui/RPGSkillTree/RPG_Start.png"   -- 시작 노드 텍스처
local MAX_PAN = 2000  -- X/Y 방향으로 최대 이동 허용량 (필요하면 숫자 줄이거나 키워도 됨)
local RESET_XP_CHUNK = 90000  -- 스킬 리셋 포인트 1개당 필요한 XP


-- 🔹 노드 사이즈 상수
local SMALL_SIZE   = 64   -- 작은 노드
local BIG_SIZE     = 96   -- 큰 노드
local SPECIAL_SIZE = 128   -- 스페셜 노드

-- 🔹 큰 노드 목록 (작작큰작작의 "큰" 노드들)
local BigNodeIds = {
    SnowlandHunter   = true,
    DesertPioneer    = true,
    WeightBig        = true,
    CombatSwimBreath = true,
    EndlessCycle     = true,
    Gladiator        = true,
    PrimalInstinct   = true,
    TunnelRats       = true,
    CombatVeteran    = true,
    WeaknessDetection = true,
	ItemBig          = true,
    XPVer2Big        = true,
}

-- 🔹 스페셜 노드 목록 (트리 끝 별 노드들)
local SpecialNodeIds = {
    Start             = true,
    GravityAdaptation = true,
    InnerStrength     = true,
    TrainingOptimism  = true,
	AccumulatedPower  = true,
	VeteranPartisan   = true,
	WeightofLife      = true,
    RandomBox         = true,
}

----------------------------------------------------
-- 🔹 선행 스킬 조건 테이블
----------------------------------------------------
local NodePrerequisitesAND = {
    -- 상단 가지: 배고픔
    Hunger1        = { "Start" },
    Hunger2        = { "Hunger1" },
    SnowlandHunter = { "Hunger2" },
    Hunger3        = { "SnowlandHunter" },
    Hunger4        = { "Hunger3" },

    -- 상단 가지: 물
    Water1         = { "Start" },
    Water2         = { "Water1" },
    DesertPioneer  = { "Water2" },
    Water3         = { "DesertPioneer" },
    Water4         = { "Water3" },

    -- 무게 가지 (Weight1은 OR 조건만 사용 → 여기선 AND 없음)
    Weight2            = { "Weight1" },
    WeightBig          = { "Weight2" },
    Weight3            = { "WeightBig" },
    Weight4            = { "Weight3" },
    GravityAdaptation  = { "Weight4" },

    -- 좌측 가지: 스태미나 회복 (보라 위줄)
    StaminaRegen1      = { "Start" },
    StaminaRegen2      = { "StaminaRegen1" },
    CombatSwimBreath   = { "StaminaRegen2" },
    StaminaRegen3      = { "CombatSwimBreath" },
    StaminaRegen4      = { "StaminaRegen3" },

    -- 좌측 가지: 스태미나 소모 감소 (보라 아래줄)
    Stamina1           = { "Start" },
    Stamina2           = { "Stamina1" },
    EndlessCycle       = { "Stamina2" },
    Stamina3           = { "EndlessCycle" },
    Stamina4           = { "Stamina3" },

    -- ✅ Weight of Life (부모: Stamina4)
    WeightofLife       = { "Stamina4" },

    -- ✅ Veteran Partisan (부모: StaminaRegen4)
    VeteranPartisan    = { "StaminaRegen4" },

    -- 좌측 가지: 조준시 발걸음 (갈색 위줄)
    Walk2              = { "Walk1" },
    Gladiator          = { "Walk2" },
    Walk3              = { "Gladiator" },
    Walk4              = { "Walk3" },

    -- 좌측 가지: 능숙한 달리기 (갈색 아래줄)
    Sprint2            = { "Sprint1" },
    PrimalInstinct     = { "Sprint2" },
    Sprint3            = { "PrimalInstinct" },
    Sprint4            = { "Sprint3" },

    -- ✅ Accumulated Power (부모: InnerStrength)
    AccumulatedPower   = { "InnerStrength" },

    -- 우측 가지: 스트레스 감소 (오렌지 위줄)
    Stress1            = { "Start" },
    Stress2            = { "Stress1" },
    TunnelRats         = { "Stress2" },
    Stress3            = { "TunnelRats" },
    Stress4            = { "Stress3" },

    -- 우측 가지: 공황 감소 (노랑 아래줄)
    Panic1             = { "Start" },
    Panic2             = { "Panic1" },
    CombatVeteran      = { "Panic2" },
    Panic3             = { "CombatVeteran" },
    Panic4             = { "Panic3" },

    -- XP 가지 (XPgain1은 OR 조건만 사용 → 여기선 AND 없음)
    XPgain2            = { "XPgain1" },
    WeaknessDetection  = { "XPgain2" },
    XPgain3            = { "WeaknessDetection" },
    XPgain4            = { "XPgain3" },

    -- ✅ 상단 가지: 루팅 확률 증가
    Item1              = { "Hunger4" },   -- 부모: Hunger4
    Item2              = { "Item1" },     -- 부모: Item1
    ItemBig            = { "Item2" },     -- 부모: Item2

    -- ✅ 상단 가지: XP 획득량 증가 Ver2
    XPVer21            = { "Water4" },    -- 부모: Water4
    XPVer22            = { "XPVer21" },   -- 부모: XPVer21
    XPVer2Big          = { "XPVer22" },   -- 부모: XPVer22

    -- ✅ 상단 가지: 차량 관련
    CarDamage          = { "WeightBig" }, -- 부모: WeightBig
    CarBreak           = { "CarDamage" }, -- 부모: CarDamage
    CarHP              = { "CarBreak" },  -- 부모: CarBreak

    -- ✅ 상단 가지: 작업 시간 단축
    Work1              = { "WeightBig" }, -- 부모: WeightBig
    Work2              = { "Work1" },     -- 부모: Work1
    Work3              = { "Work2" },     -- 부모: Work2

    -- 우측 스페셜
    TrainingOptimism   = { "XPgain4" },

    -------------------------------------------------
    -- 4. 하단 가지 (Box / RandomBox 관련)
    -------------------------------------------------

    -- ✅ Box 가격 감소
    BoxPrice1          = { "Start" },       -- 부모: Start
    BoxPrice2          = { "BoxPrice1" },   -- 부모: BoxPrice1
    BoxPrice3          = { "BoxPrice2" },   -- 부모: BoxPrice2

    -- ✅ RandomBox
    RandomBox          = { "Start" },       -- 부모: Start

    -- ✅ Box 희귀도 증가
    BoxChance1         = { "Start" },       -- 부모: Start
    BoxChance2         = { "BoxChance1" },  -- 부모: BoxChance1
    BoxChance3         = { "BoxChance2" },  -- 부모: BoxChance2
}


local NodePrerequisitesOR = {
    -- 상단: Weight1은 Hunger4 또는 Water4 중 하나만 찍혀도 해금
    Weight1           = { "Hunger4", "Water4" },

    -- 좌측: 갈색 시작 노드들 (보라 두 줄 중 한 쪽 끝만)
    Walk1             = { "StaminaRegen4", "Stamina4" },
    Sprint1           = { "StaminaRegen4", "Stamina4" },

    -- 좌측 스페셜: 둘 중 한 갈래 끝
    InnerStrength     = { "Walk4", "Sprint4" },

    -- 우측: XP 시작 노드
    XPgain1           = { "Stress4", "Panic4" },
}

----------------------------------------------------
-- 🔹 번역용 노드 설명 헬퍼
----------------------------------------------------
local function RPG_GetNodeDescription(id)
    if not id then
        return "?"
    end
    -- Tooltip_RPGSkillTree_ + 노드ID 형식의 번역키를 가져온다
    return getText("Tooltip_RPGSkillTree_" .. id)
end

----------------------------------------------------
-- 🔹 번역용 노드 설명(여러 줄) 헬퍼
--    Tooltip_RPGSkillTree_<id>_1, _2, _3 ... 이 있으면
--    그걸 여러 줄로 읽어오고,
--    없으면 기존 단일 키 Tooltip_RPGSkillTree_<id> 한 줄로 처리
----------------------------------------------------
local function RPG_GetNodeDescriptionLines(id)
    if not id then
        return { "?" }
    end

    local lines = {}

    -- 1) 먼저 번호붙은 키들을 시도: _1, _2, _3, ...
    --    예: Tooltip_RPGSkillTree_WeightofLife_1
    for i = 1, 10 do
        local key = string.format("Tooltip_RPGSkillTree_%s_%d", id, i)
        local txt = getText(key)

        -- getText가 키 그대로를 돌려주는 경우(=번역 없음)면 중단
        if not txt or txt == key then
            break
        end

        table.insert(lines, txt)
    end

    -- 2) 번호붙은게 하나도 없으면, 기존 단일 키 사용
    if #lines == 0 then
        local key = "Tooltip_RPGSkillTree_" .. id
        local txt = getText(key)
        table.insert(lines, txt)
    end

    return lines
end

----------------------------------------------------
-- 🔹 번역 문자열을 줄 단위로 쪼개는 헬퍼
--   - \n, <br> 둘 다 줄바꿈으로 처리
----------------------------------------------------
local function RPG_SplitTooltipLines(desc)
    local lines = {}

    if not desc then
        return lines
    end

    desc = tostring(desc)

    -- Tooltip 에서 HTML <br> 쓴 것도 같이 처리
    desc = desc:gsub("<br>", "\n")

    -- \n 기준으로 잘라서 lines 에 넣기
    for line in desc:gmatch("([^\n]+)") do
        table.insert(lines, line)
    end

    -- 혹시라도 비어 있으면 원문 그대로 한 줄 넣기
    if #lines == 0 then
        table.insert(lines, desc)
    end

    return lines
end


-- 🔹 이 노드를 찍을 수 있는지 검사 (선행 스킬 AND / OR 모두 반영)
function RPGSkillTreeUI:canUnlockNode(id)
    -- 시작 노드는 찍는 개념 아님
    if not id or id == "Start" then
        return false
    end

    -- RandomBox는 스킬포인트로 찍지 않고 XP로만 구매
    if id == "RandomBox" then
        return false
    end


    local state = self.nodeState or {}

    ------------------------------------------------
    -- AND 조건: 전부 찍혀 있어야 함
    ------------------------------------------------
    local reqAnd = NodePrerequisitesAND and NodePrerequisitesAND[id]
    if type(reqAnd) == "table" then
        for _, parentId in ipairs(reqAnd) do
            if not state[parentId] then
                return false
            end
        end
    end

    ------------------------------------------------
    -- OR 조건: 하나만 찍혀 있어도 OK
    ------------------------------------------------
    local reqOr = NodePrerequisitesOR and NodePrerequisitesOR[id]
    if type(reqOr) == "table" then
        local ok = false
        for _, parentId in ipairs(reqOr) do
            if state[parentId] then
                ok = true
                break
            end
        end
        if not ok then
            return false
        end
    end
	
	------------------------------------------------
    -- 🔹 레벨 조건: VeteranPartisan은 30레벨 이상만 해금 가능
    ------------------------------------------------
    if id == "VeteranPartisan" then
		local player = self.player or getSpecificPlayer(0)
        if player then
            local md = player:getModData()
            local level = md.RPG_Level or 1
            if level < 30 then
                return false
            end
        end
    end
	
	-- Accumulated Power = 레벨 50 필요
    if id == "AccumulatedPower" then
        local player = self.player or getSpecificPlayer(0)
        if player then
            local md = player:getModData()
            local level = md.RPG_Level or 1
            if level < 50 then
                return false
            end
        end
    end

    -- 여기까지 안 막혔으면 해금 가능
    return true
end




function RPGSkillTreeUI:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.background = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    o.border = true
    o.zoom = 1.0

    -- 🔹 팬(드래그 이동) 관련 변수
    o.panX = 0
    o.panY = 0
    o.isPanning = false



    -- 시작 노드
    o.startNodeTex          = getTexture(StartNodeTexture)

    -----------------------------------------
    -- 아이콘 텍스처 로딩 (UI 폴더와 1:1 매칭)
    -----------------------------------------
    local basePath = "media/ui/RPGSkillTree/"

    -- ✅ 기본 생존
    o.texHunger             = getTexture(basePath .. "RPG_Hunger.png")
    o.texHungerDisabled     = getTexture(basePath .. "RPG_Hunger_Disabled.png")

    o.texWater              = getTexture(basePath .. "RPG_Water.png")
    o.texWaterDisabled      = getTexture(basePath .. "RPG_Water_Disabled.png")

    o.texSnowHunter         = getTexture(basePath .. "RPG_SnowlandHunter.png")
    o.texSnowHunterDisabled = getTexture(basePath .. "RPG_SnowlandHunter_Disabled.png")

    o.texDesertPioneer      = getTexture(basePath .. "RPG_DesertPioneer.png")
    o.texDesertPioneerDisabled = getTexture(basePath .. "RPG_DesertPioneer_Disabled.png")

    o.texWeight             = getTexture(basePath .. "RPG_Weight.png")
    o.texWeightDisabled     = getTexture(basePath .. "RPG_Weight_Disabled.png")

    -- ✅ 보라 트리 (스태미나 계열)
    o.texStaminaRegen           = getTexture(basePath .. "RPG_StaminaRegen.png")
    o.texStaminaRegenDisabled   = getTexture(basePath .. "RPG_StaminaRegen_Disabled.png")

    o.texCombatSwim             = getTexture(basePath .. "RPG_CombatSwimBreath.png")
    o.texCombatSwimDisabled     = getTexture(basePath .. "RPG_CombatSwimBreath_Disabled.png")

    o.texStamina                = getTexture(basePath .. "RPG_Stamina.png")
    o.texStaminaDisabled        = getTexture(basePath .. "RPG_Stamina_Disabled.png")

    o.texEndlessCycle           = getTexture(basePath .. "RPG_EndlessCycle.png")
    o.texEndlessCycleDisabled   = getTexture(basePath .. "RPG_EndlessCycle_Disabled.png")

    -- ✅ 갈색 트리 (이동/근접)
    o.texWalk                   = getTexture(basePath .. "RPG_Walk.png")
    o.texWalkDisabled           = getTexture(basePath .. "RPG_Walk_Disabled.png")

    o.texGladiator              = getTexture(basePath .. "RPG_Gladiator.png")
    o.texGladiatorDisabled      = getTexture(basePath .. "RPG_Gladiator_Disabled.png")

    o.texSprint                 = getTexture(basePath .. "RPG_Sprint.png")
    o.texSprintDisabled         = getTexture(basePath .. "RPG_Sprint_Disabled.png")

    o.texPrimalInstinct         = getTexture(basePath .. "RPG_PrimalInstinct.png")
    o.texPrimalInstinctDisabled = getTexture(basePath .. "RPG_PrimalInstinct_Disabled.png")

    -- ✅ 우측 오렌지/노랑 트리 (스트레스/공황)
    o.texStress                 = getTexture(basePath .. "RPG_Stress.png")
    o.texStressDisabled         = getTexture(basePath .. "RPG_Stress_Disabled.png")

    o.texTunnelRats             = getTexture(basePath .. "RPG_TunnelRats.png")
    o.texTunnelRatsDisabled     = getTexture(basePath .. "RPG_TunnelRats_Disabled.png")

    o.texPanic                  = getTexture(basePath .. "RPG_Panic.png")
    o.texPanicDisabled          = getTexture(basePath .. "RPG_Panic_Disabled.png")

    o.texCombatVeteran          = getTexture(basePath .. "RPG_CombatVeteran.png")
    o.texCombatVeteranDisabled  = getTexture(basePath .. "RPG_CombatVeteran_Disabled.png")

    -- ✅ XP 트리
    o.texXP                     = getTexture(basePath .. "RPG_XP.png")
    o.texXPDisabled             = getTexture(basePath .. "RPG_XP_Disabled.png")

    o.texWeaknessDetection      = getTexture(basePath .. "RPG_WeaknessDetection.png")
    o.texWeaknessDetectionDisabled = getTexture(basePath .. "RPG_WeaknessDetection_Disabled.png")

    -- ✅ 스페셜
    o.texInnerStrength          = getTexture(basePath .. "RPG_InnerStrength.png")
    o.texInnerStrengthDisabled  = getTexture(basePath .. "RPG_InnerStrength_Disabled.png")

    o.texAccumulatedPower         = getTexture(basePath .. "RPG_AccumulatedPower.png")
    o.texAccumulatedPowerDisabled = getTexture(basePath .. "RPG_AccumulatedPower_Disabled.png")

    o.texTrainingOptimism       = getTexture(basePath .. "RPG_TrainingOptimism.png")
    o.texTrainingOptimismDisabled = getTexture(basePath .. "RPG_TrainingOptimism_Disabled.png")

    o.texGravityAdaptation      = getTexture(basePath .. "RPG_GravityAdaptation.png")
    o.texGravityAdaptationDisabled = getTexture(basePath .. "RPG_GravityAdaptation_Disabled.png")

    -- (옵션) 우울/불행 아이콘도 나중에 쓸 수 있음
    o.texUnhappy                = getTexture(basePath .. "RPG_Unhappy.png")
    o.texUnhappyDisabled        = getTexture(basePath .. "RPG_Unhappy_Disabled.png")
	
	------------------------------------------------
    -- ✅ 상단 가지: 루팅 / XP Ver2 / 차량 / 작업 아이콘
    ------------------------------------------------
    -- 박스(루팅 관련 + 랜덤박스 + 박스가격/확률 노드 공용)
    o.texBox             = getTexture(basePath .. "RPG_Box.png")
	o.texBox2            = getTexture(basePath .. "RPG_Box2.png")
    o.texBoxDisabled     = getTexture(basePath .. "RPG_Box_Disabled.png")

    -- 차량 관련 (CarDamage / CarBreak / CarHP 등)
    o.texCar             = getTexture(basePath .. "RPG_Car.png")
    o.texCarDisabled     = getTexture(basePath .. "RPG_Car_Disabled.png")

    -- 작업 시간 단축 (Work1/2/Big 등)
    o.texWork            = getTexture(basePath .. "RPG_Work.png")
    o.texWorkDisabled    = getTexture(basePath .. "RPG_Work_Disabled.png")



    -- 🔹 -------------------------스킬트리 노드 목록------------------------
    --    x, y 는 "시작 노드 기준 상대 위치"라고 생각하면 됨 (0,0 = 시작 노드)
    o.nodes = {

		----------------------------------------------------
		-- 0. 중심 시작 노드
		----------------------------------------------------
		{ id="Start", x = 0, y = 0, tex = o.startNodeTex, size = 1.5 },



		----------------------------------------------------
		-- 1. 상단 가지
		----------------------------------------------------

		-- 배고픔
		{ id="Hunger1",       x= -50, y=-150, tex=o.texHunger },
		{ id="Hunger2",       x= -50, y=-250, tex=o.texHunger },
		{ id="SnowlandHunter",x= -50, y=-350, tex=o.texSnowHunter },
		{ id="Hunger3",       x= -50, y=-450, tex=o.texHunger },
		{ id="Hunger4",       x= -50, y=-550, tex=o.texHunger },

		-- 목마름
		{ id="Water1",        x=  50, y=-150, tex=o.texWater },
		{ id="Water2",        x=  50, y=-250, tex=o.texWater },
		{ id="DesertPioneer", x=  50, y=-350, tex=o.texDesertPioneer },
		{ id="Water3",        x=  50, y=-450, tex=o.texWater },
		{ id="Water4",        x=  50, y=-550, tex=o.texWater },

		-- 무게증가
		{ id="Weight1",           x=0, y=-650, tex=o.texWeight },
		{ id="Weight2",           x=0, y=-750, tex=o.texWeight },
		{ id="WeightBig",         x=0, y=-850, tex=o.texWeight },
		{ id="Weight3",           x=0, y=-950, tex=o.texWeight },
		{ id="Weight4",           x=0, y=-1050, tex=o.texWeight },
		{ id="GravityAdaptation", x=0, y=-1150, tex=o.texGravityAdaptation },

		-- 루팅확률증가
		{ id="Item1",           x=-100, y=-650, tex=o.texBox },
		{ id="Item2",           x=-100, y=-750, tex=o.texBox },
		{ id="ItemBig",         x=-100, y=-850, tex=o.texBox },
		
		-- XP획득량증가2
		{ id="XPVer21",           x=100, y=-650, tex=o.texXP },
		{ id="XPVer22",           x=100, y=-750, tex=o.texXP },
		{ id="XPVer2Big",         x=100, y=-850, tex=o.texXP },
		
		-- 차량관련
		{ id="CarDamage",           x=-100, y=-950, tex=o.texCar },
		{ id="CarBreak",            x=-100, y=-1050, tex=o.texCar },
		{ id="CarHP",               x=-100, y=-1150, tex=o.texCar },
		
		-- 작업시간단축
		{ id="Work1",           x=100, y=-950, tex=o.texWork },
		{ id="Work2",           x=100, y=-1050, tex=o.texWork },
		{ id="Work3",           x=100, y=-1150, tex=o.texWork },
		


		----------------------------------------------------
		-- 2. 좌측 가지
		----------------------------------------------------

		--------------------------
		-- 스테미나 회복 (작작큼작작)
		--------------------------
		{ id="StaminaRegen1", x=-150,       y= 50,  tex=o.texStaminaRegen },
		{ id="StaminaRegen2", x=-250,      y=50,  tex=o.texStaminaRegen },
		{ id="CombatSwimBreath", x=-350,   y=50,  tex=o.texCombatSwim },
		{ id="StaminaRegen3", x=-450,      y=50,  tex=o.texStaminaRegen },
		{ id="StaminaRegen4", x=-550,      y=50,  tex=o.texStaminaRegen },

		--------------------------
		-- 스테미나 소모 감소
		--------------------------
		{ id="Stamina1", x=-150,      y=-50, tex=o.texStamina },
		{ id="Stamina2", x=-250,     y=-50, tex=o.texStamina },
		{ id="EndlessCycle", x=-350, y=-50, tex=o.texEndlessCycle },
		{ id="Stamina3", x=-450,     y=-50, tex=o.texStamina },
		{ id="Stamina4", x=-550,     y=-50, tex=o.texStamina },

		--------------------------
		-- Weight of Life
		--------------------------
		{ id="WeightofLife", x=-650,      y=-150, tex=o.texWalk },
		
		--------------------------
		-- Veteran Partisan
		--------------------------
		{ id="VeteranPartisan", x=-650,      y=150, tex=o.texSprint },

		--------------------------
		-- 조준시 발걸음 (갈색)
		--------------------------
		{ id="Walk1", x=-650,     y=-50, tex=o.texWalk },
		{ id="Walk2", x=-750,     y=-50, tex=o.texWalk },
		{ id="Gladiator", x=-850, y=-50, tex=o.texGladiator },
		{ id="Walk3", x=-950,     y=-50, tex=o.texWalk },
		{ id="Walk4", x=-1050,     y=-50, tex=o.texWalk },

		--------------------------
		-- 능숙한 달리기
		--------------------------
		{ id="Sprint1", x=-650,    y=50, tex=o.texSprint },
		{ id="Sprint2", x=-750,    y=50, tex=o.texSprint },
		{ id="PrimalInstinct", x=-850, y=50, tex=o.texPrimalInstinct },
		{ id="Sprint3", x=-950,    y=50, tex=o.texSprint },
		{ id="Sprint4", x=-1050,    y=50, tex=o.texSprint },

		--------------------------
		-- 좌측 스페셜: 내부의 힘
		--------------------------
		{ id="InnerStrength", x=-1150, y=0, tex=o.texInnerStrength },
		
		--축적된 힘
		{ id="AccumulatedPower", x=-1300, y=0, tex=o.texAccumulatedPower },


		----------------------------------------------------
		-- 3. 우측 가지
		----------------------------------------------------

		--------------------------
		-- 스트레스 감소
		--------------------------
		{ id="Stress1", x=150,      y=-50, tex=o.texStress },
		{ id="Stress2", x=250,     y=-50, tex=o.texStress },
		{ id="TunnelRats", x=350,  y=-50, tex=o.texTunnelRats },
		{ id="Stress3", x=450,     y=-50, tex=o.texStress },
		{ id="Stress4", x=550,     y=-50, tex=o.texStress },

		--------------------------
		-- 공황 감소
		--------------------------
		{ id="Panic1", x=150,      y=50, tex=o.texPanic },
		{ id="Panic2", x=250,     y=50, tex=o.texPanic },
		{ id="CombatVeteran", x=350, y=50, tex=o.texCombatVeteran },
		{ id="Panic3", x=450,     y=50, tex=o.texPanic },
		{ id="Panic4", x=550,     y=50, tex=o.texPanic },

		--------------------------
		-- XP 증가 트리
		--------------------------
		{ id="XPgain1", x=650,     y=0, tex=o.texXP },
		{ id="XPgain2", x=750,     y=0, tex=o.texXP },
		{ id="WeaknessDetection", x=850, y=0, tex=o.texWeaknessDetection },
		{ id="XPgain3", x=950,     y=0, tex=o.texXP },
		{ id="XPgain4", x=1050,     y=0, tex=o.texXP },

		--------------------------
		-- 우측 스페셜: 낙천수련
		--------------------------
		{ id="TrainingOptimism", x=1150, y=0, tex=o.texTrainingOptimism },
		
		----------------------------------------------------
		-- 4. 하단 가지
		----------------------------------------------------

		--------------------------
		-- Box 가격감소
		--------------------------
		{ id="BoxPrice1", x=-100,      y=150, tex=o.texBox },
		{ id="BoxPrice2", x=-100,      y=250, tex=o.texBox },
		{ id="BoxPrice3", x=-100,      y=350, tex=o.texBox },

		--------------------------
		-- RandomBox
		--------------------------
		{ id="RandomBox", x=0,      y=250, tex=o.texBox2 },

		--------------------------
		-- Box 희귀도 증가
		--------------------------
		{ id="BoxChance1", x=100,     y=150, tex=o.texBox },
		{ id="BoxChance2", x=100,     y=250, tex=o.texBox },
		{ id="BoxChance3", x=100,     y=350, tex=o.texBox },
	}
	
	-- 🔹 id 로 노드 찾기 쉽게 맵 생성
    o.nodeById = {}
    for _, node in ipairs(o.nodes) do
        if node.id then
            o.nodeById[node.id] = node
        end
    end

    ----------------------------------------------------
    -- 스킬 포인트 & 노드 상태 (플레이어 modData에 저장)
    ----------------------------------------------------
    o.skillPoints = 0                 
    o.nodeState   = {}                -- [nodeId] = true/false
    
	--시작 노드는 항상 활성화
    o.nodeState["Start"] = true
	
    o:initialise()
	
    -- 툴팁 캐시
    o.tooltipCache = {
        id   = nil,
        text = nil,
        w    = 0,
        h    = 0,
    }

    ------------------------------------------------
    -- 🔹 좌측 하단 리셋 버튼 생성
    ------------------------------------------------
    local btnW, btnH = 120, 25
    local margin = 20
    o.resetButton = ISButton:new(
        margin,
        o.height - btnH - margin,  -- 패널 좌측 하단
        btnW,
        btnH,
        "Reset (0)",               -- 초기 텍스트
        o,
        RPGSkillTreeUI.onClickReset
    )
    o.resetButton:initialise()
    o.resetButton:instantiate()
    o.resetButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    o:addChild(o.resetButton)

    ------------------------------------------------
    -- 🔹 우측 하단 Close 버튼 생성
    ------------------------------------------------
    o.closeButton = ISButton:new(
        o.width - btnW - margin,   -- 패널 우측 하단
        o.height - btnH - margin,
        btnW,
        btnH,
        "Close",
        o,
        RPGSkillTreeUI.onClickClose
    )
    o.closeButton:initialise()
    o.closeButton:instantiate()
    o.closeButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    o:addChild(o.closeButton)
	
    return o
end

------------------------------------------------
-- 🔹 Close 버튼 클릭
------------------------------------------------
function RPGSkillTreeUI.onClickClose(self, button, x, y)
    if self and self.close then
        self:close()
    end
end


function RPGSkillTreeUI:getInactiveTextureForNode(node)
    local id = node.id or ""

    -- 🔹 상단 (배고픔/물/무게 계열)
	if id:find("Hunger") then
		return self.texHungerDisabled
	end
	if id:find("Water") then
		return self.texWaterDisabled
	end
	if id:find("SnowlandHunter") then
		return self.texSnowHunterDisabled
	end
	if id:find("DesertPioneer") then
		return self.texDesertPioneerDisabled
	end

	-- 🔹 무게 계열 (WeightofLife는 예외 처리)
	if id:find("Weight") and not id:find("Gravity") and id ~= "WeightofLife" then
		return self.texWeightDisabled
	end
	if id:find("GravityAdaptation") then
		return self.texGravityAdaptationDisabled
	end


    -- 🔹 보라 트리 (스태미나 계열)
    if id:find("StaminaRegen") then
        return self.texStaminaRegenDisabled
    end
    if id:find("CombatSwim") then
        return self.texCombatSwimDisabled
    end
    if id:find("Stamina") and not id:find("Regen") then
        return self.texStaminaDisabled
    end
    if id:find("EndlessCycle") then
        return self.texEndlessCycleDisabled
    end

    -- 🔹 갈색 트리 (이동/근접)
    if id:find("Walk") then
        return self.texWalkDisabled
    end
	if id == "WeightofLife" then
		return self.texWalkDisabled
	end
    if id:find("Gladiator") then
        return self.texGladiatorDisabled
    end
    if id:find("Sprint") then
        return self.texSprintDisabled
    end
	if id == "VeteranPartisan" then
		return self.texSprintDisabled
	end
    if id:find("PrimalInstinct") then
        return self.texPrimalInstinctDisabled
    end

    -- 🔹 우측 트리 (스트레스/공황/XP)
    if id:find("Stress") then
        return self.texStressDisabled
    end
    if id:find("TunnelRats") then
        return self.texTunnelRatsDisabled
    end
    if id:find("Panic") then
        return self.texPanicDisabled
    end
    if id:find("CombatVeteran") then
        return self.texCombatVeteranDisabled
    end

    if id:find("XPgain") or id == "XP" then
        return self.texXPDisabled
    end
    if id:find("WeaknessDetection") then
        return self.texWeaknessDetectionDisabled
    end

    -- 🔹 스페셜
    if id == "InnerStrength" then
        return self.texInnerStrengthDisabled
    end
    if id == "TrainingOptimism" then
        return self.texTrainingOptimismDisabled
    end
    if id == "AccumulatedPower" then
        return self.texAccumulatedPowerDisabled
    end

    -- 🔹 박스/루팅/랜덤박스/박스가격/희귀도 노드
    if id:find("Item")
    or id:find("BoxPrice")
    or id:find("BoxChance")
    or id:find("RandomBox") then
        return self.texBoxDisabled
    end

    -- 🔹 차량 관련 노드
    if id:find("CarDamage")
    or id:find("CarBreak")
    or id:find("CarHP") then
        return self.texCarDisabled
    end

    -- 🔹 작업 시간 단축 노드
    if id:find("Work1")
    or id:find("Work2")
    or id:find("Work3") then
        return self.texWorkDisabled
    end
	
	if id:find("XPgain")
	or id:find("XPVer2")
		or id == "XP" then
    return self.texXPDisabled
	end


    return nil  -- 매칭 실패 시 기본 활성 아이콘 사용
end


function RPGSkillTreeUI:clampPan()
    local max = MAX_PAN or 2000

    self.panX = self.panX or 0
    self.panY = self.panY or 0

    if self.panX >  max then self.panX =  max end
    if self.panX < -max then self.panX = -max end
    if self.panY >  max then self.panY =  max end
    if self.panY < -max then self.panY = -max end
end

-- 🔹 화면 상의 노드 중심 좌표 구하는 헬퍼
function RPGSkillTreeUI:getNodeScreenPos(node, centerX, centerY, zoom)
    local baseSize = SMALL_SIZE
    if BigNodeIds[node.id] then
        baseSize = BIG_SIZE
    end
    if SpecialNodeIds[node.id] then
        baseSize = SPECIAL_SIZE
    end

    local sizeMul  = node.size or 1.0
    local iconSize = baseSize * sizeMul * zoom

    local offsetX = (node.x or 0) * zoom
    local offsetY = (node.y or 0) * zoom

    local sx = centerX + offsetX
    local sy = centerY + offsetY

    return sx, sy, iconSize
end

-- 🔹 노드의 화면상 사각형 영역(클릭/툴팁 판정용) 구하기
function RPGSkillTreeUI:getNodeScreenRect(node, centerX, centerY, zoom)
    local baseSize = SMALL_SIZE
    if BigNodeIds[node.id] then
        baseSize = BIG_SIZE
    end
    if SpecialNodeIds[node.id] then
        baseSize = SPECIAL_SIZE
    end

    local sizeMul  = node.size or 1.0
    local iconSize = baseSize * sizeMul * zoom

    local offsetX = (node.x or 0) * zoom
    local offsetY = (node.y or 0) * zoom

    local cx = centerX + offsetX
    local cy = centerY + offsetY

    local x = cx - iconSize / 2
    local y = cy - iconSize / 2

    return x, y, iconSize, iconSize
end

-- 🔹 패널 기준 좌표(mx,my)에 있는 노드 찾기
function RPGSkillTreeUI:getNodeUnderPoint(mx, my, centerX, centerY, zoom)
    if not self.nodes then return nil end

    for _, node in ipairs(self.nodes) do
        local tex = node.tex or self.startNodeTex
        if tex then
            local x, y, w, h = self:getNodeScreenRect(node, centerX, centerY, zoom)
            if mx >= x and mx <= x + w and my >= y and my <= y + h then
                return node
            end
        end
    end
    return nil
end

-- 직선을 여러 개의 작은 사각형으로 그리는 헬퍼 (최적화 버전)
function RPGSkillTreeUI:drawLineRect(x1, y1, x2, y2, r, g, b, a)
    local dx = x2 - x1
    local dy = y2 - y1

    -- 실제 길이
    local dist = math.sqrt(dx * dx + dy * dy)

    -- 한 점 찍는 간격(픽셀). 숫자 줄이면 선이 더 촘촘하지만 렉이 늘어남.
    -- 4~6 정도가 무난. 더 최적화하고 싶으면 8까지 올려도 됨.
    local stepPixels = 4

    local steps = math.floor(dist / stepPixels + 0.5)

    -- 너무 많이 찍지 않도록 상한
    if steps > 256 then
        steps = 256
    end

    if steps <= 0 then
        self:drawRect(x1, y1, 2, 2, a, r, g, b)
        return
    end

    local sx = dx / steps
    local sy = dy / steps

    local x = x1
    local y = y1
    for i = 1, steps do
        self:drawRect(x, y, 2, 2, a, r, g, b)
        x = x + sx
        y = y + sy
    end
end

------------------------------------------------
-- 🔹 \n 이 들어간 텍스트 여러 줄로 그리기 헬퍼
------------------------------------------------
function RPGSkillTreeUI:drawMultiline(text, x, y, r, g, b, a, font)
    local tm   = getTextManager()
    font       = font or UIFont.Small
    text       = tostring(text or "")
    local lineH = tm:MeasureStringY(font, "A") + 2

    for line in string.gmatch(text, "([^\n]+)") do
        self:drawText(line, x, y, r, g, b, a, font)
        y = y + lineH
    end

    return y  -- 마지막 줄 아래 y 좌표 리턴
end

function RPGSkillTreeUI:render()
    -- 기본 패널 그리기 (배경 등)
    ISPanel.render(self)
	
	local player = self.player or getSpecificPlayer(0)
	
    ------------------------------------------------
    -- 🔹 상단 중앙에 크게 Skill Points 표시
    ------------------------------------------------
    local sp = self.skillPoints or 0
    local tm   = getTextManager()
    local font = UIFont.Large
    local text = "Skill Points : " .. tostring(sp)

    local textW = tm:MeasureStringX(font, text)
    local x = (self.width - textW) / 2     -- 가로 중앙 정렬
    local y = 10                           -- 화면 위에서 조금 내려온 위치

    -- 노란색 계열로 강조 (원하면 색 바꿔도 됨)
    self:drawText(text, x, y, 1, 0.9, 0.2, 1, font)

    -- 현재 스킬 포인트 표시
    local sp = self.skillPoints or 0
    self:drawText("SP: " .. tostring(sp), 20, 20, 0, 1, 0, 1, UIFont.Small)
	
    -- 🔹 레벨 / XP 표시 (추가)
    if player then
        local md  = player:getModData()
        local lvl = md.RPG_Level       or 1
        local xp  = md.RPG_XP          or 0

        local xpNext = 1000
        if RPG_GetRequiredXP then
            xpNext = RPG_GetRequiredXP(lvl)
        end

        self.skillPoints = md.RPGSkillPoints or self.skillPoints

        self:drawText("LV: " .. tostring(lvl), 20, 35, 1, 1, 1, 1, UIFont.Small)
        self:drawText("XP: " .. tostring(xp) .. " / " .. tostring(xpNext),
                      20, 50, 1, 1, 1, 1, UIFont.Small)

        -- 🔹 리셋까지 남은 XP 표시 (XPSystem 헬퍼 사용)
        if RPG_GetResetXPRemain then
            local remain, chunk = RPG_GetResetXPRemain(player)
            self:drawText("ResetPointXP: " .. tostring(remain),
                          20, 65, 1, 1, 1, 1, UIFont.Small)
        end

        -- Reset 버튼 타이틀 갱신
        if self.resetButton then
            local resetPts = md.RPG_ResetPoints or 0
            self.resetButton:setTitle("Reset (" .. tostring(resetPts) .. ")")
            self.resetButton.enable = (resetPts > 0)
        end
		
        ------------------------------------------------
        -- 🔹 우측 상단: 현재 적용 중인 스킬 스테이터스 표시
        ------------------------------------------------
        -- 기본 MaxWeight 저장 (이미 있으면 유지)
        md.RPG_BaseMaxWeight = md.RPG_BaseMaxWeight or player:getMaxWeightBase()

                local statusX = self.width - 260      -- 오른쪽에서 살짝 안쪽
        local statusY = 20                    -- 위에서 조금 내려옴
        local lineH   = tm:MeasureStringY(UIFont.Small, "A") + 2

        ------------------------------------------------
        -- 제목 (한 줄짜리지만 그대로 둠)
        ------------------------------------------------
        self:drawText(getText("UI_RPG_Status"), statusX, statusY,
                      1, 1, 0.8, 1, UIFont.Small)
        statusY = statusY + lineH

        ------------------------------------------------
        -- 🔹 계수를 텍스트로 그려주는 헬퍼
        --    (여기서 \n 이 있으면 drawMultiline 이 처리)
        ------------------------------------------------
        local function drawFactorLine(labelKey, factor)
            if factor == nil then return end
            factor = factor or 1.0

            -- Normal(=1.0)이면 아예 표시하지 않음
            if math.abs(factor - 1.0) < 0.001 then
                return
            end

            local label = getText(labelKey)
            local txt

            if factor < 1.0 then
                local pct = math.floor((1.0 - factor) * 100 + 0.5)
                txt = string.format("%s -%d%%", label, pct)
            else
                local pct = math.floor((factor - 1.0) * 100 + 0.5)
                txt = string.format("%s +%d%%", label, pct)
            end

            statusY = self:drawMultiline(txt, statusX, statusY,
                                         1, 1, 1, 1, UIFont.Small)
        end

        ------------------------------------------------
        -- 🔹 기본 생존/스태미나/정신 계수
        ------------------------------------------------
        drawFactorLine("UI_RPG_Status_HungerGain",   RPG_HUNGER_GAIN_FACTOR)
        drawFactorLine("UI_RPG_Status_ThirstGain",   RPG_THIRST_GAIN_FACTOR)
        drawFactorLine("UI_RPG_Status_StaminaDrain", RPG_STAMINA_DRAIN_FACTOR)
        drawFactorLine("UI_RPG_Status_StaminaRegen", RPG_STAMINA_REGEN_FACTOR)
        drawFactorLine("UI_RPG_Status_StressGain",   RPG_STRESS_GAIN_FACTOR)
        drawFactorLine("UI_RPG_Status_PanicGain",    RPG_PANIC_GAIN_FACTOR)

        ------------------------------------------------
        -- 🔹 전투/XP 계수
        ------------------------------------------------
        drawFactorLine("UI_RPG_Status_XPGain", RPG_ZOMBIE_XP_FACTOR)

        if RPG_LOOT_CHANCE_FACTOR then
            drawFactorLine("UI_RPG_Status_LootChance", RPG_LOOT_CHANCE_FACTOR)
        end
        if RPG_BOX_RARE_CHANCE_FACTOR then
            drawFactorLine("UI_RPG_Status_BoxRareChance", RPG_BOX_RARE_CHANCE_FACTOR)
        end

        ------------------------------------------------
        -- 🔹 소지 무게 (기본 대비 몇 %인지, Normal이면 숨김)
        ------------------------------------------------
        local baseW = md.RPG_BaseMaxWeight or player:getMaxWeightBase()
        local curW  = player:getMaxWeightBase()
        if baseW and baseW > 0 then
            local wFactor = curW / baseW
            if math.abs(wFactor - 1.0) > 0.001 then
                local pct = math.floor((wFactor - 1.0) * 100 + 0.5)
                local txt = string.format(
                    "%s %+d%%",
                    getText("UI_RPG_Status_CarryWeight"),
                    pct
                )
                statusY = self:drawMultiline(txt, statusX, statusY,
                                             1, 1, 1, 1, UIFont.Small)
            end
        end

        ------------------------------------------------
        -- 🔹 작업 속도
        ------------------------------------------------
        if RPG_WORK_SPEED_FACTOR then
            drawFactorLine("UI_RPG_Status_WorkSpeed", RPG_WORK_SPEED_FACTOR)
        end

        ------------------------------------------------
        -- 🔹 차량 관련 스킬 (CarDamage / CarBreak / CarHP)
        ------------------------------------------------
        if RPG_VEHICLE_COLLISION_DAMAGE_FACTOR then
            local f = RPG_VEHICLE_COLLISION_DAMAGE_FACTOR
            if math.abs(f - 1.0) > 0.001 then
                local pct = math.floor((1.0 - f) * 100 + 0.5)
                local txt = string.format(
                    "%s -%d%%",
                    getText("UI_RPG_Status_VehicleCollision"),
                    pct
                )
                statusY = self:drawMultiline(txt, statusX, statusY,
                                             1, 1, 1, 1, UIFont.Small)
            end
        end

        if RPG_VEHICLE_DURABILITY_LOSS_FACTOR then
            local f = RPG_VEHICLE_DURABILITY_LOSS_FACTOR
            if math.abs(f - 1.0) > 0.001 then
                local pct = math.floor((1.0 - f) * 100 + 0.5)
                local txt = string.format(
                    "%s -%d%%",
                    getText("UI_RPG_Status_VehicleDurability"),
                    pct
                )
                statusY = self:drawMultiline(txt, statusX, statusY,
                                             1, 1, 1, 1, UIFont.Small)
            end
        end

        if RPG_VEHICLE_HP_FACTOR then
            local f = RPG_VEHICLE_HP_FACTOR
            if math.abs(f - 1.0) > 0.001 then
                local pct = math.floor((f - 1.0) * 100 + 0.5)
                local txt = string.format(
                    "%s +%d%%",
                    getText("UI_RPG_Status_VehicleHP"),
                    pct
                )
                statusY = self:drawMultiline(txt, statusX, statusY,
                                             1, 1, 1, 1, UIFont.Small)
            end
        end

        ------------------------------------------------
        -- 🔹 Running / Nimble XP 배수 상태 (여기도 \n 대응)
        ------------------------------------------------
        if RPG_SPRINT_XP_DESC then
            statusY = self:drawMultiline(RPG_SPRINT_XP_DESC,
                                         statusX, statusY,
                                         1, 1, 1, 1, UIFont.Small)
        end

        if RPG_NIMBLE_XP_DESC then
            statusY = self:drawMultiline(RPG_NIMBLE_XP_DESC,
                                         statusX, statusY,
                                         1, 1, 1, 1, UIFont.Small)
        end

        ------------------------------------------------
        -- 🔹 루팅 보너스
        ------------------------------------------------
        if RPG_LOOT_EXTRA_CHANCE and RPG_LOOT_EXTRA_CHANCE > 0 then
            local pct = math.floor(RPG_LOOT_EXTRA_CHANCE * 100 + 0.5)
            local txt = string.format(
                "%s +%d%%",
                getText("UI_RPG_Status_ExtraLootChance"),
                pct
            )
            statusY = self:drawMultiline(txt, statusX, statusY,
                                         1, 1, 1, 1, UIFont.Small)
        end

        ------------------------------------------------
        -- 🔹 XP Ver2 설명 (여기도 나중에 \n 넣고 싶으면 OK)
        ------------------------------------------------
        if RPG_XPVER2_DESC then
            -- 번역 키를 쓰고 싶으면 여기서 getText(...) 랩핑해도 됨
            statusY = self:drawMultiline(RPG_XPVER2_DESC,
                                         statusX, statusY,
                                         1, 1, 1, 1, UIFont.Small)
        end

        ------------------------------------------------
        -- 🔹 스페셜 노드 상태 (InnerStrength 등)
        ------------------------------------------------
        local nodes = md.RPGSkillNodes or {}

        if nodes.InnerStrength then
            statusY = self:drawMultiline(
                getText("UI_RPG_Status_InfectionImmune"),
                statusX, statusY,
                0.3, 1.0, 0.3, 1, UIFont.Small
            )
        end

        if nodes.TrainingOptimism then
            statusY = self:drawMultiline(
                getText("UI_RPG_Status_UnhappyDecrease"),
                statusX, statusY,
                0.3, 1.0, 0.3, 1, UIFont.Small
            )
        end

        if nodes.WeightofLife then
            statusY = self:drawMultiline(
                getText("UI_RPG_Status_StompDamage"),
                statusX, statusY,
                0.3, 1.0, 0.3, 1, UIFont.Small
            )
        end

        if nodes.VeteranPartisan then
            statusY = self:drawMultiline(
                getText("UI_RPG_Status_SprintKnockdown"),
                statusX, statusY,
                0.3, 1.0, 0.3, 1, UIFont.Small
            )
        end

        -- Accumulated Power 쿨타임 상태
        if nodes.AccumulatedPower and RPG_GetAccumulatedPowerCooldownRemain then
            local remain = RPG_GetAccumulatedPowerCooldownRemain(player) or 0
            if remain <= 0 then
                statusY = self:drawMultiline(
                    getText("UI_RPG_Status_AccumulatedReady"),
                    statusX, statusY,
                    0.3, 1.0, 0.3, 1, UIFont.Small
                )
            else
                local txt = string.format(
                    getText("UI_RPG_Status_AccumulatedRemain"),
                    remain
                )
                statusY = self:drawMultiline(
                    txt, statusX, statusY,
                    1.0, 0.8, 0.2, 1, UIFont.Small
                )
            end
        end

        ------------------------------------------------
        -- ✅ RandomBox 가격 노드 상태 표시 (번역 + \n 지원)
        ------------------------------------------------
        do
            local nodes = md.RPGSkillNodes or {}
            local discountStep = 0

            if nodes.BoxPrice1 then discountStep = discountStep + 1 end
            if nodes.BoxPrice2 then discountStep = discountStep + 1 end
            if nodes.BoxPrice3 then discountStep = discountStep + 1 end

            if discountStep > 0 then
                local xpText
                if discountStep == 1 then
                    xpText = "5,000"
                elseif discountStep == 2 then
                    xpText = "10,000"
                elseif discountStep == 3 then
                    xpText = "15,000"
                end

                local txt = string.format(
                    getText("UI_RPG_Status_RandomboxPrice"),
                    xpText
                )
                statusY = self:drawMultiline(
                    txt, statusX, statusY,
                    1, 1, 1, 1, UIFont.Small
                )
            end
        end
	end
	
    -- 텍스처 체크
    if not self.startNodeTex then
        self:drawText("NO TEX", 20, 40, 1, 0, 0, 1, UIFont.Medium)
        return
    end
    if not self.nodes then
        self:drawText("NO NODES", 20, 60, 1, 0, 0, 1, UIFont.Medium)
        return
    end

    self:clampPan()

    local zoom = self.zoom or 1.0

    -- 기준점 (팬 적용)
    local centerX = self.width  / 2 + (self.panX or 0)
    local centerY = self.height / 2 + (self.panY or 0)

    ------------------------------------------------
    -- 1) 선 먼저 그리기
    ------------------------------------------------
    local state = self.nodeState or {}
    local nodeById = self.nodeById or {}

	-- AND 연결선
	for childId, parents in pairs(NodePrerequisitesAND) do
		local child = nodeById[childId]
		if child then
			local cx, cy = self:getNodeScreenPos(child, centerX, centerY, zoom)

			-- 자식이 찍혀 있으면 금색, 아니면 검은색
			local unlocked = state[childId]
			local r, g, b = 1, 1, 1   -- 기본: 검은선
			if unlocked then
				r, g, b = 1.0, 0.84, 0.0   -- 금색 느낌
			end

			for _, parentId in ipairs(parents) do
				local parent = nodeById[parentId]
				if parent then
					local px, py = self:getNodeScreenPos(parent, centerX, centerY, zoom)
					-- self:drawLine(px, py, cx, cy, r, g, b, 1.0)  -- ❌ 없음
					self:drawLineRect(px, py, cx, cy, r, g, b, 1.0) -- ✅ 이렇게
				end
			end
		end
	end

	-- OR 연결선 (필요하다면)
	for childId, parents in pairs(NodePrerequisitesOR) do
		local child = nodeById[childId]
		if child then
			local cx, cy = self:getNodeScreenPos(child, centerX, centerY, zoom)

			local unlocked = state[childId]
			local r, g, b = 1, 1, 1
			if unlocked then
				r, g, b = 1.0, 0.84, 0.0
			end

			for _, parentId in ipairs(parents) do
				local parent = nodeById[parentId]
				if parent then
					local px, py = self:getNodeScreenPos(parent, centerX, centerY, zoom)
					self:drawLineRect(px, py, cx, cy, r, g, b, 1.0)
				end
			end
		end
	end

	------------------------------------------------
	-- 2) 노드 아이콘들 그리기
	------------------------------------------------
	for _, node in ipairs(self.nodes) do
		local id = node.id
		local isUnlocked = self.nodeState and self.nodeState[id]
		local canBuyRandomBox = false
		------------------------------------------------
		-- ✅ 기본 스킬 노드용: SP로 찍을 수 있는지 여부
		------------------------------------------------
		local canUnlock = false
		if id ~= "RandomBox"                -- 랜덤박스는 SP로 안 찍음
			and (not isUnlocked)
			and (self.skillPoints or 0) > 0 then

			if self.canUnlockNode and self:canUnlockNode(id) then
				canUnlock = true
			end
		end

		------------------------------------------------
		-- 🔹 RandomBox: XP로 살 수 있으면 컬러 + 초록 테두리
		------------------------------------------------
		if id == "RandomBox" then
			local player = self.player or getSpecificPlayer(0)
			if player and RPG_GetRandomBoxPrice then
				local md    = player:getModData()
				local xp    = md.RPG_XP or 0
				local price = RPG_GetRandomBoxPrice(player)

				if xp >= price then
					isUnlocked      = true      -- 컬러 아이콘 사용
					canBuyRandomBox = true      -- 초록 테두리 표시
				else
					isUnlocked      = false     -- 회색 아이콘 사용
					canBuyRandomBox = false
				end
			end
		end


		------------------------------------------------
		-- 🔹 텍스처 선택
		------------------------------------------------
		local tex
		if isUnlocked then
			tex = node.tex or self.startNodeTex   -- 정상 컬러 아이콘
		else
			tex = self:getInactiveTextureForNode(node) or node.tex
			-- 비활성 노드는 기본적으로 회색 아이콘 사용
		end

		------------------------------------------------
		-- 🔹 아이콘 크기 계산
		------------------------------------------------
		local baseSize = SMALL_SIZE
		if BigNodeIds[node.id] then baseSize = BIG_SIZE end
		if SpecialNodeIds[node.id] then baseSize = SPECIAL_SIZE end

		local sizeMul  = node.size or 1.0
		local iconSize = baseSize * sizeMul * zoom

		local offsetX = (node.x or 0) * zoom
		local offsetY = (node.y or 0) * zoom

		local drawX = centerX + offsetX - iconSize / 2
		local drawY = centerY + offsetY - iconSize / 2

		------------------------------------------------
		-- 🔹 아이콘 그리기 (무조건 원래 텍스처)
		------------------------------------------------
		if tex then
			self:drawTextureScaled(tex, drawX, drawY, iconSize, iconSize, 1, 1, 1, 1)
		end

		------------------------------------------------
		-- 🔹 찍을 수 있는 노드 → 금빛 테두리만!
		------------------------------------------------
		if canUnlock and (not isUnlocked) then
			self:drawRectBorder(
				drawX - 3, drawY - 3,
				iconSize + 6, iconSize + 6,
				1.0,        -- alpha
				1.0, 0.84, 0.0  -- 금빛 RGB
			)
		end
		------------------------------------------------
		-- ✅ RandomBox: 구매 가능할 때 테두리
		------------------------------------------------
		if canBuyRandomBox then
			self:drawRectBorder(
				drawX - 5, drawY - 5,
				iconSize + 10, iconSize + 10,
				1.0,         -- alpha
				1.0, 0.84, 0.0
			)
		end
	end

	    ------------------------------------------------
    -- 3) 마우스 위치의 노드 찾아서 툴팁 표시
    ------------------------------------------------
    local absX = self:getAbsoluteX()
    local absY = self:getAbsoluteY()
    local mx   = getMouseX() - absX
    local my   = getMouseY() - absY

    local hovered = self:getNodeUnderPoint(mx, my, centerX, centerY, zoom)
    self.hoveredNode = hovered

    if hovered then
        local cache = self.tooltipCache or {}
        local lines = {}

        ------------------------------------------------
        -- 1) 어떤 텍스트(여러 줄)를 보여줄지 결정
        ------------------------------------------------
        local id = hovered.id

        if id == "RandomBox" then
            local player = self.player or getSpecificPlayer(0)
            local price  = 50000

            if player and RPG_GetRandomBoxPrice then
                price = RPG_GetRandomBoxPrice(player)
            end

            -- 1) 기본 설명 줄들 (번역파일에서 여러 줄 읽기)
            lines = RPG_GetNodeDescriptionLines("RandomBox")

            -- 2) 가격 줄 추가 (원하면 UI 키로도 뺄 수 있음)
            local priceLine = string.format("Price : %d XP", price)
            table.insert(lines, priceLine)

        elseif id == "AccumulatedPower" then
            -- 기본 설명 줄들
            local baseLines = RPG_GetNodeDescriptionLines("AccumulatedPower")
            for _, l in ipairs(baseLines) do
                table.insert(lines, l)
            end

            -- 쿨타임 상태 줄 추가
            local player = self.player or getSpecificPlayer(0)
            local remain = 0
            if player and RPG_GetAccumulatedPowerCooldownRemain then
                remain = RPG_GetAccumulatedPowerCooldownRemain(player) or 0
            end

            if remain <= 0 then
                -- 준비됨(Ready) 문구도 번역키로 빼고 싶으면 getText 써도 됨
                table.insert(lines, getText("UI_RPG_Status_AccumulatedReady"))
            else
                local fmt = getText("UI_RPG_Status_AccumulatedRemain")
                -- 예: "축적된 힘 남은 시간: %.1f시간"
                table.insert(lines, string.format(fmt, remain))
            end
        else
            -- 일반 노드: id 기준으로 여러 줄 가져오기
            lines = RPG_GetNodeDescriptionLines(id)
        end

        ------------------------------------------------
        -- 2) 툴팁 박스 크기 계산 (여러 줄 기준)
        ------------------------------------------------
        local font = UIFont.Small
        local tm   = getTextManager()

        -- lines 내용이 바뀌었는지 간단 비교용 문자열
        local concatKey = table.concat(lines, "\n")

        if cache.id ~= id or cache.key ~= concatKey then
            local maxW = 0
            local totalH = 0
            local lineH = tm:MeasureStringY(font, "A")

            for _, line in ipairs(lines) do
                local w = tm:MeasureStringX(font, line)
                if w > maxW then maxW = w end
                totalH = totalH + lineH
            end

            local pad = 4
            cache.id  = id
            cache.key = concatKey
            cache.w   = maxW + pad * 2
            cache.h   = totalH + pad * 2

            self.tooltipCache = cache
        end

        local pad  = 4
        local boxW = cache.w
        local boxH = cache.h
        local tipX = mx + 16
        local tipY = my + 16

        if tipX + boxW > self.width then
            tipX = self.width - boxW - 5
        end
        if tipY + boxH > self.height then
            tipY = self.height - boxH - 5
        end

        -- 박스 배경 + 테두리
        self:drawRect(tipX, tipY, boxW, boxH, 0.8, 0, 0, 0)
        self:drawRectBorder(tipX, tipY, boxW, boxH, 1, 1, 1, 0.8)

        -- 실제 텍스트 여러 줄 출력
        local lineH = tm:MeasureStringY(font, "A")
        local drawY = tipY + pad
        for _, line in ipairs(lines) do
            self:drawText(line, tipX + pad, drawY, 1, 1, 1, 1, font)
            drawY = drawY + lineH
        end
    end
end


function RPGSkillTreeUI:onNodeClicked(node)
    local id = node.id
    if not id then return end

    -- 시작 노드는 찍는 개념이 아니라 항상 활성
    if id == "Start" then return end

    -- 🔹 RandomBox: SP가 아니라 XP로 구매
    if id == "RandomBox" then
        local player = self.player or getSpecificPlayer(0)
        if player and RPG_BuyRandomBox then
            RPG_BuyRandomBox(player)  -- 여기서 XP 체크 + 차감 + 아이템 지급
        end
        return
    end

    -- 이미 찍힌 노드면 무시
    if self.nodeState[id] then return end
    -- 포인트 없으면 무시
    if self.skillPoints <= 0 then return end

    -- 🔹 선행 스킬 조건 검사
    if not self:canUnlockNode(id) then
        return
    end

    -- 🔹 포인트 소모 + 노드 활성화
    self.skillPoints = self.skillPoints - 1
    self.nodeState[id] = true

    -- 🔹 플레이어 modData에 저장
    local player = self.player or getSpecificPlayer(0)
    if player then
        local md = player:getModData()
        md.RPGSkillPoints = self.skillPoints
        md.RPGSkillNodes  = self.nodeState

        -- 🔥 스킬 효과 즉시 적용
        if RPG_UpdateAllSkillEffects then
            RPG_UpdateAllSkillEffects(player)
        end
    end
end

------------------------------------------------
-- 🔹 리셋 버튼 클릭
------------------------------------------------
function RPGSkillTreeUI.onClickReset(self, button, x, y)
    local player = self.player or getSpecificPlayer(0)
    if not player then return end

    local md = player:getModData()
    md.RPG_ResetPoints = md.RPG_ResetPoints or 0

    if md.RPG_ResetPoints <= 0 then
        if player.Say then
            player:Say("No Skill Reset Points.")
        end
        return
    end

    -- XP 시스템 쪽에 구현해 둔 함수 호출
    if RPG_ResetSkillTree then
        RPG_ResetSkillTree(player)
    else
        if player.Say then
            player:Say("Reset function not found.")
        end
    end
end


function RPGSkillTreeUI:onMouseDown(x, y)
    ISPanel.onMouseDown(self, x, y)

    -- 좌클릭을 팬 시작으로 사용
    self.isPanning = true
end

function RPGSkillTreeUI:onMouseMove(dx, dy)
    ISPanel.onMouseMove(self, dx, dy)

    if self.isPanning then
        self.panX = (self.panX or 0) + dx
        self.panY = (self.panY or 0) + dy
        self:clampPan()
    end
end



function RPGSkillTreeUI:onMouseUp(x, y)
    ISPanel.onMouseUp(self, x, y)

    self.isPanning = false

    if not self.nodes then return end

    local zoom    = self.zoom or 1.0
    local centerX = self.width  / 2 + (self.panX or 0)
    local centerY = self.height / 2 + (self.panY or 0)

    for _, node in ipairs(self.nodes) do
        local tex = node.tex or self.startNodeTex
        if tex then
            local baseSize = SMALL_SIZE
            if BigNodeIds[node.id] then baseSize = BIG_SIZE end
            if SpecialNodeIds[node.id] then baseSize = SPECIAL_SIZE end

            local sizeMul  = node.size or 1.0
            local iconSize = baseSize * sizeMul * zoom

            local offsetX = (node.x or 0) * zoom
            local offsetY = (node.y or 0) * zoom
            local drawX   = centerX + offsetX - iconSize / 2
            local drawY   = centerY + offsetY - iconSize / 2

            if x >= drawX and x <= drawX + iconSize and
               y >= drawY and y <= drawY + iconSize then
                self:onNodeClicked(node)
                break
            end
        end
    end
end


function RPGSkillTreeUI:onMouseWheel(del)
    local zoomStep = 0.1

    self.zoom = self.zoom or 1.0
    local oldZoom = self.zoom
    local newZoom = self.zoom - del * zoomStep

    if newZoom < 0.2 then newZoom = 0.2 end
    if newZoom > 2.0 then newZoom = 2.0 end

    if math.abs(newZoom - oldZoom) < 0.0001 then
        return true
    end

    local absX = self:getAbsoluteX()
    local absY = self:getAbsoluteY()
    local mx   = getMouseX() - absX
    local my   = getMouseY() - absY

    self.panX = self.panX or 0
    self.panY = self.panY or 0

    local centerX = self.width  / 2 + self.panX
    local centerY = self.height / 2 + self.panY

    local worldX = (mx - centerX) / oldZoom
    local worldY = (my - centerY) / oldZoom

    self.zoom = newZoom

    local newCenterX = mx - worldX * self.zoom
    local newCenterY = my - worldY * self.zoom

    self.panX = newCenterX - self.width  / 2
    self.panY = newCenterY - self.height / 2

    self:clampPan()
    return true
end




----------------------------------------------------------------
-- 🔻 여기부터: UI 열고/닫을 때 게임 일시정지 연동 부분
----------------------------------------------------------------

-- 스킬트리 창 닫기 함수
function RPGSkillTreeUI:close()
    -- 게임 속도 되돌리기
    if self.prevGameSpeed then
        setGameSpeed(self.prevGameSpeed)
    else
        setGameSpeed(1) -- 혹시 몰라서 기본 1배속으로
    end

    -- UI 매니저에서 제거
    self:removeFromUIManager()
    RPGSkillTreeUI.instance = nil
end

-- 스킬트리 창 열기(정적 함수)
function RPGSkillTreeUI.open(player)
    if RPGSkillTreeUI.instance then return end

    player = player or getSpecificPlayer(0)
    if not player then return end

    local core = getCore()
    local sw   = core:getScreenWidth()
    local sh   = core:getScreenHeight()

    local ui = RPGSkillTreeUI:new(0, 0, sw, sh)
    ui.player = player   -- ✅ 핵심

    local md = player:getModData()
    md.RPGSkillPoints = md.RPGSkillPoints or 0
    md.RPGSkillNodes  = md.RPGSkillNodes  or {}
    md.RPGSkillNodes["Start"] = true
    md.RPG_ResetPoints = md.RPG_ResetPoints or 0

    ui.skillPoints = md.RPGSkillPoints
    ui.nodeState   = md.RPGSkillNodes

    if RPG_UpdateAllSkillEffects then
        RPG_UpdateAllSkillEffects(player)
    end

    ui:addToUIManager()
    ui:setVisible(true)

    ui.prevGameSpeed = getGameSpeed() or 1
    setGameSpeed(0)

    RPGSkillTreeUI.instance = ui
end




----------------------------------------------------------------
-- 🔻 L 키로 스킬트리 토글 (열기/닫기)
----------------------------------------------------------------
local function RPGSkillTreeUI_onKeyPressed(key)
    if key == Keyboard.KEY_L then
        local player = getSpecificPlayer(0)
        if not player then return end

        if RPGSkillTreeUI.instance then
            RPGSkillTreeUI.instance:close()
        else
            RPGSkillTreeUI.open(player)
        end
    end
end

Events.OnKeyPressed.Add(RPGSkillTreeUI_onKeyPressed)

