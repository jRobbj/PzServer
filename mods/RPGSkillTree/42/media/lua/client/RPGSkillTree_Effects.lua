---------------------------------------------------------
-- RPGSkillTree_Effects.lua
-- 스킬트리 노드 상태를 실제 게임 스탯에 반영하는 곳
---------------------------------------------------------

--  전역
RPG_HUNGER_GAIN_FACTOR = RPG_HUNGER_GAIN_FACTOR or 1.0
RPG_THIRST_GAIN_FACTOR = RPG_THIRST_GAIN_FACTOR or 1.0
RPG_STAMINA_REGEN_FACTOR = RPG_STAMINA_REGEN_FACTOR or 1.0
RPG_STRESS_GAIN_FACTOR   = RPG_STRESS_GAIN_FACTOR   or 1.0
RPG_ZOMBIE_XP_FACTOR     = RPG_ZOMBIE_XP_FACTOR     or 1.0
RPG_LOOT_EXTRA_CHANCE    = RPG_LOOT_EXTRA_CHANCE    or 0.0
RPG_WORK_SPEED_FACTOR    = RPG_WORK_SPEED_FACTOR    or 1.0
RPG_VEHICLE_COLLISION_DAMAGE_FACTOR  = RPG_VEHICLE_COLLISION_DAMAGE_FACTOR  or 1.0
RPG_VEHICLE_DURABILITY_LOSS_FACTOR   = RPG_VEHICLE_DURABILITY_LOSS_FACTOR   or 1.0
RPG_VEHICLE_HP_FACTOR                = RPG_VEHICLE_HP_FACTOR                or 1.0
RPG_STOMP_DAMAGE_FACTOR   = RPG_STOMP_DAMAGE_FACTOR   or 1.0
RPG_XPVER2_CHANCE = RPG_XPVER2_CHANCE or 0         -- 전체 보너스 확률 (%)
RPG_XPVER2_DESC   = RPG_XPVER2_DESC   or nil       -- Status UI용 텍스트
RPG_ITEM_XP_FACTOR = RPG_ITEM_XP_FACTOR or 1.0   -- 장비 아이템에서 오는 추가 XP 배수
RPG_BOX_RARE_CHANCE_FACTOR       = RPG_BOX_RARE_CHANCE_FACTOR       or 1.0
RPG_BOX_UPGRADE_CHANCE_NORMAL    = RPG_BOX_UPGRADE_CHANCE_NORMAL    or 0.0  -- Normal → Rare 확률 (0~1)
RPG_BOX_UPGRADE_CHANCE_RARE      = RPG_BOX_UPGRADE_CHANCE_RARE      or 0.0  -- Rare   → Legendary 확률 (0~1)

