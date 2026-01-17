--=========================================================
-- 🧬 InnerStrength: 완전 감염 면역 (42.13 / 멀티 대응)
--   - InnerStrength 노드를 찍은 플레이어만 적용
--   - 로컬 플레이어만 처리 (멀티/분할 화면 대비)
--=========================================================

local function RPG_InfectionImmunity(player)
    -- 0) 기본 방어
    if not player then return end
    if player.isDead and player:isDead() then return end
    if player.isZombie and player:isZombie() then return end

    -------------------------------------------------
    -- 1) 멀티 / 분할 화면 대비:
    --    실제 로컬로 조작 중인 플레이어만 처리
    -------------------------------------------------
    if player.isLocalPlayer and not player:isLocalPlayer() then
        -- 원격 플레이어나 거울 객체 등은 스킵
        return
    end

    -------------------------------------------------
    -- 2) 스킬 노드 체크 (InnerStrength 없으면 종료)
    -------------------------------------------------
    local md = player.getModData and player:getModData() or nil
    if not md then return end

    md.RPGSkillNodes = md.RPGSkillNodes or {}
    if not md.RPGSkillNodes["InnerStrength"] then
        return
    end

    -------------------------------------------------
    -- 3) BodyDamage 기반 감염 초기화
    -------------------------------------------------
    local body = player.getBodyDamage and player:getBodyDamage() or nil
    if body then
        if body.setInfected then
            body:setInfected(false)
        end

        local parts = body.getBodyParts and body:getBodyParts() or nil
        if parts then
            for i = 0, parts:size() - 1 do
                local p = parts:get(i)
                if p and p.SetInfected then
                    p:SetInfected(false)
                end
            end
        end
    end

    -------------------------------------------------
    -- 4) CharacterStat 기반 감염도 항상 0으로
    -------------------------------------------------
    local stats = player.getStats and player:getStats() or nil
    if stats and stats.set and CharacterStat and CharacterStat.zombie_infection then
        stats:set(CharacterStat.zombie_infection, 0)
    end
end

Events.OnPlayerUpdate.Add(RPG_InfectionImmunity)
