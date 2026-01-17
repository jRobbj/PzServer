-------------------------------------------------
-- RPGSkillTreeItemEffects.lua
-- 장비(목걸이, 귀걸이, 반지)에서 오는 보너스를 관리
-- ✔ 안전하게 7프레임마다 한 번 재계산
-- ✔ B42.13: ItemBodyLocation + ResourceLocation 기반 슬롯 접근
-------------------------------------------------

-- 전역 기본값 (혹시 없으면 초기화)
RPG_ITEM_XP_FACTOR   = RPG_ITEM_XP_FACTOR   or 1.0   -- 장비 XP 배수
RPG_ITEM_WEIGHT_MUL  = RPG_ITEM_WEIGHT_MUL or 1.0   -- 장비 무게 배수

-------------------------------------------------
-- 🔧 공통 헬퍼: 착용 아이템 가져오기 (42.13 전용)
--   bodyLocationId 예시:
--     "Necklace", "Necklace_Long", "Ears", "Nose"
--   → ItemBodyLocation.get(ResourceLocation.of(bodyLocationId)) 사용
-------------------------------------------------
local function RPG_GetWornItem(player, bodyLocationId)
    if not player or not bodyLocationId then return nil end

    -- 필수 클래스 체크 (42.13이면 다 있음)
    if not ItemBodyLocation or not ItemBodyLocation.get then return nil end
    if not ResourceLocation or not ResourceLocation.of then return nil end

    -- String → ResourceLocation → ItemBodyLocation
    local rl = ResourceLocation.of(bodyLocationId)
    if not rl then return nil end

    local loc = ItemBodyLocation.get(rl)
    if not loc then return nil end

    -- 1) 표준 경로: player:getWornItem(ItemBodyLocation)
    if player.getWornItem then
        local item = player:getWornItem(loc)
        if item then return item end
    end

    -- 2) 예비: player:getWornItems():getItem(ItemBodyLocation)
    if player.getWornItems then
        local worn = player:getWornItems()
        if worn and worn.getItem then
            local item = worn:getItem(loc)
            if item then return item end
        end
    end

    return nil
end

-------------------------------------------------
-- 🔹 1. XP 목걸이 보너스
-------------------------------------------------
local function RPG_UpdateItemXPBonus(player)
    if not player or (player.isDead and player:isDead()) then return end

    local mul = 1.0

    -- items.txt 의 BodyLocation 값 기준:
    --   Necklace / Necklace_Long
    local neck =
        RPG_GetWornItem(player, "Necklace") or
        RPG_GetWornItem(player, "Necklace_Long")

    if neck and neck.getFullType then
        local fullType = neck:getFullType()

        if fullType == "RPGSkillTree.Necklace_of_Memories_Normal" then
            mul = mul + 0.05
        elseif fullType == "RPGSkillTree.Necklace_of_Memories_Rare" then
            mul = mul + 0.15
        elseif fullType == "RPGSkillTree.Necklace_of_Memories_Legendary" then
            mul = mul + 0.50
        end
    end

    RPG_ITEM_XP_FACTOR = mul
end

-------------------------------------------------
-- 🔹 2. Strength Necklace (Carry Weight %) 보너스
-------------------------------------------------
local function RPG_UpdateItemCarryBonus(player)
    if not player or (player.isDead and player:isDead()) then return end

    local mul = 1.0  -- 기본 100%

    local neck =
        RPG_GetWornItem(player, "Necklace_Long") or
        RPG_GetWornItem(player, "Necklace")

    if neck and neck.getType then
        local itemType = neck:getType()

        if itemType == "Necklace_of_Strength_Normal" then
            mul = mul * 1.05   -- +5%
        elseif itemType == "Necklace_of_Strength_Rare" then
            mul = mul * 1.15   -- +15%
        elseif itemType == "Necklace_of_Strength_Legendary" then
            mul = mul * 1.30   -- +30%
        end
    end

    RPG_ITEM_WEIGHT_MUL = mul
end

-------------------------------------------------
-- 🔹 3. Forest Earrings (Hunger 감소)
-------------------------------------------------
local function RPG_UpdateItemHungerBonus(player)
    if not player or (player.isDead and player:isDead()) then return end

    local bonus = 1.0  -- 기본 = 100%

    -- BodyLocation=Ears
    local ear = RPG_GetWornItem(player, "Ears")
    if ear and ear.getType then
        local itemType = ear:getType()

        if itemType == "Forest_Earrings_Rare" then
            bonus = 0.80      -- 배고픔 -20%
        elseif itemType == "Forest_Earrings_Legendary" then
            bonus = 0.50      -- 배고픔 -50%
        end
    end

    local md = player:getModData()
    md.RPG_ITEM_HUNGER_FACTOR = bonus
end

-------------------------------------------------
-- 🔹 4. Dew Beaded Ring (Thirst 감소)
-------------------------------------------------
local function RPG_UpdateItemThirstBonus(player)
    if not player or (player.isDead and player:isDead()) then return end

    local factor = 1.0  -- 기본

    -- BodyLocation=Nose
    local nose = RPG_GetWornItem(player, "Nose")
    if nose and nose.getType then
        local itemType = nose:getType()

        if itemType == "Dew_Beaded_Ring_Rare" then
            factor = 0.8      -- 목마름 -20%
        elseif itemType == "Dew_Beaded_Ring_Legendary" then
            factor = 0.5      -- 목마름 -50%
        end
    end

    local md = player:getModData()
    md.RPG_ITEM_THIRST_FACTOR = factor
end

-------------------------------------------------
-- 🔹 5. 장비 관련 보너스 전체 재계산
-------------------------------------------------
local function RPG_RecalcAllItemBonuses(player)
    if not player or (player.isDead and player:isDead()) then return end

    RPG_UpdateItemXPBonus(player)
    RPG_UpdateItemCarryBonus(player)
    RPG_UpdateItemHungerBonus(player)
    RPG_UpdateItemThirstBonus(player)

    -- 아이템 계수까지 포함해서 전체 스킬 효과 다시 적용
    if RPG_UpdateAllSkillEffects then
        RPG_UpdateAllSkillEffects(player)
    end
end

-------------------------------------------------
-- 🔹 6. 7프레임마다 한 번씩 자동 재계산
--    - 싱글 기준 player0만 처리
-------------------------------------------------
local function RPG_OnPlayerUpdate_ItemEffects(player)
    if not player or (player.isDead and player:isDead()) then return end

    -- 싱글 기준: 0번 플레이어만
    local p0 = getSpecificPlayer and getSpecificPlayer(0) or nil
    if not p0 or player ~= p0 then return end

    local md = player:getModData()
    md.RPG_ItemEffectTick = (md.RPG_ItemEffectTick or 0) + 1

    -- 7프레임마다 한 번씩만 계산
    if md.RPG_ItemEffectTick >= 7 then
        md.RPG_ItemEffectTick = 0
        RPG_RecalcAllItemBonuses(player)
    end
end

Events.OnPlayerUpdate.Add(RPG_OnPlayerUpdate_ItemEffects)

-------------------------------------------------
-- 🔹 7. 플레이어 생성 시 한 번 초기 계산
-------------------------------------------------
local function RPG_OnCreatePlayer(playerIndex, player)
    if not player or (player.isDead and player:isDead()) then return end

    local md = player:getModData()
    md.RPG_ItemEffectTick = 0

    RPG_RecalcAllItemBonuses(player)
end

Events.OnCreatePlayer.Add(RPG_OnCreatePlayer)
