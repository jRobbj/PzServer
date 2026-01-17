-------------------------------------------------
-- RPGSkillTree_Randombox.lua
-- B42 craftRecipe + Recipe.OnCreate 기반 랜덤박스
-- 상자 진급 확률 + 스킬(BoxChance1/2/3) 반영 버전
-------------------------------------------------

require "RPGSkillTree_Effects"

if not Recipe then Recipe = {} end
Recipe.OnCreate = Recipe.OnCreate or {}

-------------------------------------------------
-- 공통: 유효한 플레이어 얻기
-------------------------------------------------
local function getValidPlayer(player)
    local pl = player or getSpecificPlayer(0)
    if not pl or pl:isDead() then
        return nil
    end
    return pl
end

-------------------------------------------------
-- 공통: 스킬로 상자 진급 확률 보너스 계산
--  BoxChance1 / BoxChance2 / BoxChance3
--  각 +2%씩 증가 (총 +6%까지)
-------------------------------------------------
local function getLootUpgradeBonus(player)
    if not player then return 0 end

    local md    = player:getModData() or {}
    local nodes = md.RPGSkillNodes or {}
    local bonus = 0

    if nodes.BoxChance1 then bonus = bonus + 2 end   -- +2%
    if nodes.BoxChance2 then bonus = bonus + 2 end   -- +2%
    if nodes.BoxChance3 then bonus = bonus + 2 end   -- +2% (최대 +15%)

    return bonus
end

-------------------------------------------------
-- NORMAL Randombox
--  기본 드랍 → 마지막에 Rare 박스로 "진급"할 기회
-------------------------------------------------
function Recipe.OnCreate.OpenRandombox_Normal(items, result, player)
    local pl = getValidPlayer(player)
    if not pl then return end

    local inv = pl:getInventory()
    if not inv then return end

    -------------------------------------------------
    -- 1) 기본 드랍 아이템 결정
    -------------------------------------------------
    local roll = ZombRand(4)  -- 0 ~ 99
    local rewardFullType

    if roll < 1 then
        rewardFullType = "RPGSkillTree.Necklace_of_Memories_Normal"

    elseif roll < 2 then
        rewardFullType = "RPGSkillTree.Necklace_of_Strength_Normal"

    elseif roll < 3 then
        rewardFullType = "RPGSkillTree.Bag_HydrationBackpack_Normal"

    else -- 4
        rewardFullType = "RPGSkillTree.Bag_ALICE_BeltSus_Normal"
    end

    -------------------------------------------------
    -- 2) 상자 진급 판정 (Normal → Rare)
    --    기본 3% + BoxChance1/2/3 보너스
    -------------------------------------------------
    local baseChance  = 2      -- 기본 진급 확률(%)
    local bonus       = getLootUpgradeBonus(pl)
    local finalChance = baseChance + bonus

    if finalChance > 0 and ZombRand(100) < finalChance then
        -- 희귀 상자로 진급!
        rewardFullType = "Base.Randombox_Rare"
    end

    -------------------------------------------------
    -- 3) 최종 아이템 지급
    -------------------------------------------------
    inv:AddItem(rewardFullType)
end

-------------------------------------------------
-- RARE Randombox
--  기본 드랍 → 마지막에 Legendary 박스로 "진급"할 기회
-------------------------------------------------
function Recipe.OnCreate.OpenRandombox_Rare(items, result, player)
    local pl = getValidPlayer(player)
    if not pl then return end

    local inv = pl:getInventory()
    if not inv then return end

    -------------------------------------------------
    -- 1) 기본 드랍 아이템 결정
    -------------------------------------------------
    local roll = ZombRand(6)  -- 0 ~ 99
    local rewardFullType

    if roll < 1 then
        rewardFullType = "RPGSkillTree.Necklace_of_Memories_Rare"

    elseif roll < 2 then
        rewardFullType = "RPGSkillTree.Necklace_of_Strength_Rare"

    elseif roll < 3 then
        rewardFullType = "RPGSkillTree.Forest_Earrings_Rare"

    elseif roll < 4 then
        rewardFullType = "RPGSkillTree.Dew_Beaded_Ring_Rare"

    elseif roll < 5 then
        rewardFullType = "RPGSkillTree.Bag_HydrationBackpack_Rare"

    else -- 6
        rewardFullType = "RPGSkillTree.Bag_ALICE_BeltSus_Rare"
    end

    -------------------------------------------------
    -- 2) 상자 진급 판정 (Rare → Legendary)
    --    기본 4% + BoxChance1/2/3 보너스
    -------------------------------------------------
    local baseChance  = 2      -- Rare → Legendary 기본 진급 확률(%)
    local bonus       = getLootUpgradeBonus(pl)
    local finalChance = baseChance + bonus

    if finalChance > 0 and ZombRand(100) < finalChance then
        -- 전설 상자로 진급!
        rewardFullType = "Base.Randombox_Legendary"
    end

    -------------------------------------------------
    -- 3) 최종 아이템 지급
    -------------------------------------------------
    inv:AddItem(rewardFullType)
end

-------------------------------------------------
-- LEGENDARY Randombox (상자 진급 없음, 그냥 최상위 보상)
-------------------------------------------------
function Recipe.OnCreate.OpenRandombox_Legendary(items, result, player)
    local pl = getValidPlayer(player)
    if not pl then return end

    local inv = pl:getInventory()
    if not inv then return end

    local roll = ZombRand(6)

    if roll < 1 then
        inv:AddItem("RPGSkillTree.Necklace_of_Memories_Legendary")

    elseif roll < 2 then
        inv:AddItem("RPGSkillTree.Necklace_of_Strength_Legendary")

    elseif roll < 3 then
        inv:AddItem("RPGSkillTree.Forest_Earrings_Legendary")

    elseif roll < 4 then
        inv:AddItem("RPGSkillTree.Dew_Beaded_Ring_Legendary")

    elseif roll < 5 then
        inv:AddItem("RPGSkillTree.Bag_HydrationBackpack_Legendary")

    else
        inv:AddItem("RPGSkillTree.Bag_ALICE_BeltSus_Legendary")
    end
end
