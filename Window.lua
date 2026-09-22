-- RocketMounts | Window.lua
-- A janela: a lista ranqueada à esquerda, a ficha da montaria escolhida à direita.
local ADDON, ns = ...
local L = ns.L

local S = ns.Skin

-- (!) A LARGURA É UMA CONTA, E ELA ESTAVA ERRADA (relatado em 22/09, testando no jogo):
-- *"as informações da direita estão bem grudadas e tem texto vazando pra fora da janela"*.
--
-- A fórmula antiga era `WINDOW_W - LIST_W - padding * 3`, e ela esquecia três coisas: as duas
-- margens da janela, o 1px do separador e -- a maior delas -- a **barra de rolagem**. O
-- `UIPanelScrollFrameTemplate` põe a barra FORA do quadro, encostada à direita dele, e ninguém
-- tinha reservado espaço para ela: ela caía em cima do separador. Somando tudo, a ficha começava
-- 15px à direita de onde cabia, e o texto dela terminava do lado de fora da borda.
--
-- Agora cada pedaço tem nome e a soma é conferida no harness. As margens são as duas iguais
-- (`leftMargin`), como na barra de filtro, que já se ancorava assim.
local SCROLLBAR_W = 25      -- a barra do `UIPanelScrollFrameTemplate`, que vive fora do quadro
local SEP_W = 1             -- o fio entre a lista e a ficha

local WINDOW_W, WINDOW_H = 880, 560
local LIST_W = 450
-- Medida de leitura: a ficha é prosa (o "Como pega" da Blizzard, o aviso de conferir), e texto
-- corrido pede 45 a 75 caracteres por linha. A 12pt da fonte do jogo, 360px dão ~60.
local DETAIL_W = 360

-- O que a janela precisa ter de largura para tudo isso caber, com margem dos dois lados. Se esta
-- conta não bater com `WINDOW_W`, algo vaza -- e é exatamente isso que o teste trava.
local NEEDED_W = S.leftMargin + LIST_W + SCROLLBAR_W + S.padding + SEP_W + S.padding
    + DETAIL_W + S.leftMargin

-- (!) A LINHA DA LISTA TINHA O MESMO VICIO, num numero solto: o nome usava `LIST_W - 160`, e
-- 160 nao vinha de lugar nenhum. Medido, o nome terminava 4px DEPOIS de onde o numero da
-- direita comecava -- encostados, e o nome (que nao quebra linha) cortado bem ali.
local ROW_W = LIST_W - 20              -- o quadro rolavel desconta a barra
local ROW_ICON = S.rowHeight - 4
local ROW_TEXT_X = 2 + ROW_ICON + 8    -- inset do icone + icone + respiro
local HEADLINE_W = 96
local HEADLINE_INSET = 6
local ROW_GAP = 10                     -- o respiro entre o nome e o numero, que faltava
local ROW_TEXT_W = ROW_W - ROW_TEXT_X - ROW_GAP - HEADLINE_W - HEADLINE_INSET

ns.Geometry = {
    windowW = WINDOW_W, neededW = NEEDED_W,
    listW = LIST_W, detailW = DETAIL_W,
    margin = S.leftMargin, padding = S.padding,
    scrollbarW = SCROLLBAR_W, sepW = SEP_W,
    rowW = ROW_W, rowTextX = ROW_TEXT_X, rowTextW = ROW_TEXT_W,
    headlineW = HEADLINE_W, headlineInset = HEADLINE_INSET, rowGap = ROW_GAP,
}

local ROW_STEP = S.rowHeight + S.rowSpacing
-- O nome da faixa mais longo ("Garantidas — requisito em andamento") a 12pt pede ~220px.
local TIER_TITLE_WIDTH = 230
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
    d.waypoint:SetText(L["Set map pin"])
    d.waypoint:Hide()

    d.empty = ns.NewText(d, S.rowFontSize, S.dim)
    d.empty:SetPoint("TOPLEFT", 0, -6)
    d.empty:SetWidth(DETAIL_W)
    d.empty:SetText(L["Pick a mount in the list to see how it is obtained."])

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

