-- RocketMounts | Window.lua
-- A janela: a lista ranqueada à esquerda, a ficha da montaria escolhida à direita.
local ADDON, ns = ...

local S = ns.Skin

local WINDOW_W, WINDOW_H = 790, 560
local LIST_W = 450
local DETAIL_W = WINDOW_W - LIST_W - S.padding * 3

local ROW_STEP = S.rowHeight + S.rowSpacing
local SECTION_STEP = S.sectionHeight + S.sectionGap

local window, list, detail
local rowPool, headPool = {}, {}
local selected

--------------------------------------------------------------------------------
-- Peças
--------------------------------------------------------------------------------

local function Backdrop(frame, alpha)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.035, 0.035, 0.05, alpha or S.panelAlpha)
    return bg
end

local function GlyphButton(parent, texture, atlas, size, tooltip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    -- Glifo chapado, não botão com moldura: misturar as duas famílias numa barra de
    -- ícones produz o efeito "botão de Windows XP no meio de ícone plano".
    if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas)
    else
        tex:SetTexture(texture)
    end
    tex:SetDesaturated(true)
    tex:SetVertexColor(0.78, 0.73, 0.58)
    b:SetScript("OnEnter", function(self)
        tex:SetVertexColor(1, 0.95, 0.80)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function()
        tex:SetVertexColor(0.78, 0.73, 0.58)
        GameTooltip:Hide()
    end)
    b.texture = tex
    return b
end

--------------------------------------------------------------------------------
-- Ficha da montaria (painel da direita)
--------------------------------------------------------------------------------

local function BuildDetail(parent)
    local d = CreateFrame("Frame", nil, parent)
    d:SetSize(DETAIL_W, WINDOW_H - S.headerHeight - 60)

    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(48, 48)
    d.icon:SetPoint("TOPLEFT", 0, 0)

    d.name = ns.NewText(d, S.titleFontSize, S.gold)
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 8, -2)
    d.name:SetWidth(DETAIL_W - 60)
    d.name:SetJustifyV("TOP")

    d.tier = ns.NewText(d, S.subFontSize, S.dim)
    d.tier:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 8, -24)
    d.tier:SetWidth(DETAIL_W - 60)

    d.rule = d:CreateTexture(nil, "ARTWORK")
    d.rule:SetColorTexture(1, 1, 1, 0.10)
    d.rule:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -10)
    d.rule:SetSize(DETAIL_W, 1)

    -- Corpo da ficha: uma pilha de blocos "rótulo em cima, texto embaixo". Aqui o
    -- empilhamento é o certo — é texto livre de largura cheia, não campo de formulário.
    d.blocks = {}
    for i = 1, 6 do
        local b = {}
        b.label = ns.NewText(d, S.subFontSize, S.gold)
        b.value = ns.NewText(d, S.rowFontSize, S.text)
        b.value:SetWidth(DETAIL_W)
        b.value:SetJustifyV("TOP")
        b.value:SetSpacing(2)
        d.blocks[i] = b
    end

    d.waypoint = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    d.waypoint:SetSize(160, 22)
    d.waypoint:SetText("Marcar no mapa")
    d.waypoint:Hide()

    d.empty = ns.NewText(d, S.rowFontSize, S.dim)
    d.empty:SetPoint("TOPLEFT", 0, -6)
    d.empty:SetWidth(DETAIL_W)
    d.empty:SetText("Escolha uma montaria na lista para ver como ela se pega.")

    return d
end

local function ZoneLine(entry)
    if not entry.coords or not entry.coords[1] then return nil, nil end
    local wp = entry.coords[1]
    local zone
    if wp.m and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(wp.m)
        zone = info and info.name
    end
    if not zone then return nil, wp end
    if wp.x and wp.y then
        return string.format("%s  %.1f, %.1f%s", zone, wp.x, wp.y, wp.n and (" — " .. wp.n) or ""), wp
    end
    return zone, wp
end