---------------------------------------------------------
-- 🔹 모든 스킬 효과를 다시 계산해서 적용
--   - playerObj: 옵션. 없으면 player0 기준.
---------------------------------------------------------
function RPG_UpdateAllSkillEffects(playerObj)
    local player = playerObj or getSpecificPlayer(0)
    if not player then return end

    local md = player:getModData()
    md.RPGSkillNodes = md.RPGSkillNodes or {}
    local nodes = md.RPGSkillNodes

    -------------------------------------------------
    -- 0) 기본 소지무게를 한 번만 저장
    --    (스킬 효과 계산은 항상 이 값을 기준으로 한다)
    -------------------------------------------------
    if not md.RPG_BaseMaxWeight then
        md.RPG_BaseMaxWeight = player:getMaxWeightBase()
    end
    local baseWeight = md.RPG_BaseMaxWeight

    -------------------------------------------------
    -- 1) 배고픔 증가량 감소 / 증가 계수 계산
    --    Hunger1~4 : 각각 -5%
    --    SnowlandHunter : -30%
    --    InnerStrength : Hunger +200% (배고픔 3배)
    -------------------------------------------------
    local hungerNodes = 0

    if nodes.Hunger1        then hungerNodes = hungerNodes + 1 end
    if nodes.Hunger2        then hungerNodes = hungerNodes + 1 end
    if nodes.Hunger3        then hungerNodes = hungerNodes + 1 end
    if nodes.Hunger4        then hungerNodes = hungerNodes + 1 end

    local hungerFactor = 1.0
    hungerFactor = hungerFactor - 0.05 * hungerNodes   -- Hunger1~4: 각각 -5%

    if nodes.SnowlandHunter then
        hungerFactor = hungerFactor - 0.30             -- SnowlandHunter: -30%
    end

    -- InnerStrength : 배고픔 3배
    if nodes.InnerStrength then
        hungerFactor = hungerFactor * 3.0
    end

    -- 🔹 귀걸이 Hunger 감소 보정 적용 (Rare/Legendary)
    local itemHungerFactor = md.RPG_ITEM_HUNGER_FACTOR or 1.0
    hungerFactor = hungerFactor * itemHungerFactor

    -- 너무 과하거나 음수 방지
    if hungerFactor < 0.1 then hungerFactor = 0.1 end
    if hungerFactor > 3.0 then hungerFactor = 3.0 end

    RPG_HUNGER_GAIN_FACTOR = hungerFactor


    -------------------------------------------------
    -- 2) 목마름 증가량 감소 / 증가 계수 계산
    --    Water1~4 : 각각 -5%
    --    DesertPioneer : -30%
    --    TrainingOptimism : Thirst +200% (갈증 3배)
    -------------------------------------------------
    local waterNodes = 0

    if nodes.Water1 then waterNodes = waterNodes + 1 end
    if nodes.Water2 then waterNodes = waterNodes + 1 end
    if nodes.Water3 then waterNodes = waterNodes + 1 end
    if nodes.Water4 then waterNodes = waterNodes + 1 end

    local thirstFactor = 1.0
    thirstFactor = thirstFactor - 0.05 * waterNodes  -- Water 1~4 (각 -5%)

    if nodes.DesertPioneer then
        thirstFactor = thirstFactor - 0.30           -- Desert Pioneer (-30%)
    end

    -- Training Optimism: Thirst 3배
    if nodes.TrainingOptimism then
        thirstFactor = thirstFactor * 3.0
    end

    local itemThirstFactor = md.RPG_ITEM_THIRST_FACTOR or 1.0
    thirstFactor = thirstFactor * itemThirstFactor

    -- 범위 제한
    if thirstFactor < 0.1 then thirstFactor = 0.1 end
    if thirstFactor > 3.0 then thirstFactor = 3.0 end

    RPG_THIRST_GAIN_FACTOR = thirstFactor

    -------------------------------------------------
    -- 3) 소지 무게 증가 계산 (트리 + 아이템 배수)
    -------------------------------------------------
    local weightNodes = 0
    if nodes.Weight1 then weightNodes = weightNodes + 1 end
    if nodes.Weight2 then weightNodes = weightNodes + 1 end
    if nodes.Weight3 then weightNodes = weightNodes + 1 end
    if nodes.Weight4 then weightNodes = weightNodes + 1 end

    local weightFactor = 1.0 + weightNodes * 0.025

    if nodes.WeightBig then
        weightFactor = weightFactor + 0.20
    end
    if nodes.GravityAdaptation then
        weightFactor = weightFactor + 0.50
    end

    local itemWeightMul = RPG_ITEM_WEIGHT_MUL or 1.0

    local finalWeight = baseWeight * weightFactor * itemWeightMul
    if finalWeight < 1 then finalWeight = 1 end
    player:setMaxWeightBase(finalWeight)

    -------------------------------------------------
    -- 4) 스태미나 소모 감소 계산
    --    Stamina1~4 : 각각 -5%
    --    EndlessCycle : -30%
    -------------------------------------------------
    local staminaNodes = 0

    if nodes.Stamina1 then staminaNodes = staminaNodes + 1 end
    if nodes.Stamina2 then staminaNodes = staminaNodes + 1 end
    if nodes.Stamina3 then staminaNodes = staminaNodes + 1 end
    if nodes.Stamina4 then staminaNodes = staminaNodes + 1 end

    local staminaFactor = 1.0
    staminaFactor = staminaFactor - staminaNodes * 0.05   -- 5%씩 감소

    if nodes.EndlessCycle then
        staminaFactor = staminaFactor - 0.30              -- 추가 30%
    end

    if staminaFactor < 0.1 then staminaFactor = 0.1 end   -- 최소 90% 감소
    if staminaFactor > 1.0 then staminaFactor = 1.0 end   -- 최대 감소 없음

    RPG_STAMINA_DRAIN_FACTOR = staminaFactor

    -------------------------------------------------
    -- 5) 스태미나 회복 속도 계산
    --    StaminaRegen1~4 : 각각 +10%
    --    CombatSwimBreath : +60%
    -------------------------------------------------
    local regenNodes = 0

    if nodes.StaminaRegen1     then regenNodes = regenNodes + 1 end
    if nodes.StaminaRegen2     then regenNodes = regenNodes + 1 end
    if nodes.StaminaRegen3     then regenNodes = regenNodes + 1 end
    if nodes.StaminaRegen4     then regenNodes = regenNodes + 1 end

    local staminaRegenFactor = 1.0 + regenNodes * 0.10   -- 노드당 +10%

    if nodes.CombatSwimBreath then
        staminaRegenFactor = staminaRegenFactor + 0.60   -- +60%
    end

    if staminaRegenFactor < 0.1 then staminaRegenFactor = 0.1 end
    RPG_STAMINA_REGEN_FACTOR = staminaRegenFactor

    -------------------------------------------------
    -- 6) Sprinting / Nimble XP 책버프식 배수 적용
    -------------------------------------------------
    local xp = player:getXp()
    if xp then
        local map = xp:getMultiplierMap()

        -------------------------------------------------
        -- 6-1) Sprinting XP 배수
        -------------------------------------------------
        local perkSprint = Perks.Sprinting

        if map then
            map:remove(perkSprint)   -- 기존 스프린트 배수 초기화
        end

        if nodes.Sprint1 then
            xp:addXpMultiplier(perkSprint, 1, 0, 10)
        end
        if nodes.Sprint2 then
            xp:addXpMultiplier(perkSprint, 2, 0, 10)
        end
        if nodes.PrimalInstinct then
            xp:addXpMultiplier(perkSprint, 8, 0, 10)
        end
        if nodes.Sprint3 then
            xp:addXpMultiplier(perkSprint, 9, 0, 10)
        end
        if nodes.Sprint4 then
            xp:addXpMultiplier(perkSprint, 10, 0, 10)
        end

        -------------------------------------------------
        -- 6-2) Nimble XP 배수 (Walk 트리)
        -------------------------------------------------
        local perkNimble = Perks.Nimble

        if map then
            map:remove(perkNimble)   -- 기존 님블 배수 초기화
        end

        if nodes.Walk1 then
            xp:addXpMultiplier(perkNimble, 1, 0, 10)
        end
        if nodes.Walk2 then
            xp:addXpMultiplier(perkNimble, 2, 0, 10)
        end
        if nodes.Gladiator then
            xp:addXpMultiplier(perkNimble, 8, 0, 10)
        end
        if nodes.Walk3 then
            xp:addXpMultiplier(perkNimble, 9, 0, 10)
        end
        if nodes.Walk4 then
            xp:addXpMultiplier(perkNimble, 10, 0, 10)
        end
    end

    -------------------------------------------------
    -- 7) 스트레스 증가량 감소 계산
    -------------------------------------------------
    local stressNodes = 0

    if nodes.Stress1       then stressNodes = stressNodes + 1 end
    if nodes.Stress2       then stressNodes = stressNodes + 1 end
    if nodes.Stress3       then stressNodes = stressNodes + 1 end
    if nodes.Stress4       then stressNodes = stressNodes + 1 end

    local stressFactor = 1.0
    stressFactor = stressFactor - 0.05 * stressNodes

    if nodes.TunnelRats then
        stressFactor = stressFactor - 0.30
    end

    if stressFactor < 0.1 then stressFactor = 0.1 end  -- 최소 90% 감소
    if stressFactor > 1.0 then stressFactor = 1.0 end  -- 기본 이상은 안 올라가게

    RPG_STRESS_GAIN_FACTOR = stressFactor

    -------------------------------------------------
    -- 8) 공황 증가량 감소 계산
    -------------------------------------------------
    local panicNodes = 0

    if nodes.Panic1 then panicNodes = panicNodes + 1 end
    if nodes.Panic2 then panicNodes = panicNodes + 1 end
    if nodes.Panic3 then panicNodes = panicNodes + 1 end
    if nodes.Panic4 then panicNodes = panicNodes + 1 end

    local panicFactor = 1.0 - (panicNodes * 0.05)

    if nodes.CombatVeteran then
        panicFactor = panicFactor - 0.30
    end

    if panicFactor < 0.10 then panicFactor = 0.10 end
    if panicFactor > 1.0  then panicFactor = 1.0  end

    RPG_PANIC_GAIN_FACTOR = panicFactor

    -------------------------------------------------
    -- 9) 좀비 처치 XP 증가량 배수 계산
    -------------------------------------------------
    local xpNodes = 0

    if nodes.XPgain1 then xpNodes = xpNodes + 1 end
    if nodes.XPgain2 then xpNodes = xpNodes + 1 end
    if nodes.XPgain3 then xpNodes = xpNodes + 1 end
    if nodes.XPgain4 then xpNodes = xpNodes + 1 end

    local zombieXPFactor = 1.0 + xpNodes * 0.25

    if nodes.WeaknessDetection then
        zombieXPFactor = zombieXPFactor + 1.0
    end

    if zombieXPFactor < 1.0 then
        zombieXPFactor = 1.0
    end

    RPG_ZOMBIE_XP_FACTOR = zombieXPFactor

    -------------------------------------------------
    -- 9-1) XP Ver2 (1% 확률로 큰 XP 보너스) - 설명용 변수
    -------------------------------------------------
    do
        local bonusChance = 0
        local parts = {}

        if nodes.XPVer21 then
            bonusChance = bonusChance + 1
            table.insert(parts, "x25")
        end
        if nodes.XPVer22 then
            bonusChance = bonusChance + 0
            table.insert(parts, "x25")
        end
        if nodes.XPVer2Big then
            bonusChance = bonusChance + 0
            table.insert(parts, "x100")
        end

        RPG_XPVER2_CHANCE = bonusChance or 0

        if bonusChance > 0 then
            local list = table.concat(parts, ", ")
            RPG_XPVER2_DESC = string.format(
                "Bonus XP: %d%% chance (%s)",
                bonusChance,
                list
            )
        else
            RPG_XPVER2_DESC = nil
        end
    end

    -------------------------------------------------
    -- 10) 우울(불행) 회복 속도 - TrainingOptimism
    -------------------------------------------------
    RPG_UNHAPPY_RECOVERY_RATE = 0.0

    if nodes.TrainingOptimism then
        RPG_UNHAPPY_RECOVERY_RATE = 30.0
    end

    -------------------------------------------------
    -- 11) Running / Nimble XP 배수 상태 텍스트
    -------------------------------------------------
    RPG_SPRINT_XP_DESC = nil
    RPG_NIMBLE_XP_DESC = nil

    do
        -- Nimble
        local nimbleMul = 0
        if nodes.Walk1 then nimbleMul = 1 end
        if nodes.Walk2 then nimbleMul = 2 end
        if nodes.Gladiator then nimbleMul = 8 end
        if nodes.Walk3 then nimbleMul = 9 end
        if nodes.Walk4 then nimbleMul = 10 end

        if nimbleMul > 0 then
            RPG_NIMBLE_XP_DESC = string.format("Nimble XP x%d", nimbleMul)
        end

        -- Running
        local sprintMul = 0
        if nodes.Sprint1 then sprintMul = 1 end
        if nodes.Sprint2 then sprintMul = 2 end
        if nodes.PrimalInstinct then sprintMul = 8 end
        if nodes.Sprint3 then sprintMul = 9 end
        if nodes.Sprint4 then sprintMul = 10 end

        if sprintMul > 0 then
            RPG_SPRINT_XP_DESC = string.format("Running XP x%d", sprintMul)
        end
    end

    -------------------------------------------------
    -- 12) 루팅 추가 횟수 확률
    --     Item1 : +2.5%
    --     Item2 : +2.5%
    --     ItemBig : +10%
    -------------------------------------------------
    local extraLootChance = 0.0

    if nodes.Item1 then
        extraLootChance = extraLootChance + 0.025
    end
    if nodes.Item2 then
        extraLootChance = extraLootChance + 0.025
    end
    if nodes.ItemBig then
        extraLootChance = extraLootChance + 0.10
    end

    RPG_LOOT_EXTRA_CHANCE = extraLootChance
	
	-------------------------------------------------
    -- 13) RandomBox 희귀 상자 업그레이드 확률
    --     BoxChance1/2/3 :
    --       Normal → Rare     : 기본 2% + 노드당 2%
    --       Rare   → Legendary: 기본 2% + 노드당 2%
    -------------------------------------------------
    do
        local boxChanceNodes = 0
        if nodes.BoxChance1 then boxChanceNodes = boxChanceNodes + 1 end
        if nodes.BoxChance2 then boxChanceNodes = boxChanceNodes + 1 end
        if nodes.BoxChance3 then boxChanceNodes = boxChanceNodes + 1 end

        local baseNormal      = 0.02   -- 3%
        local baseRare        = 0.02   -- 3%
        local perNodeNormal   = 0.02   -- 노드당 3%
        local perNodeRare     = 0.02   -- 노드당 3%

        local upgradeNormal   = baseNormal + perNodeNormal * boxChanceNodes
        local upgradeRare     = baseRare   + perNodeRare   * boxChanceNodes

        -- 안전빵으로 상한
        if upgradeNormal > 0.9 then upgradeNormal = 0.9 end
        if upgradeRare   > 0.9 then upgradeRare   = 0.9 end

        RPG_BOX_UPGRADE_CHANCE_NORMAL = upgradeNormal
        RPG_BOX_UPGRADE_CHANCE_RARE   = upgradeRare

        -- Status UI용: 1.0 기준으로 몇 % 증가인지 보여주는 배수
        RPG_BOX_RARE_CHANCE_FACTOR = 1.0 + boxChanceNodes * 1.0  -- 노드당 +100% 느낌
    end

    -------------------------------------------------
    -- 13) 작업 속도 배수 (Work1/2/3)
    -------------------------------------------------
    do
        local workNodes = 0
        if nodes.Work1 then workNodes = workNodes + 1 end
        if nodes.Work2 then workNodes = workNodes + 1 end
        if nodes.Work3 then workNodes = workNodes + 1 end

        local workSpeedFactor = 1.0 + workNodes * 0.50
        RPG_WORK_SPEED_FACTOR = workSpeedFactor
    end

    -------------------------------------------------
    -- 14) 차량 스킬 계수 (Status UI용 전역만 세팅)
    -------------------------------------------------
    do
        local collisionFactor  = 1.0
        local durabilityFactor = 1.0
        local hpFactor         = 1.0

        if nodes.CarDamage then
            collisionFactor = 0.7
        end
        if nodes.CarBreak then
            durabilityFactor = 0.7
        end
        if nodes.CarHP then
            hpFactor = 1.3
        end

        RPG_VEHICLE_COLLISION_DAMAGE_FACTOR = collisionFactor
        RPG_VEHICLE_DURABILITY_LOSS_FACTOR  = durabilityFactor
        RPG_VEHICLE_HP_FACTOR               = hpFactor
    end

    -- 디버그 보고 싶으면 사용
    -- print(string.format("[RPG] Hunger=%.2f, Thirst=%.2f", RPG_HUNGER_GAIN_FACTOR, RPG_THIRST_GAIN_FACTOR))
