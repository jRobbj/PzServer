-- RPG_XPBar.lua
require "ISUI/ISPanel"

ISXPBar = ISPanel:derive("ISXPBar")

-- 여러 플레이어(코옵) 대비용, 인덱스로 관리
ISXPBar.instances = ISXPBar.instances or {}

----------------------------------------------------
-- 🔹 레벨별 필요 경험치 : XP 시스템에서 가져오거나 전역 함수 사용
----------------------------------------------------
-- XP 시스템 파일에서 이미 정의했다면 이건 생략 가능
-- 여기서는 RPG_GetRequiredXP(level) 이 전역에 있다고 가정
-- 없으면 이 파일 위쪽에 테이블이랑 RPG_GetRequiredXP 정의해두면 됨.

----------------------------------------------------
-- 🔹 생성
----------------------------------------------------
function ISXPBar:new(x, y, width, height, playerIndex)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.playerIndex = playerIndex or 0

    o.background     = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.6 }  -- 반투명 검정
    o.border         = true
    o.borderColor    = { r = 1, g = 1, b = 1, a = 0.8 }   -- 흰색 테두리

    o.dragging = false

    return o
end

----------------------------------------------------
-- 🔹 위치 저장/로드 헬퍼
----------------------------------------------------
function ISXPBar:savePosition()
    local player = getSpecificPlayer(self.playerIndex)
    if not player then return end

    local md = player:getModData()
    md.RPG_XPBarX = self:getX()
    md.RPG_XPBarY = self:getY()

    -- 멀티 대비용(싱글이면 없어도 상관 없지만 있어도 문제 없음)
    if isClient and isClient() then
        player:transmitModData()
    end
end

function ISXPBar.loadSavedPosition(playerIndex, defaultX, defaultY, width, height)
    local player = getSpecificPlayer(playerIndex)
    if not player then
        return defaultX, defaultY
    end

    local md = player:getModData()
    local x = md.RPG_XPBarX or defaultX
    local y = md.RPG_XPBarY or defaultY

    -- 화면 밖으로 나가 있었을 수도 있으니까 한 번 클램프
    local core = getCore()
    local sw = core:getScreenWidth()
    local sh = core:getScreenHeight()

    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x + width > sw then x = sw - width end
    if y + height > sh then y = sh - height end

    return x, y
end

----------------------------------------------------
-- 🔹 드래그 관련
----------------------------------------------------
function ISXPBar:onMouseDown(x, y)
    ISPanel.onMouseDown(self, x, y)
    self.dragging = true
    self.dragStartX = x
    self.dragStartY = y
end

function ISXPBar:onMouseUp(x, y)
    ISPanel.onMouseUp(self, x, y)
    if self.dragging then
        self.dragging = false
        self:savePosition()  -- 🔹 드래그 끝날 때 위치 저장
    end
end

function ISXPBar:onMouseUpOutside(x, y)
    ISPanel.onMouseUpOutside(self, x, y)
    if self.dragging then
        self.dragging = false
        self:savePosition()  -- 🔹 밖에서 떼도 저장
    end
end

function ISXPBar:onMouseMove(dx, dy)
    ISPanel.onMouseMove(self, dx, dy)

    if self.dragging then
        self:setX(self.x + dx)
        self:setY(self.y + dy)

        -- 화면 밖 안 나가게 클램프
        local core = getCore()
        local sw = core:getScreenWidth()
        local sh = core:getScreenHeight()

        if self.x < 0 then self:setX(0) end
        if self.y < 0 then self:setY(0) end
        if self.x + self.width > sw then
            self:setX(sw - self.width)
        end
        if self.y + self.height > sh then
            self:setY(sh - self.height)
        end
    end
end

----------------------------------------------------
-- 🔹 렌더
----------------------------------------------------
function ISXPBar:render()
    ISPanel.render(self)

    local player = getSpecificPlayer(self.playerIndex)
    if not player then return end

    local md = player:getModData()
    local level = md.RPG_Level or 1
    local xp    = md.RPG_XP    or 0

    -- XP 시스템에서 제공하는 함수 사용
    local req = 0
    if RPG_GetRequiredXP then
        req = RPG_GetRequiredXP(level)
    end
    if req <= 0 then req = 1 end

    local ratio = xp / req
    if ratio < 0 then ratio = 0 end
    if ratio > 1 then ratio = 1 end

    -- 내부 여백
    local pad  = 2
    local barX = pad
    local barY = pad
    local barW = self.width  - pad * 2
    local barH = self.height - pad * 2

    -- 배경 바(어두운 회색)
    self:drawRect(barX, barY, barW, barH, 0.8, 0.2, 0.2, 0.2)

    -- 채워지는 바 (금색 느낌)
    local fillW = math.floor(barW * ratio + 0.5)
    self:drawRect(barX, barY, fillW, barH, 0.9, 1.0, 0.84, 0.0)

    -- 텍스트: "Lv. X  1234 / 5678"
    local text = string.format("Lv. %d   %d / %d", level, xp, req)
    local font = UIFont.Small
    local textW = getTextManager():MeasureStringX(font, text)
    local textH = getTextManager():MeasureStringY(font, text)

    local tx = self.width  / 2 - textW / 2
    local ty = self.height / 2 - textH / 2

    -- 글자는 흰색
    self:drawText(text, tx, ty, 1, 1, 1, 1, font)
end

----------------------------------------------------
-- 🔹 플레이어 생성 시 XP 바 만들기
----------------------------------------------------
local function RPG_CreateXPBar(playerIndex, player)
    local core = getCore()
    local sw = core:getScreenWidth()
    local sh = core:getScreenHeight()

    local w = 300
    local h = 20

    -- 기본 위치: 화면 아래 중앙
    local defaultX = (sw - w) / 2
    local defaultY = sh - h - 60

    -- 🔹 저장된 위치가 있으면 그걸 사용
    local x, y = ISXPBar.loadSavedPosition(playerIndex, defaultX, defaultY, w, h)

    local bar = ISXPBar:new(x, y, w, h, playerIndex)
    bar:initialise()
    bar:addToUIManager()
    bar:setVisible(true)

    ISXPBar.instances[playerIndex] = bar
end

Events.OnCreatePlayer.Add(RPG_CreateXPBar)