local function FillDetail(entry)
    local d = detail
    for i = 1, #d.blocks do
        d.blocks[i].label:Hide()
        d.blocks[i].value:Hide()
    end
    d.waypoint:Hide()

    if not entry then
        d.icon:Hide(); d.name:Hide(); d.tier:Hide(); d.rule:Hide()
        d.empty:Show()
        return
    end
    d.empty:Hide()
    d.icon:Show(); d.name:Show(); d.tier:Show(); d.rule:Show()

    d.icon:SetTexture(entry.icon)
    d.name:SetText(entry.name)

    local c = ns.TIER_COLOR[entry.tier] or S.dim
    d.tier:SetText(ns.TIER_NAME[entry.tier])
    d.tier:SetTextColor(c[1], c[2], c[3])

    local n = 0
    local function Block(label, value)
        if not value or value == "" then return end
        n = n + 1
        local b = d.blocks[n]
        if not b then return end
        b.label:SetText(label)
        b.value:SetText(value)
        b.label:Show(); b.value:Show()
    end

    -- O texto da própria Blizzard. É o melhor "como pega" que existe, e já vem traduzido.
    Block("Como pega", entry.sourceText and entry.sourceText ~= "" and entry.sourceText
        or ns.SOURCE_NAMES[entry.sourceType])

    if entry.chance and entry.chance > 0 then
        local pct = 100 / entry.chance
        local fmt = (pct >= 1 and "1 em %d  (%.0f%%)") or (pct >= 0.1 and "1 em %d  (%.1f%%)") or "1 em %d  (%.2f%%)"
        local txt = string.format(fmt, entry.chance, pct)
        if entry.bossName then txt = txt .. "\n" .. entry.bossName end
        Block("Taxa de queda", txt)
    end

    local p = entry.progressFrom and entry[entry.progressFrom]
    if p and p.label then
        Block("O que você já andou", p.label)
    end

    if entry.cost and entry.progressFrom ~= "cost" then
        Block("Custo", entry.cost.label)
    end

    local zone, wp = ZoneLine(entry)
    if zone then Block("Onde", zone) end

    if entry.ownedByPct then
        Block("Quantos jogadores têm", string.format("%.1f%% da base", entry.ownedByPct))
    end

    if entry.blackMarket then
        Block("Também aparece", "Mercado Negro")
    end

    -- Posiciona a pilha. Empilhado: 2 por dentro (rótulo → seu texto), 10 por fora.
    -- Razão de 5x, que é a que a Blizzard pratica no formulário empilhado dela.
    local anchor, y = d.rule, -10
    for i = 1, n do
        local b = d.blocks[i]
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", anchor, i == 1 and "BOTTOMLEFT" or "BOTTOMLEFT", 0, y)
        b.value:ClearAllPoints()
        b.value:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2)
        anchor, y = b.value, -10
    end

    if wp and wp.m and wp.x and wp.y and C_Map and C_Map.CanSetUserWaypointOnMap
        and C_Map.CanSetUserWaypointOnMap(wp.m) then
        d.waypoint:ClearAllPoints()
        d.waypoint:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
        d.waypoint:SetScript("OnClick", function()
            local point = UiMapPoint.CreateFromCoordinates(wp.m, wp.x / 100, wp.y / 100)
            C_Map.SetUserWaypoint(point)
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
            ns.Print("seta apontada para " .. (entry.name or "a montaria") .. ".")
        end)
        d.waypoint:Show()
    end
end

--------------------------------------------------------------------------------
-- Linhas da lista
--------------------------------------------------------------------------------