end

---------------------------------------------------------
-- 🔹 차량 스킬 효과 적용 (HP / 속도 / 질량 / 오프로드)
--    매 틱마다 부르지 않고, OnPlayerUpdate 래퍼에서
--    몇 프레임에 한 번씩만 호출하도록 설계
---------------------------------------------------------
function RPG_UpdateVehicleSkillEffects(player)
    if not player or player:isDead() then return end
    if not player:isDriving() then return end

    local vehicle = player:getVehicle()
    if not vehicle then return end

    local vmd = vehicle:getModData()
    local md  = player:getModData() or {}
    local nodes = md.RPGSkillNodes or {}

    ------------------------------------------------
    -- 🔸 차량 기본값을 처음 한 번만 저장
    ------------------------------------------------
    if not vmd.RPG_BaseBrakingForce then
        vmd.RPG_BaseBrakingForce    = vehicle:getBrakingForce()
        vmd.RPG_BaseMaxSpeed        = vehicle:getMaxSpeed()
        vmd.RPG_BaseEngineQuality   = vehicle:getEngineQuality()
        vmd.RPG_BaseEngineLoudness  = vehicle:getEngineLoudness()
        vmd.RPG_BaseEnginePower     = vehicle:getEnginePower()
        vmd.RPG_BaseMass            = vehicle:getMass()
        vmd.RPG_BaseInitialMass     = vehicle:getInitialMass()
        vmd.RPG_BaseOffRoadEff      = vehicle:getScript():getOffroadEfficiency()
        vmd.RPG_BaseRegulatorSpeed  = vehicle:getRegulatorSpeed()
    end

    local baseBrake    = vmd.RPG_BaseBrakingForce
    local baseMaxSpd   = vmd.RPG_BaseMaxSpeed
    local baseEq       = vmd.RPG_BaseEngineQuality
    local baseLoud     = vmd.RPG_BaseEngineLoudness
    local basePower    = vmd.RPG_BaseEnginePower
    local baseMass     = vmd.RPG_BaseMass
    local baseInitMass = vmd.RPG_BaseInitialMass
    local baseOffroad  = vmd.RPG_BaseOffRoadEff
    local baseRegSpd   = vmd.RPG_BaseRegulatorSpeed

    if not baseBrake or not basePower then
        return
    end

    ------------------------------------------------
    -- 🔸 스킬에 따른 계수 계산
    ------------------------------------------------
    local collisionMul  = 1.0  -- CarDamage  : 차량 충돌 데미지 배수
    local durabilityMul = 1.0  -- CarBreak   : 차량 내구도 감소 배수
    local hpMul         = 1.0  -- CarHP      : 엔진 파워/마력 배수

    if nodes.CarDamage then
        collisionMul = 0.7
    end
    if nodes.CarBreak then
        durabilityMul = 0.7
    end
    if nodes.CarHP then
        hpMul = 1.3
    end

    RPG_VEHICLE_COLLISION_DAMAGE_FACTOR = collisionMul
    RPG_VEHICLE_DURABILITY_LOSS_FACTOR  = durabilityMul
    RPG_VEHICLE_HP_FACTOR               = hpMul

    ------------------------------------------------
    -- 🔸 실제 차량 스펙에 반영
    ------------------------------------------------
    -- 1) 엔진/속도 계열
    local newPower  = basePower * hpMul
    local newMaxSpd = baseMaxSpd * hpMul
    local newRegSpd = baseRegSpd * hpMul

    vehicle:setEngineFeature(baseEq, baseLoud, newPower)
    vehicle:setMaxSpeed(newMaxSpd)
    vehicle:setRegulatorSpeed(newRegSpd)

    -- 2) 질량/오프로드 계열
    local massMul    = 1.0
    local offroadMul = 1.0

    if nodes.CarDamage then
        massMul = massMul * 0.8       -- 20% 가볍게
    end
    if nodes.CarBreak then
        offroadMul = offroadMul * 1.2 -- 20% 효율 증가
    end

    vehicle:setMass(baseMass * massMul)
    vehicle:setInitialMass(baseInitMass * massMul)
    vehicle:updateTotalMass()
    vehicle:getScript():setOffroadEfficiency(baseOffroad * offroadMul)

    vehicle:setBrakingForce(baseBrake)
