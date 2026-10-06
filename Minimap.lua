-- RocketMount | Minimap.lua
-- Botão de minimapa próprio, sem LibDBIcon: são ~60 linhas e evita embutir biblioteca.
-- Guarda a posição como ângulo, então continua no lugar em qualquer tamanho de minimapa.
-- É o mesmo desenho dos outros addons Rocket, de propósito: o jogador aprende um e conhece os três.
local ADDON, ns = ...
local L = ns.L

local RADIUS = 80
local button

local function UpdatePosition()
    if not button then return end
    local angle = math.rad(ns.db.minimap.angle or 200)
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local px, py = GetCursorPosition()
    px, py = px / scale, py / scale
    ns.db.minimap.angle = math.deg(math.atan2(py - my, px - mx)) % 360
    UpdatePosition()
end

function ns.CreateMinimapButton()
    if button then return button end
    if ns.db.minimap.hide then return nil end

    button = CreateFrame("Button", ADDON .. "MinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    -- (!) THE GAME'S RING AND THE ICON, AT THE NUMBERS EVERY OTHER BUTTON USES (06/10). Reported
    -- with a screenshot: our drawing sat off-centre inside the gold ring. The button had the ring
    -- at 53 and the icon at 19, shifted (-1, 1) -- numbers of the OLD clients. On retail the
    -- minimap-button library the other addons ship (LibDBIcon-1.0, `WOW_PROJECT_MAINLINE`
    -- branch) draws the ring at 50 from the top left, the game's dark disc at 24 and the icon at
    -- 18, both at the button's very centre. With the game's square icons nobody saw the 1.5
    -- points; with a ring of our own inside the gold one, it shows.
    local disc = button:CreateTexture(nil, "BACKGROUND")
    disc:SetSize(24, 24)
    disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    disc:SetPoint("CENTER", button, "CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", button, "CENTER")
    icon:SetTexture(ns.LOGO_MINIMAP)
    button.icon, button.disc = icon, disc
    icon:SetTexCoord(0, 1, 0, 1)
    -- Máscara redonda: é o que a UI moderna do jogo faz, e quadrado com borda preta
    -- dentro da moldura redonda do minimapa parece recorte colado.
    icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if ns.category then Settings.OpenToCategory(ns.category:GetID()) end
        else
            ns.ToggleWindow()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cffff6a00Rocket|r Mount", 1, 1, 1)
        -- A dica responde a pergunta que o ícone levanta: quantas faltam, e qual é a
        -- primeira da fila. Sem isso o ícone só ocupa espaço no minimapa.
        local ok, list = pcall(ns.GetRanked)
        if ok and list and #list > 0 then
            GameTooltip:AddLine(string.format(L["%d mounts missing"], #list), 0.86, 0.87, 0.90)
            local first = list[1]
            local c = ns.TIER_COLOR[first.tier] or { 1, 0.82, 0 }
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Next in line:"], 1, 0.82, 0)
            GameTooltip:AddLine(first.name, c[1], c[2], c[3])
            GameTooltip:AddLine(first.why or "", 0.55, 0.55, 0.58, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Click to open · right-click for options"], 0.55, 0.55, 0.58)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdatePosition()
    return button
end

function ns.SetMinimapHidden(hide)
    ns.db.minimap.hide = hide
    if hide then
        if button then button:Hide() end
    elseif button then
        button:Show()
    else
        ns.CreateMinimapButton()
    end
end