-- (!) O CONTEÚDO DA FICHA SE MONTA FORA DO DESENHO.
--
-- A regra morava dentro do código que pinta widget, e por isso o harness não tinha como
-- olhar para ela. Foi assim que a mesma informação chegou a aparecer três vezes na ficha
-- sem nenhum teste reclamar. Separada, esta é uma função pura: entra a montaria, sai a
-- lista de blocos, e o teste lê a lista.
---@return table blocos `{ { label, value }, ... }`, na ordem da ficha
---@return table|nil wp o ponto do mapa, para o botão de seta
function ns.DetailBlocks(entry)
    local blocks = {}
    local function Block(label, value)
        if not value or value == "" then return end
        blocks[#blocks + 1] = { label = label, value = value }
    end

    -- O texto da própria Blizzard. É o melhor "como pega" que existe, e já vem traduzido.
    Block(L["How to get it"], entry.sourceText and entry.sourceText ~= "" and entry.sourceText
        or ns.SOURCE_NAMES[entry.sourceType])

    if entry.chance and entry.chance > 0 then
        local pct = 100 / entry.chance
        local fmt = (pct >= 1 and "1 em %d  (%.0f%%)") or (pct >= 0.1 and "1 em %d  (%.1f%%)") or "1 em %d  (%.2f%%)"
        local txt = string.format(fmt, entry.chance, pct)
        if entry.bossName then txt = txt .. "\n" .. entry.bossName end
        Block(L["Chance"], txt)
    end

    -- Requisito e aquisição são blocos separados de propósito: misturar os dois é o que
    -- fazia a lista anunciar "100%" numa montaria que ainda depende de sorte.
    -- A EXPANSÃO, no alto da ficha: é a primeira coisa que situa a montaria, e sem ela o
    -- jogador lê "Vendedor em Valdrakken" sem saber de que época aquilo é.
    if entry.expansionName then
        Block(L["Expansion"], entry.expansionName)
    end

    if entry.factionOnly then
        -- FACÇÃO É INFORMAÇÃO, e antes ela só servia para esconder a montaria. Quem planeja o
        -- outro lado precisa saber que ela existe e de quem ela é.
        Block(L["Faction"], entry.factionOnly == "Horde" and L["Horde only"] or L["Alliance only"])
    end

    -- (!) A FICHA LISTA TODOS OS REQUISITOS, um por linha, com o estado de cada um.
    --
    -- Ela ja mostrou so o mais atrasado, e o usuario bateu de frente com o resultado disso:
    -- *"falta cristal de ressonancia mas que tambem falta reputacao"*. Uma montaria com dois
    -- requisitos que anuncia so um deles manda o jogador para a metade do caminho.
    local p = entry.requirementFrom and entry[entry.requirementFrom]
    if entry.requisitos and #entry.requisitos > 0 then
        local linhas = {}
        for _, r in ipairs(entry.requisitos) do
            linhas[#linhas + 1] = (r.cumprido and "|cff55dd66+|r  " or "|cffff5a52x|r  ")
                .. (r.label or "?")
        end
        Block(entry.faltando > 0
            and string.format(L["Requirements — %d of %d missing"], entry.faltando, #entry.requisitos)
            or L["Requirements — all met"],
            table.concat(linhas, string.char(10)))
    end

    -- QUAL PERSONAGEM TEM. A API só fala do conectado; esta lista vem do livro-caixa, que é
    -- escrito quando cada personagem entra. Por isso ela diz "pelo que ficou anotado" — uma
    -- anotação velha se passando por leitura ao vivo seria pior que anotação nenhuma.
    if p and p.unreadable and entry.rep and entry.rep.factionId ~= nil and ns.Roster then
        local quem = ns.Roster.WhoHas(entry.rep.factionId)
        if #quem > 0 then
            local linhas = {}
            for i = 1, math.min(#quem, 5) do
                local c = quem[i]
                linhas[#linhas + 1] = string.format("%s — %s", c.name,
                    _G["FACTION_STANDING_LABEL" .. c.reaction] or "?")
            end
            Block(L["Who has it, from what was recorded"],
                table.concat(linhas, string.char(10)))
        end
    end

    -- (!) O PREÇO NÃO TEM BLOCO PRÓPRIO, e isso é correção, não esquecimento.
    --
    -- Ele tinha: "Requisitos" listava o preço, e logo abaixo vinham "Preço" e "Falta" dizendo a
    -- mesma coisa outra vez. O usuário viu isso rodando: *"tem o Requisitos, tem o preço e o
    -- Falta, às vezes tem as mesmas informações"*. Três linhas para um fato só.
    --
    -- Preço É um requisito, e o lugar dele é a lista com os outros — com o mesmo sinal de
    -- cumprido, e contado no "faltam N de M". A exigência antiga continua valendo dentro da
    -- linha: o que ela custa primeiro, o que falta depois, nunca os dois números grudados
    -- (`CostProgress` monta esse texto, e é lá que ele vive).

    if entry.gated and not entry.deterministic then
        Block(L["Heads up"],
            L["The requirement above only UNLOCKS the attempt. Once met, the mount still depends on luck."])
    end

    -- ⛑ O AVISO QUE FALTAVA. O addon só enxerga reputação, renome, conquista, moeda e ouro.
    -- Conquista de guilda, nível de guilda, classificação de PvP e perícia de profissão ele NÃO
    -- lê — e foi por calar sobre isso que a Fênix Negra apareceu como "é só ir pegar".
    if entry.tier == ns.TIER.CHECK then
        local texto
        if entry.vendorGuilda then
            -- ESPECÍFICO quando dá para ser: toda montaria de vendedor de guilda exige
            -- reputação com a guilda mais uma conquista de guilda.
            texto = L["Guild vendor. These ask for reputation with your guild AND an achievement OF THE GUILD — and the achievement is the part I cannot read, because no installed catalogue says which achievement belongs to which mount. The price shown in the requirements is only part of what it costs."]
        else
            texto = L["Of what I can read, only the price shows up on this mount — and price is almost never what blocks. There may be an achievement, a guild level or a rating in the way, and those I do not read."]
            if entry.vendorVago then
                texto = texto .. L[" Not even the catalogue knows which vendor this one has."]
            end
        end
        Block(L["Why check"], texto)
    end

    local zone, wp = ZoneLine(entry)
    if zone then Block(L["Where"], zone) end

    if entry.ownedByPct then
        Block(L["How many players own it"], string.format(L["%.1f%% of the playerbase"], entry.ownedByPct))
    end

    if entry.blackMarket then
        Block(L["Also shows up at"], L["Black Market"])
    end

    return blocks, wp
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

    local blocks, wp = ns.DetailBlocks(entry)
    local n = math.min(#blocks, #d.blocks)
    for i = 1, n do
        local b = d.blocks[i]
        b.label:SetText(blocks[i].label)
        b.value:SetText(blocks[i].value)
        b.label:Show(); b.value:Show()
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
            ns.Print(string.format(L["arrow pointed at %s."], entry.name or L["the mount"]))
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
    r:SetSize(ROW_W, S.rowHeight)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()

    r.icon = r:CreateTexture(nil, "ARTWORK")
    -- Quadrado e da altura da linha, como a referência do medidor faz. Máscara
    -- redonda menor que a linha parece recorte colado.
    r.icon:SetSize(ROW_ICON, ROW_ICON)
    r.icon:SetPoint("LEFT", 2, 0)

    r.name = ns.NewText(r, S.rowFontSize, S.text)
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
    r.name:SetWidth(ROW_TEXT_W)
    r.name:SetWordWrap(false)

    r.why = ns.NewText(r, S.subFontSize, S.dim)
    r.why:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
    r.why:SetWidth(ROW_TEXT_W)
    r.why:SetWordWrap(false)

    r.headline = ns.NewText(r, S.rowFontSize, S.cream, "RIGHT")
    r.headline:SetPoint("RIGHT", -HEADLINE_INSET, 0)
    r.headline:SetWidth(HEADLINE_W)

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
    h:SetSize(ROW_W, S.sectionHeight)

    -- Largura explícita nos dois: sem ela a FontString cresce até onde o texto pedir e
    -- atravessa a borda da lista — e estes rótulos mudam de tamanho a cada faixa.
    h.title = ns.NewText(h, S.headFontSize, S.gold)
    h.title:SetPoint("BOTTOMLEFT", 0, 2)
    h.title:SetWidth(TIER_TITLE_WIDTH)
    h.title:SetWordWrap(false)

    h.hint = ns.NewText(h, S.subFontSize, S.dim)
    h.hint:SetPoint("LEFT", h.title, "RIGHT", 8, 0)
    h.hint:SetWidth(ROW_W - TIER_TITLE_WIDTH - 8)
    h.hint:SetWordWrap(false)

    h.rule = h:CreateTexture(nil, "ARTWORK")
    h.rule:SetColorTexture(1, 1, 1, 0.08)
    h.rule:SetPoint("BOTTOMLEFT", 0, 0)
    h.rule:SetSize(ROW_W, 1)

    headPool[i] = h
    return h
end

--------------------------------------------------------------------------------
-- Desenho da lista
--------------------------------------------------------------------------------

-- (!) O TETO DE 100 LINHAS SAIU (0.10.0), e ele era a causa de *"tá faltando MUITA montaria
-- nessa lista, não tem as das expansões recentes"*.
--
-- A lista é ordenada por esforço, e montaria de expansão nova está quase sempre LONGE — pouca
-- reputação acumulada, conquista no começo. Ou seja: o corte em 100 recortava exatamente a parte
-- que o jogador mais queria conferir, e o rodapé dizendo "mostrando as 100 primeiras de 412" não
-- competia com a impressão de que a montaria simplesmente não estava lá.
--
-- O teto existia por desempenho: montar 400 linhas de frame na abertura custa caro. A resposta
-- certa não era cortar a lista, era **não montar o que não está à vista** — que é o que o
-- `ScrollBox` da Blizzard faz, e o que o RocketSwap já usa.
local function Redraw()
    local entries, total = ns.GetFiltered()
    local limit = #entries

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
    -- DE QUEM É ESTA LISTA. Reputação, moeda e conquista são lidas do personagem CONECTADO, e
    -- o jogador não tem como saber disso olhando a tela — foi o segundo defeito relatado em
    -- 21/09: *"qual char tem essa reputação?"*. O nome fica à vista o tempo todo, e cada linha
    -- de reputação diz se o progresso é da conta ou só deste personagem.
    local footer = string.format(L["%d mounts missing"], #entries)
    if #entries ~= total then
        footer = footer .. string.format(L[" (filtered from %d)"], total)
    end
    -- BUSCA SEM RESULTADO TEM QUE DIZER ISSO. Lista vazia sem explicação parece addon quebrado,
    -- e o primeiro palpite de quem vê é que o addon parou — não que o termo não achou nada.
    if ns.search and ns.search ~= "" and #entries == 0 then
        footer = string.format(L['nothing found for "%s"'], ns.search)
    end
    if not mcl then
        footer = footer .. L["  |cffcc6666· without MCL, there is no drop chance|r"]
    elseif not rar then
        footer = footer .. L["  |cff888888· without MountJournalEnhanced, there is no playerbase share|r"]
    end
    footer = (UnitName("player") or "?") .. "  ·  " .. footer
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
        ns.Print(L["this client has no new menu; use /rmt sources."])
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L["Sources"])
        root:CreateButton(L["All"], function()
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
    title:SetText(L["Rocket Mounts — where to start"])

    local close = GlyphButton(header, "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
        "common-icon-redx", 16, L["Close"])
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
    sourceBtn:SetText(L["Sources"])
    sourceBtn:SetScript("OnClick", function(self) SourceMenu(self) end)

    -- A CAIXA DE BUSCA, com a arte nativa (`SearchBoxTemplate`): lupa, texto de dica e o "x"
    -- de limpar já vêm com ela, e o jogador reconhece a forma de outras janelas do jogo.
    local busca = CreateFrame("EditBox", nil, bar, "SearchBoxTemplate")
    busca:SetSize(220, 22)
    busca:SetPoint("LEFT", sourceBtn, "RIGHT", 8, 0)
    busca:SetAutoFocus(false)
    -- `if busca.Instructions then` NÃO BASTA: no simulador do harness qualquer campo
    -- desconhecido responde uma função, que é verdadeira — e aí o `:SetText` tenta indexar
    -- função e estoura. Guardar pelo TIPO vale nos dois lados, e no jogo também protege contra
    -- um template que mude de forma.
    if type(busca.Instructions) == "table" and busca.Instructions.SetText then
        busca.Instructions:SetText(L["name, boss, zone, vendor"])
    end

    -- FILTRA A CADA TECLA, e não só no Enter: a lista respondendo enquanto se digita é o que
    -- deixa procurar por tentativa — escreve "fyr", vê, corrige.
    busca:SetScript("OnTextChanged", function(self, byUser)
        if not byUser then return end
        ns.search = self:GetText()
        ns.RefreshWindow()
    end)
    busca:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        ns.search = ""
        ns.RefreshWindow()
    end)
    window.search = busca

    window.footer = ns.NewText(bar, S.subFontSize, S.dim, "RIGHT")
    window.footer:SetPoint("RIGHT")
    window.footer:SetWidth(WINDOW_W - 180)

    -- Lista, com rolagem.
    list = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -S.padding)
    list:SetSize(LIST_W, WINDOW_H - S.headerHeight - 25 - S.padding * 3 - 6)
    list.content = CreateFrame("Frame", nil, list)
    list.content:SetSize(ROW_W, 1)
    list:SetScrollChild(list.content)

    -- Separador entre a lista e a ficha.
    local sep = window:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.08)
    -- A calha da barra de rolagem entra AQUI. Sem ela, a barra desenhava por cima do fio.
    sep:SetPoint("TOPLEFT", list, "TOPRIGHT", SCROLLBAR_W + S.padding, 0)
    sep:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", SCROLLBAR_W + S.padding, 0)
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