end

---------------------------------------------------------
-- 🔹 OnPlayerUpdate 에서 차량 효과를 주기적으로만 갱신
---------------------------------------------------------
local RPG_VehicleUpdateCounter = 0

local function RPG_OnPlayerUpdate_Vehicle(player)
    if not player or player:isDead() then return end
    if player ~= getSpecificPlayer(0) then return end

    -- 10프레임마다 한 번만 갱신 (원하면 숫자 조절)
    RPG_VehicleUpdateCounter = (RPG_VehicleUpdateCounter + 1) % 10
    if RPG_VehicleUpdateCounter ~= 0 then
        return
    end

    RPG_UpdateVehicleSkillEffects(player)
end

if not RPG_VehicleEventRegistered then
    Events.OnPlayerUpdate.Add(RPG_OnPlayerUpdate_Vehicle)
    RPG_VehicleEventRegistered = true
end

---------------------------------------------------------
-- 🔹 Weight of Life : 스톰프 대미지 +100%
---------------------------------------------------------
function RPG_WeightOfLife_StompUpdate(player)
    if not player or player:isDead() then return end

    local md = player:getModData()
    md.RPGSkillNodes = md.RPGSkillNodes or {}
    local nodes = md.RPGSkillNodes

    local hasWeightOfLife = nodes.WeightofLife == true

    local shoes = player:getClothingItem_Feet()
    if not shoes then
        return
    end

    local itemdata = shoes:getModData()
    local origstomp = itemdata.RPG_OrigStomp

    if origstomp == nil then
        origstomp = shoes:getStompPower()
        itemdata.RPG_OrigStomp  = origstomp
        itemdata.RPG_StompState = "Normal"
    end

    if hasWeightOfLife then
        if itemdata.RPG_StompState ~= "WeightOfLife" then
            local newstomp = origstomp * 2.0 -- +100%
            shoes:setStompPower(newstomp)
            itemdata.RPG_StompState = "WeightOfLife"
        end
    else
        if shoes:getStompPower() ~= origstomp then
            shoes:setStompPower(origstomp)
            itemdata.RPG_StompState = "Normal"
        end
    end
