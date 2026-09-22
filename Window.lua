-- RocketMounts | Window.lua
-- A janela: a lista ranqueada à esquerda, a ficha da montaria escolhida à direita.
local ADDON, ns = ...

local S = ns.Skin

local WINDOW_W, WINDOW_H = 790, 560
local LIST_W = 450
local DETAIL_W = WINDOW_W - LIST_W - S.padding * 3

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
        Block("Chance", txt)
    end

    -- Requisito e aquisição são blocos separados de propósito: misturar os dois é o que
    -- fazia a lista anunciar "100%" numa montaria que ainda depende de sorte.
    -- A EXPANSÃO, no alto da ficha: é a primeira coisa que situa a montaria, e sem ela o
    -- jogador lê "Vendedor em Valdrakken" sem saber de que época aquilo é.
    if entry.expansionName then
        Block("Expansão", entry.expansionName)
    end

    if entry.factionOnly then
        -- FACÇÃO É INFORMAÇÃO, e antes ela só servia para esconder a montaria. Quem planeja o
        -- outro lado precisa saber que ela existe e de quem ela é.
        Block("Facção", entry.factionOnly == "Horde" and "Só para a Horda" or "Só para a Aliança")
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
            and string.format("Requisitos — faltam %d de %d", entry.faltando, #entry.requisitos)
            or "Requisitos — todos cumpridos",
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
            Block("Quem tem, pelo que ficou anotado",
                table.concat(linhas, string.char(10)))
        end
    end

    -- PREÇO E FALTA SÃO DUAS LINHAS, e não um número grudado no outro: *"mistura o valor que
    -- tenho em bag com o valor da montaria, muito confuso"*. O preço é o que interessa primeiro;
    -- o que falta só aparece quando falta.
    if entry.cost then
        Block("Preço", entry.cost.price)
        if entry.cost.gap then
            Block("Falta", entry.cost.gap)
        end
    end

    if entry.gated and not entry.deterministic then
        Block("Atenção", "O requisito acima só LIBERA a tentativa. Cumprido ele, a montaria "
            .. "ainda depende da sorte.")
    end

    -- ⛑ O AVISO QUE FALTAVA. O addon só enxerga reputação, renome, conquista, moeda e ouro.
    -- Conquista de guilda, nível de guilda, classificação de PvP e perícia de profissão ele NÃO
    -- lê — e foi por calar sobre isso que a Fênix Negra apareceu como "é só ir pegar".
    if entry.tier == ns.TIER.CHECK then
        local texto
        if entry.vendorGuilda then
            -- ESPECÍFICO quando dá para ser: toda montaria de vendedor de guilda exige
            -- reputação com a guilda mais uma conquista de guilda.
            texto = "Vendedor de guilda. Estas exigem reputação com a sua guilda E uma "
                .. "conquista DA GUILDA — e é a conquista que eu não consigo ler, porque nenhum "
                .. "catálogo instalado diz qual conquista pertence a qual montaria. O preço "
                .. "abaixo é só uma parte do que ela custa."
        else
            texto = "Do que eu consigo ler, só o preço aparece nesta montaria — e preço quase "
                .. "nunca é o que trava. Pode haver conquista, nível de guilda ou classificação no "
                .. "caminho, e isso eu não leio."
            if entry.vendorVago then
                texto = texto .. " Nem o catálogo sabe qual é o vendedor exato desta."
            end
        end
        Block("Por que conferir", texto)
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

    -- Largura explícita nos dois: sem ela a FontString cresce até onde o texto pedir e
    -- atravessa a borda da lista — e estes rótulos mudam de tamanho a cada faixa.
    h.title = ns.NewText(h, S.headFontSize, S.gold)
    h.title:SetPoint("BOTTOMLEFT", 0, 2)
    h.title:SetWidth(TIER_TITLE_WIDTH)
    h.title:SetWordWrap(false)

    h.hint = ns.NewText(h, S.subFontSize, S.dim)
    h.hint:SetPoint("LEFT", h.title, "RIGHT", 8, 0)
    h.hint:SetWidth(LIST_W - 20 - TIER_TITLE_WIDTH - 8)
    h.hint:SetWordWrap(false)

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
    local footer = string.format("%d montarias faltando", #entries)
    if #entries ~= total then
        footer = footer .. string.format(" (filtrado de %d)", total)
    end
    -- BUSCA SEM RESULTADO TEM QUE DIZER ISSO. Lista vazia sem explicação parece addon quebrado,
    -- e o primeiro palpite de quem vê é que o addon parou — não que o termo não achou nada.
    if ns.search and ns.search ~= "" and #entries == 0 then
        footer = string.format("nada encontrado para \"%s\"", ns.search)
    end
    if not mcl then
        footer = footer .. "  |cffcc6666· sem o MCL, não há a chance de saque|r"
    elseif not rar then
        footer = footer .. "  |cff888888· sem o MountJournalEnhanced, não há o percentual da base|r"
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
        busca.Instructions:SetText("nome, chefe, zona, vendedor")
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