local function AcquireRow(parent, i)
    local r = rowPool[i]
    if r then return r end

    r = CreateFrame("Button", nil, parent)
    r:SetSize(LIST_W - 20, S.rowHeight)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()

    r.icon = r:CreateTexture(nil, "ARTWORK")
    -- Quadrado e da altura da linha, como a referência do medidor faz. Máscara
    -- redonda menor que a linha parece recorte colado.
    r.icon:SetSize(S.rowHeight - 4, S.rowHeight - 4)
    r.icon:SetPoint("LEFT", 2, 0)

    r.name = ns.NewText(r, S.rowFontSize, S.text)
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
    r.name:SetWidth(LIST_W - 160)
    r.name:SetWordWrap(false)

    r.why = ns.NewText(r, S.subFontSize, S.dim)
    r.why:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
    r.why:SetWidth(LIST_W - 160)
    r.why:SetWordWrap(false)

    r.headline = ns.NewText(r, S.rowFontSize, S.cream, "RIGHT")
    r.headline:SetPoint("RIGHT", -6, 0)
    r.headline:SetWidth(96)

    r:SetScript("OnEnter", function(self)
        if self.entry ~= selected then
            self.bg:SetColorTexture(unpack(S.rowBackgroundHl))
        end
        if self.entry and self.entry.description and self.entry.description ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.entry.name, 1, 0.82, 0)
            GameTooltip:AddLine(self.entry.description, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function(self)
        self:UpdateBackground()
        GameTooltip:Hide()
    end)
    r:SetScript("OnClick", function(self)
        selected = self.entry
        FillDetail(selected)
        for _, other in ipairs(rowPool) do
            if other.UpdateBackground then other:UpdateBackground() end
        end
    end)

    function r:UpdateBackground()
        if self.entry and self.entry == selected then
            self.bg:SetColorTexture(unpack(S.rowBackgroundSel))
        else
            self.bg:SetColorTexture(unpack(S.rowBackground))
        end
    end

    rowPool[i] = r
    return r
end

local function AcquireHead(parent, i)
    local h = headPool[i]
    if h then return h end

    h = CreateFrame("Frame", nil, parent)
    h:SetSize(LIST_W - 20, S.sectionHeight)

    h.title = ns.NewText(h, S.headFontSize, S.gold)
    h.title:SetPoint("BOTTOMLEFT", 0, 2)

    h.hint = ns.NewText(h, S.subFontSize, S.dim)
    h.hint:SetPoint("LEFT", h.title, "RIGHT", 8, 0)

    h.rule = h:CreateTexture(nil, "ARTWORK")
    h.rule:SetColorTexture(1, 1, 1, 0.08)
    h.rule:SetPoint("BOTTOMLEFT", 0, 0)
    h.rule:SetSize(LIST_W - 20, 1)

    headPool[i] = h
    return h
end

--------------------------------------------------------------------------------
-- Desenho da lista
--------------------------------------------------------------------------------