end

---------------------------------------------------------
-- 🔹 OnPlayerUpdate 에서 Weight of Life 도 주기적으로만 체크
---------------------------------------------------------
local RPG_WeightOfLifeCounter = 0

local function RPG_OnPlayerUpdate_WeightOfLife(player)
    if not player or player:isDead() then return end
    if player ~= getSpecificPlayer(0) then return end

    -- 10프레임마다 한 번만 체크
    RPG_WeightOfLifeCounter = (RPG_WeightOfLifeCounter + 1) % 10
    if RPG_WeightOfLifeCounter ~= 0 then
        return
    end

    RPG_WeightOfLife_StompUpdate(player)
end

if not RPG_WeightOfLifeEventRegistered then
    Events.OnPlayerUpdate.Add(RPG_OnPlayerUpdate_WeightOfLife)
    RPG_WeightOfLifeEventRegistered = true
end

---------------------------------------------------------
--  - VeteranPartisan 스킬
--    전력질주 중 근처 좀비를 들이받아 넘어뜨림
--  - B42.13 / 멀티 대응 / CharacterStat.ENDURANCE 사용
---------------------------------------------------------

local STAMINA_HIT_ON_CHARGE = 0.00002   -- 0~100 스탯 기준 매우 약한 소모

---------------------------------------------------------
-- 🧟 좀비 넉다운
---------------------------------------------------------
local function RPG_KnockdownZombie(zombie, player)
    if not zombie or zombie:isDead() then return end
    if not player then return end

    if zombie:isKnockedDown() or zombie:isOnFloor() then
        return
    end

    zombie:setKnockedDown(true)
    zombie:setOnFloor(true)
    zombie:changeState(ZombieOnGroundState.instance())
end

---------------------------------------------------------
-- 🎯 플레이어 방향 벡터 계산
---------------------------------------------------------
local function RPG_GetForwardVector(player)
    local dir = player:getDirectionAngle() -- radian
    return math.cos(dir), math.sin(dir)
end

---------------------------------------------------------
-- 🎯 정면 각도 판정
---------------------------------------------------------
local function RPG_IsInFront(player, zombie, maxAngleDeg)
    if not player or not zombie then return false end

    local px, py = player:getX(), player:getY()
    local zx, zy = zombie:getX(), zombie:getY()
    local vx, vy = zx - px, zy - py

    local distSq = vx*vx + vy*vy
    if distSq <= 0.0001 then return false end

    local len = math.sqrt(distSq)
    vx, vy = vx/len, vy/len

    local fx, fy = RPG_GetForwardVector(player)
    local dot = fx * vx + fy * vy
    dot = math.max(-1, math.min(1, dot))

    local angle = math.deg(math.acos(dot))
    return angle <= (maxAngleDeg or 120)
end

---------------------------------------------------------
-- ⭐ VeteranPartisan 핵심 로직
---------------------------------------------------------
local function RPG_VeteranPartisan_Update(player)
    if not player or player:isDead() then return end
    if player.isZombie and player:isZombie() then return end

    -- 스킬 체크
    local md = player:getModData()
    if not md then return end
    md.RPGSkillNodes = md.RPGSkillNodes or {}
    if not md.RPGSkillNodes.VeteranPartisan then return end

    -- 전력질주 체크
    if not player.isSprinting or not player:isSprinting() then
        return  -- 전력질주 아닐 때는 절대 계산 안함
    end

    local cell = getCell()
    if not cell then return end

    local radius = 3.0
    local radiusSq = radius * radius
    local maxAngle = 120

    local px, py = player:getX(), player:getY()
    local zombies = cell:getZombieList()
    if not zombies then return end

    for i = 0, zombies:size()-1 do
        local z = zombies:get(i)
        if z and not z:isDead() then

            local dx = z:getX() - px
            local dy = z:getY() - py
            local distSq = dx*dx + dy*dy

            if distSq <= radiusSq then
                if RPG_IsInFront(player, z, maxAngle) then
                    -- 🔹 넉다운
                    RPG_KnockdownZombie(z, player)

                    -- 🔹 전력질주 충돌 시 스태미나 감소
                    local stats = player.getStats and player:getStats()
                    if stats and stats.get and stats.set and CharacterStat and CharacterStat.ENDURANCE then
                        local now = stats:get(CharacterStat.ENDURANCE) or 0
                        local newVal = math.max(0, now - STAMINA_HIT_ON_CHARGE)
                        stats:set(CharacterStat.ENDURANCE, newVal)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------