local function Redraw()
    local entries, total = ns.GetFiltered()
    local limit = math.min(#entries, ns.db.topN or 100)

    for _, r in ipairs(rowPool) do r:Hide(); r.entry = nil end
    for _, h in ipairs(headPool) do h:Hide() end

    local content = list.content
    local y = 0
    local ri, hi, lastTier = 0, 0, nil

    for i = 1, limit do
        local e = entries[i]

        if e.tier ~= lastTier then
            hi = hi + 1
            local h = AcquireHead(content, hi)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -y)
            h.title:SetText(ns.TIER_NAME[e.tier])
            local c = ns.TIER_COLOR[e.tier] or S.gold
            h.title:SetTextColor(c[1], c[2], c[3])
            h.hint:SetText(ns.TIER_HINT[e.tier])
            h:Show()
            y = y + SECTION_STEP
            lastTier = e.tier
        end

        ri = ri + 1
        local r = AcquireRow(content, ri)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -y)
        r.entry = e
        r.icon:SetTexture(e.icon)
        r.name:SetText(e.name)
        r.why:SetText(e.why or "")
        r.headline:SetText(e.headline or "")
        local c = ns.TIER_COLOR[e.tier] or S.cream
        r.headline:SetTextColor(c[1], c[2], c[3])
        r:UpdateBackground()
        r:Show()
        y = y + ROW_STEP
    end

    content:SetHeight(math.max(y, 1))

    local mcl, rar = ns.ProviderStatus()
    local footer
    if limit < #entries then
        footer = string.format("Mostrando as %d primeiras de %d que faltam", limit, #entries)
    else
        footer = string.format("%d montarias faltando", #entries)
    end
    if #entries ~= total then
        footer = footer .. string.format(" (filtrado de %d)", total)
    end
    if not mcl then
        footer = footer .. "  |cffcc6666· sem o MCL, não há taxa de queda|r"
    elseif not rar then
        footer = footer .. "  |cff888888· sem o MountJournalEnhanced, não há o percentual da base|r"
    end
    window.footer:SetText(footer)
end

function ns.RefreshWindow()
    if window and window:IsShown() then
        Redraw()
        if selected then FillDetail(selected) end
    end
end

--------------------------------------------------------------------------------
-- Filtro de fonte
--------------------------------------------------------------------------------

local function SourceMenu(owner)
    if not _G.MenuUtil then
        ns.Print("este cliente não tem o menu novo; use /rmt fontes.")
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Fontes")
        root:CreateButton("Todas", function()
            ns.db.sources = nil
            ns.RefreshWindow()
        end)
        for id = 0, 11 do
            root:CreateCheckbox(ns.SOURCE_NAMES[id],
                function() return not ns.db.sources or ns.db.sources[id] end,
                function()
                    local t = ns.db.sources
                    if not t then
                        -- Primeira desmarcação: parte de "todas ligadas".
                        t = {}
                        for i = 0, 11 do t[i] = true end
                        ns.db.sources = t
                    end
                    t[id] = not t[id]
                    local any = false
                    for i = 0, 11 do if t[i] then any = true end end
                    if not any then ns.db.sources = nil end
                    ns.RefreshWindow()
                end)
        end
    end)
end

--------------------------------------------------------------------------------
-- A janela
--------------------------------------------------------------------------------

local function Build()
    window = CreateFrame("Frame", ADDON .. "Window", UIParent)
    window:SetSize(WINDOW_W, WINDOW_H)
    window:SetFrameStrata("HIGH")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    Backdrop(window)

    local pos = ns.db.window
    if pos then
        window:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
    else
        window:SetPoint("CENTER")
    end

    -- Cabeçalho: faixa escura em degradê com texto dourado. É o padrão que o
    -- rastreador de missões, o medidor nativo e o Details usam.
    local header = CreateFrame("Frame", nil, window)
    header:SetHeight(S.headerHeight)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header.art = header:CreateTexture(nil, "ARTWORK")
    header.art:SetAllPoints()
    ns.ApplyHeaderArt(header.art)

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        local point, _, _, x, y = window:GetPoint()
        ns.db.window = { point = point, x = x, y = y }
    end)

    local title = ns.NewText(header, S.titleFontSize, S.gold)
    title:SetPoint("LEFT", 10, 0)
    title:SetText("Rocket Mounts — por onde começar")

    local close = GlyphButton(header, "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        "common-icon-redx", 16, "Fechar")
    close:SetPoint("RIGHT", -8, 0)
    close:SetScript("OnClick", function() window:Hide() end)

    -- Barra de filtro.
    local bar = CreateFrame("Frame", nil, window)
    bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", S.leftMargin, -S.padding)
    bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -S.leftMargin, -S.padding)
    bar:SetHeight(25)

    local sourceBtn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    -- Combo de retail: 120x25 (Blizzard_Menu/Mainline/MenuTemplates.xml:4).
    sourceBtn:SetSize(120, 25)
    sourceBtn:SetPoint("LEFT")
    sourceBtn:SetText("Fontes")
    sourceBtn:SetScript("OnClick", function(self) SourceMenu(self) end)

    window.footer = ns.NewText(bar, S.subFontSize, S.dim, "RIGHT")
    window.footer:SetPoint("RIGHT")
    window.footer:SetWidth(WINDOW_W - 180)

    -- Lista, com rolagem.
    list = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -S.padding)
    list:SetSize(LIST_W, WINDOW_H - S.headerHeight - 25 - S.padding * 3 - 6)
    list.content = CreateFrame("Frame", nil, list)
    list.content:SetSize(LIST_W - 20, 1)
    list:SetScrollChild(list.content)

    -- Separador entre a lista e a ficha.
    local sep = window:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.08)
    sep:SetPoint("TOPLEFT", list, "TOPRIGHT", S.padding, 0)
    sep:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", S.padding, 0)
    sep:SetWidth(1)

    detail = BuildDetail(window)
    detail:SetPoint("TOPLEFT", sep, "TOPRIGHT", S.padding, 0)

    tinsert(UISpecialFrames, window:GetName())   -- Esc fecha
    window:Hide()
    ns.window = window
end

function ns.ToggleWindow()
    if not window then Build() end
    if window:IsShown() then
        window:Hide()
        return
    end
    window:Show()
    Redraw()
    FillDetail(selected)
end