-- 🔥 전력질주 중에는 매 프레임 계산
---------------------------------------------------------

local function RPG_OnPlayerUpdate_VeteranPartisan(player)
    if not player or player:isDead() then return end
    if player.isZombie and player:isZombie() then return end

    -- 전력질주 중이면 매 프레임 실행
    if player.isSprinting and player:isSprinting() then
        RPG_VeteranPartisan_Update(player)
    end
end

Events.OnPlayerUpdate.Add(RPG_OnPlayerUpdate_VeteranPartisan)




---------------------------------------------------------
-- 🔹 RandomBox 가격 계산 (BoxPrice1/2/3 할인 반영)
---------------------------------------------------------
function RPG_GetRandomBoxPrice(player)
    local pl = player or getSpecificPlayer(0)
    if not pl then
        return 50000
    end

    local md    = pl:getModData()
    local nodes = md.RPGSkillNodes or {}

    local basePrice = 50000
    local discount  = 0

    if nodes.BoxPrice1 then discount = discount + 5000 end
    if nodes.BoxPrice2 then discount = discount + 5000 end
    if nodes.BoxPrice3 then discount = discount + 5000 end

    local finalPrice = basePrice - discount
    if finalPrice < 0 then
        finalPrice = 0
    end

    return finalPrice
end

---------------------------------------------------------
-- 🔹 RandomBox 구매 (XP 소모 → Randombox_Normal 획득)
---------------------------------------------------------
function RPG_BuyRandomBox(player)
    local pl = player or getSpecificPlayer(0)
    if not pl or pl:isDead() then
        return
    end

    local md = pl:getModData()
    md.RPG_XP = md.RPG_XP or 0

    local price = RPG_GetRandomBoxPrice(pl)

    -- 가격이 0 이하이면 그냥 막 눌러도 되긴 한데, 방지용
    if price <= 0 then
        price = 0
    end

    if md.RPG_XP < price then
        if pl.Say then
            pl:Say("Not enough XP.")
        end
        return
    end

    -- XP 차감
    md.RPG_XP = md.RPG_XP - price

    -- 상자 지급
    local inv = pl:getInventory()
    if inv then
        inv:AddItem("Base.Randombox_Normal")
    end

    if pl.Say then
        pl:Say("Purchased a RandomBox.")
    end
end


-------------------------------------------------
-- 🔹 항상 스킬 효과/무게/스탯이 적용되도록 글로벌 업데이트
-------------------------------------------------
-- 마지막으로 스킬 효과를 다시 계산한 게임 시간
local RPG_LastSkillEffectUpdateTime = 0

local function RPG_OnPlayerUpdate_Global(player)
    if not player or player:isDead() then return end
    if player ~= getSpecificPlayer(0) then return end

    local gt  = getGameTime()
    local now = gt and gt:getWorldAgeHours() or 0

    -- ▶ 여기서 주기 조절
    -- 0.005 시간 = 약 18초. 너무 길면 0.002(7.2초) 같은 걸로 줄여도 됨.
    if now - RPG_LastSkillEffectUpdateTime < 0.005 then
        return
    end
    RPG_LastSkillEffectUpdateTime = now

    if RPG_UpdateAllSkillEffects then
        RPG_UpdateAllSkillEffects(player)
    end
end

if not RPG_GlobalUpdateEventRegistered then
    Events.OnPlayerUpdate.Add(RPG_OnPlayerUpdate_Global)
    RPG_GlobalUpdateEventRegistered = true
end


Events.OnPlayerUpdate.Add(RPG_OnPlayerUpdate_VeteranPartisan)
